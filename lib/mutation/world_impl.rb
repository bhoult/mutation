# frozen_string_literal: true

require 'set'

module Mutation
  # Simple class to represent dead agents on the grid for display purposes
  class DeadAgent
    attr_reader :agent_id, :position
    
    def initialize(agent_id, position)
      @agent_id = agent_id
      @position = position
    end
    
    def alive?
      false
    end
    
    def energy
      0
    end
  end

  class WorldImpl
    attr_accessor :grid, :tick, :last_survivor_code, :generation, :statistics
    attr_reader :agent_manager, :width, :height

    def initialize(width: nil, height: nil, size: nil, seed_code: nil, agent_executables: nil)
      initialize_world_logging
      # Support both 1D (size) and 2D (width/height) initialization
      if width && height
        @width = width
        @height = height
      elsif size
        # Convert 1D size to 2D (square grid)
        @size = size
        @width = Math.sqrt(size).ceil
        @height = Math.sqrt(size).ceil
      else
        # Use configuration
        config_size = Mutation.configuration.world_size
        @size = config_size
        @width = Math.sqrt(config_size).ceil
        @height = Math.sqrt(config_size).ceil
      end
      @size = @width * @height

      @tick = 0
      @generation = 0
      @last_survivor_code = seed_code
      @agent_manager = AgentManager.new
      @agent_executables = agent_executables || []
      @mutation_engine = MutationEngine.new
      @mutated_agent_manager = MutatedAgentManager.new
      @statistics = {
        total_agents_created: 0,
        total_generations: 0,
        max_fitness_achieved: 0,
        longest_survival_ticks: 0
      }

      # Track mutations externally (not in agent memory for security)
      @mutation_agents = Set.new  # Set of agent_ids that are mutations
      @mutation_metadata = {}     # agent_id => {original_agent: name, code: string}

      reset_grid
    end

    def reset_grid
      # Kill all existing agents
      cleanup_start = Time.now
      puts "PERF: Starting agent cleanup for reset..."
      @agent_manager.kill_all_agents
      cleanup_time = Time.now - cleanup_start
      puts "PERF: Agent cleanup completed in #{(cleanup_time * 1000).round(2)}ms"

      # Create empty grid
      @grid = Array.new(@height) { Array.new(@width) { nil } }
      
      # Clear mutation tracking
      @mutation_agents.clear
      @mutation_metadata.clear

      # Calculate initial agent count
      total_positions = @width * @height
      coverage = Mutation.configuration.initial_coverage
      agent_count = (total_positions * coverage).round
      agent_count = [agent_count, 1].max # Ensure at least 1 agent
      
      # Apply max agent count limit
      max_agents = Mutation.configuration.max_agent_count
      actual_agent_count = [agent_count, max_agents].min
      
      puts "DEBUG: World size #{@width}x#{@height} = #{total_positions} positions"
      puts "DEBUG: Coverage #{coverage} => desired agent_count = #{agent_count}"
      puts "DEBUG: Max agent limit = #{max_agents}, actual_agent_count = #{actual_agent_count}"

      # Get available positions
      positions = []
      (0...@height).each do |y|
        (0...@width).each do |x|
          positions << [x, y]
        end
      end
      positions.shuffle!

      # Create initial mutations (10% of actual population that will be spawned)
      puts "DEBUG: actual_agent_count = #{actual_agent_count}"
      initial_mutations = @mutated_agent_manager.create_initial_mutations(actual_agent_count)
      puts "INIT_AGENTS: Total=#{actual_agent_count} InitialMutations=#{initial_mutations.size} (#{(initial_mutations.size.to_f/actual_agent_count*100).round(1)}%)"
      puts "DEBUG: initial_mutations.size = #{initial_mutations.size}"
      
      # Spawn initial agents (mix of originals and mutations)
      actual_spawned = 0
      actual_agent_count.times do |i|
        if positions.empty?
          puts "SPAWN_BREAK: Breaking at slot #{i} - no more positions available"
          break
        end

        x, y = positions.pop
        
        # Use mutation if available, otherwise random agent
        if i < initial_mutations.size
          # Use a pre-created mutation
          mutation_data = initial_mutations[i]
          puts "SPAWN_SLOT_#{i}: Using MUTATION from #{mutation_data[:original_agent]}"
          agent = spawn_agent_from_data(mutation_data, x, y)
        else
          # Use only original (non-mutation) agents for the remaining 90%
          agent_data = @mutated_agent_manager.select_original_agent
          if agent_data
            puts "SPAWN_SLOT_#{i}: Using ORIGINAL #{agent_data[:name]}"
            agent = spawn_agent_from_data(agent_data, x, y)
          else
            # Fallback to default executable
            executable = default_executable
            agent = @agent_manager.spawn_agent(
              executable, x, y, 
              Mutation.configuration.random_initial_energy, 
              @generation + 1,
              {} # Initial empty memory
            )
          end
        end
        
        if agent
          @grid[y][x] = agent
          @statistics[:total_agents_created] += 1
          actual_spawned += 1
        else
          puts "SPAWN_FAILED: Failed to spawn agent at slot #{i}"
        end
      end
      
      puts "SPAWN_COMPLETE: Attempted=#{actual_agent_count} ActualSpawned=#{actual_spawned} PositionsRemaining=#{positions.size}"

      @generation += 1
      @statistics[:total_generations] = @generation

      # Log final mutation tracking state
      total_spawned = living_agents.count
      tracked_mutations = @mutation_agents.size
      counted_mutations = mutation_count
      
      puts "SPAWN_SUMMARY: Total=#{total_spawned} TrackedMutations=#{tracked_mutations} CountedMutations=#{counted_mutations}"
      puts "MUTATION_AGENTS: #{@mutation_agents.to_a}"
      
      Mutation.logger.generation("🌱 Generation #{@generation} seeded with #{total_spawned} agents (#{coverage_percentage}% of #{@width}x#{@height})")
    end

    def reset_tick
      @tick = 0
    end
    
    def reinitialize_logging
      initialize_world_logging
    end

    # Helper method to spawn agent from mutation data
    def spawn_agent_from_data(agent_data, x, y)
      executable_path = agent_data[:path]
      
      # If no path (in-memory mutation), create a temporary file
      if executable_path.nil?
        # Extract parent name from the agent data
        parent_name = agent_data[:original_agent]
        executable_path = create_temp_agent_file(agent_data[:code], parent_name)
        temp_file_created = true
      else
        temp_file_created = false
      end
      
      # Validate executable path
      unless executable_path && File.exist?(executable_path)
        Mutation.logger.error("Invalid agent path: #{executable_path.inspect} for agent #{agent_data[:name]}")
        return nil
      end
      
      # Spawn the agent using the file
      agent = @agent_manager.spawn_agent(
        executable_path, x, y,
        Mutation.configuration.random_initial_energy,
        @generation + 1,
        { 
          temp_file_path: temp_file_created ? executable_path : nil # Track temp files for cleanup
        }
      )
      
      # Track mutations externally if this is a mutation
      if agent && agent_data[:is_mutation]
        @mutation_agents.add(agent.agent_id)
        @mutation_metadata[agent.agent_id] = {
          original_agent: agent_data[:original_agent],
          code: agent_data[:code]
        }
        puts "SPAWN_MUTATION: #{agent.agent_id} from #{agent_data[:original_agent]} - Added to @mutation_agents (now #{@mutation_agents.size})"
      else
        puts "SPAWN_NORMAL: #{agent&.agent_id || 'nil'} is_mutation=#{agent_data[:is_mutation]} - NOT added to @mutation_agents (still #{@mutation_agents.size})"
      end
      
      agent
    end

    # Create a temporary file for agent code that persists during simulation
    def create_temp_agent_file(code, parent_name = nil)
      project_root = File.expand_path('../../../', __FILE__)
      temp_dir = File.join(project_root, 'agents', 'temp_mutation_agents')
      FileUtils.mkdir_p(temp_dir)
      
      # Create unique filename with generation info and parent name
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S_%N')
      base_name = parent_name ? "#{parent_name}_mutation" : "temp_agent"
      temp_filename = "#{base_name}_gen#{@generation}_#{timestamp}.rb"
      temp_filepath = File.join(temp_dir, temp_filename)
      
      # Write the agent code to temporary file
      File.write(temp_filepath, code)
      File.chmod(0755, temp_filepath) # Make executable
      
      temp_filepath
    end

    # Helper to find agent file path
    def find_agent_file(agent_name)
      # Look for the agent file in the agents directory
      agent_file = File.join('agents', "#{agent_name}.rb")
      return agent_file if File.exist?(agent_file)
      
      # Fallback to default executable
      default_executable
    end

    def step
      begin
        step_start = Time.now
      
      # Build individual world states for each agent including their neighbors
      world_state_start = Time.now
      agent_world_states = {}
      
      @grid.each_with_index do |row, y|
        row.each_with_index do |agent, x|
          next unless agent&.alive?

          # Get vision data for this agent (5-square radius)
          vision = get_vision(x, y, radius: 5)
          
          agent_world_states[agent.agent_id] = {
            tick: @tick,
            agent_id: agent.agent_id,
            position: [x, y],
            energy: agent.energy,
            world_size: [@width, @height],
            timeout_ms: Mutation.configuration.agent_timeout_ms,
            vision: vision,
            generation: agent.generation,
            memory: agent.memory # Pass agent's memory to the process
          }
        end
      end
      world_state_time = Time.now - world_state_start

      # Get all agent actions
      actions_start = Time.now
      actions = @agent_manager.get_agent_actions_with_individual_states(agent_world_states)
      actions_time = Time.now - actions_start

      # Apply actions sequentially to avoid race conditions
      grid_setup_start = Time.now
      new_grid = Array.new(@height) { Array.new(@width) { nil } }

      # First, copy dead agents to preserve their locations
      @grid.each_with_index do |row, y|
        row.each_with_index do |agent, x|
          if agent && !agent.alive?
            new_grid[y][x] = agent  # Keep dead agents
          end
        end
      end
      grid_setup_time = Time.now - grid_setup_start

      action_execution_start = Time.now
      living_count = 0
      @grid.each_with_index do |row, y|
        row.each_with_index do |agent, x|
          if agent&.alive?
            living_count += 1
          end
          next unless agent&.alive?

          action_response = actions[agent.agent_id] || { type: :rest }
          action = { type: action_response[:type], target: action_response[:target] }
          agent.memory = action_response[:memory] || {} # Update agent's memory

          # Convert action type to symbol for consistency
          action_type = action[:type].to_s.to_sym if action[:type]

          execute_action(agent, action, x, y, new_grid)

          # Age the agent and check for maximum lifespan
          died_of_old_age = agent.age_one_cycle!
          
          # Apply additional energy decay (aging/metabolism)
          current_energy = agent.energy
          new_energy = current_energy - Mutation.configuration.energy_decay
          @agent_manager.update_agent_energy(agent.agent_id, new_energy)

          # Keep agent if still alive after all checks (energy and age)
          if agent.alive && new_energy > 0.001 && !died_of_old_age
            # Only place agent at original position if it didn't move
            # (Movement already places the agent in the new position)
            unless action_type == :move
              new_grid[y][x] = agent
            end
          else
            # Agent died - handle different death causes
            if agent.alive
              if died_of_old_age
                Mutation.logger.debug("Agent #{agent.agent_id} at (#{x},#{y}) died of old age (age: #{agent.age})")
                log_world_event("DEATH_AGE", agent.agent_id, [x, y], { age: agent.age, energy: new_energy })
              else
                Mutation.logger.debug("Agent #{agent.agent_id} at (#{x},#{y}) dying (energy: #{new_energy})")
                log_world_event("DEATH_ENERGY", agent.agent_id, [x, y], { energy: new_energy })
              end
              agent.die!
              @agent_manager.remove_agent(agent.agent_id)
              cleanup_mutation_tracking(agent.agent_id)
            end
            # Create dead agent marker
            dead_agent = DeadAgent.new(agent.agent_id, [x, y])
            new_grid[y][x] = dead_agent
          end
        end
      end
      action_execution_time = Time.now - action_execution_start

      @grid = new_grid
      @tick += 1

      # Process any deferred agent cleanup operations
      @agent_manager.process_cleanup_queue

      update_statistics
      
      total_step_time = Time.now - step_start
      
      # Log timing every 50 ticks for performance monitoring
      if @tick % 50 == 0
        Mutation.logger.debug("PROFILE T:#{@tick} | Total: #{(total_step_time * 1000).round(2)}ms | WorldState: #{(world_state_time * 1000).round(2)}ms | Actions: #{(actions_time * 1000).round(2)}ms | GridSetup: #{(grid_setup_time * 1000).round(2)}ms | Execution: #{(action_execution_time * 1000).round(2)}ms")
      end
      
      # Debug and fix agent tracking mismatch
      if @tick % 20 == 0
        manager_count = agent_count
        grid_count = grid_agent_count
        if manager_count != grid_count
          Mutation.logger.warn("AGENT MISMATCH: Manager has #{manager_count} agents, Grid has #{grid_count} agents")
          
          # List agents in manager but not on grid
          manager_agents = living_agents.map(&:agent_id).to_set
          grid_agents = Set.new
          @grid.each_with_index do |row, y|
            row.each_with_index do |cell, x|
              if cell&.alive?
                grid_agents.add(cell.agent_id)
              end
            end
          end
          
          missing_from_grid = manager_agents - grid_agents
          if missing_from_grid.any?
            Mutation.logger.warn("Agents in manager but not on grid: #{missing_from_grid.to_a.join(', ')}")
            
            # Clean up orphaned agents
            missing_from_grid.each do |agent_id|
              Mutation.logger.warn("Removing orphaned agent #{agent_id} from manager")
              agent = @agent_manager.agents[agent_id]
              if agent
                agent.die!
                @agent_manager.remove_agent(agent_id)
                cleanup_mutation_tracking(agent_id)
              end
            end
          end
        end
      end
      #   grid_living = 0
      #   @grid.each do |row|
      #     row.each do |cell|
      #       grid_living += 1 if cell&.respond_to?(:alive?) && cell.alive?
      #     end
      #   end
      #   if living.count != grid_living
      #     Mutation.logger.debug("MISMATCH T:#{@tick} | AgentManager: #{living.count} living | Grid: #{grid_living} living")
      #   end
      # end
      rescue => e
        Mutation.logger.error("Exception in WorldImpl.step: #{e.message}")
        Mutation.logger.error(e.backtrace.join("\n"))
        raise
      end
    end

    def execute_action(agent, action, x, y, new_grid)
      action_start = Time.now
      
      # Calculate base action cost (all actions cost energy)
      base_action_cost = Mutation.configuration.base_action_cost
      
      action_type = action[:type].to_s.to_sym if action[:type]
      
      case action_type
      when :attack
        action_cost = base_action_cost + Mutation.configuration.attack_action_cost
        log_world_event("ATTACK_START", agent.agent_id, [x, y], { target: action[:target] })
        execute_attack(agent, action[:target], x, y)
      when :rest
        action_cost = base_action_cost  # Resting still costs some energy
        log_world_event("REST", agent.agent_id, [x, y])
        execute_rest(agent)
      when :replicate
        action_cost = base_action_cost + Mutation.configuration.replication_cost
        log_world_event("REPLICATE_START", agent.agent_id, [x, y])
        execute_replicate(agent, x, y, new_grid)
      when :move
        action_cost = base_action_cost  # Moving costs base energy
        log_world_event("MOVE_START", agent.agent_id, [x, y], { target: action[:target] })
        execute_move(agent, action[:target], x, y, new_grid)
      when :die
        action_cost = 0  # Dying is free
        log_world_event("SUICIDE", agent.agent_id, [x, y])
        agent.die!
      else
        Mutation.logger.debug("Agent #{agent.agent_id} unknown action #{action[:type]} (#{action_type}), defaulting to rest")
        action_cost = base_action_cost  # Default to rest cost
        log_world_event("UNKNOWN_ACTION", agent.agent_id, [x, y], { action: action[:type] })
        execute_rest(agent)
      end
      
      # Apply action cost (world enforces this, agents can't cheat)
      current_energy = agent.energy
      new_energy = current_energy - action_cost
      @agent_manager.update_agent_energy(agent.agent_id, new_energy)
      
      # Kill agent if energy depleted (fix floating point precision)
      if new_energy <= 0.001
        agent.die!
        @agent_manager.remove_agent(agent.agent_id)
        cleanup_mutation_tracking(agent.agent_id)
      end
      
      # Optional: Log slow actions for debugging
      # action_time = Time.now - action_start
      # if action_time > 0.05 # Log if action takes > 50ms
      #   Mutation.logger.debug("PROFILE SlowAction: #{action_type} for #{agent.agent_id} took #{(action_time * 1000).round(2)}ms")
      # end
    end

    def execute_attack(agent, target_direction, x, y)
      target_x, target_y = get_target_position(x, y, target_direction)
      return unless valid_position?(target_x, target_y)

      target_agent = @grid[target_y][target_x]
      return unless target_agent&.alive

      # Apply damage
      damage = Mutation.configuration.attack_damage
      new_target_energy = target_agent.energy - damage
      @agent_manager.update_agent_energy(target_agent.agent_id, new_target_energy)

      # Attacker gains energy
      energy_gain = Mutation.configuration.attack_energy_gain
      new_attacker_energy = agent.energy + energy_gain
      @agent_manager.update_agent_energy(agent.agent_id, new_attacker_energy)

      if new_target_energy <= 0
        # Create dead agent marker before removing from manager
        dead_agent = DeadAgent.new(target_agent.agent_id, [target_x, target_y])
        @agent_manager.remove_agent(target_agent.agent_id)
        cleanup_mutation_tracking(target_agent.agent_id)
        @grid[target_y][target_x] = dead_agent
        log_world_event("ATTACK_KILL", agent.agent_id, [x, y], { killed: target_agent.agent_id, at: [target_x, target_y] })
      else
        log_world_event("ATTACK_DAMAGE", agent.agent_id, [x, y], { target: target_agent.agent_id, damage: damage })
      end
    end

    def execute_rest(agent)
      # Resting provides energy gain to offset action and decay costs
      energy_gain = Mutation.configuration.rest_energy_gain
      new_energy = agent.energy + energy_gain
      @agent_manager.update_agent_energy(agent.agent_id, new_energy)
    end

    def execute_move(agent, target_direction, x, y, new_grid)
      target_x, target_y = get_target_position(x, y, target_direction)
      unless valid_position?(target_x, target_y)
        # Invalid move (out of bounds) - stay at original position
        new_grid[y][x] = agent
        return
      end

      # Check what's at the target position in the new grid
      target_cell = new_grid[target_y][target_x]
      
      if target_cell.nil?
        # Empty space - just move there
        @agent_manager.move_agent(agent.agent_id, target_x, target_y)
        new_grid[target_y][target_x] = agent
        new_grid[y][x] = nil  # Clear old position
        log_world_event("MOVE_SUCCESS", agent.agent_id, [target_x, target_y], { from: [x, y] })
      elsif target_cell.is_a?(DeadAgent)
        # Dead agent - eat it and gain energy
        dead_agent_energy_gain = Mutation.configuration.dead_agent_energy_gain
        new_energy = agent.energy + dead_agent_energy_gain
        @agent_manager.update_agent_energy(agent.agent_id, new_energy)
        @agent_manager.move_agent(agent.agent_id, target_x, target_y)
        new_grid[target_y][target_x] = agent
        new_grid[y][x] = nil  # Clear old position
        log_world_event("MOVE_EAT_DEAD", agent.agent_id, [target_x, target_y], { from: [x, y], energy_gained: dead_agent_energy_gain })
      else
        # Position occupied by living agent - movement fails, stay at original position
        new_grid[y][x] = agent
        log_world_event("MOVE_BLOCKED", agent.agent_id, [x, y], { target: [target_x, target_y] })
      end
    end

    def execute_replicate(agent, x, y, new_grid)
      total_replication_cost = Mutation.configuration.replication_cost
      return if agent.energy < total_replication_cost

      # Population cap to prevent excessive spawning
      return if agent_count >= @size # Don't exceed grid capacity

      # Find empty adjacent position (check new_grid to avoid conflicts)
      empty_positions = get_empty_adjacent_positions(x, y, new_grid)
      return if empty_positions.empty?

      offspring_x, offspring_y = empty_positions.sample

      # Double-check the position is still empty in new_grid
      if new_grid[offspring_y][offspring_x] != nil
        log_world_event("REPLICATE_FAILED", agent.agent_id, [x, y], { reason: "position_occupied", at: [offspring_x, offspring_y] })
        return
      end

      # Create offspring - exact duplicate with 10% chance of mutation
      should_mutate = rand < 0.1  # 10% chance of mutation
      
      if should_mutate
        # Create mutated offspring
        offspring = create_mutated_offspring(agent, offspring_x, offspring_y)
        Mutation.logger.info("REPLICATE_MUTATED: #{agent.agent_id} -> #{offspring&.agent_id}")
      else
        # Create exact duplicate
        offspring = create_duplicate_offspring(agent, offspring_x, offspring_y)
        Mutation.logger.info("REPLICATE_DUPLICATE: #{agent.agent_id} -> #{offspring&.agent_id}")
      end
      
      return unless offspring

      # Note: Replication cost is now handled in execute_action, not here
      # Place offspring in grid
      new_grid[offspring_y][offspring_x] = offspring
      @statistics[:total_agents_created] += 1
      
      # Note: We don't automatically track replicated agents as mutations
      # Only initial mutations (10%) should be counted as "mutations" in the display
      # Replicated agents are just evolutionary descendants, not mutations per se
      
      log_world_event("REPLICATE_SUCCESS", agent.agent_id, [x, y], { offspring: offspring.agent_id, at: [offspring_x, offspring_y] })
    end

    def get_target_position(x, y, direction)
      case direction.to_sym
      when :north then [x, y - 1]
      when :south then [x, y + 1]
      when :east then [x + 1, y]
      when :west then [x - 1, y]
      when :north_east then [x + 1, y - 1]
      when :north_west then [x - 1, y - 1]
      when :south_east then [x + 1, y + 1]
      when :south_west then [x - 1, y + 1]
      else [x, y] # Invalid direction
      end
    end

    def get_empty_adjacent_positions(x, y, grid = nil)
      grid ||= @grid  # Default to current grid if not specified
      positions = []
      (-1..1).each do |dx|
        (-1..1).each do |dy|
          next if dx == 0 && dy == 0 # Skip center position
          
          new_x, new_y = x + dx, y + dy
          next unless valid_position?(new_x, new_y)
          next if grid[new_y][new_x] # Position occupied (including dead agents)
          
          positions << [new_x, new_y]
        end
      end
      positions
    end

    def valid_position?(x, y)
      x >= 0 && x < @width && y >= 0 && y < @height
    end

    def get_neighbors(x, y)
      neighbors = []

      # 8-directional neighbors (Moore neighborhood)
      (-1..1).each do |dy|
        (-1..1).each do |dx|
          next if dx == 0 && dy == 0 # Skip center

          neighbor_x = x + dx
          neighbor_y = y + dy

          if neighbor_x >= 0 && neighbor_x < @width && neighbor_y >= 0 && neighbor_y < @height
            neighbors << @grid[neighbor_y][neighbor_x]
          else
            neighbors << nil # Outside world boundary
          end
        end
      end

      neighbors
    end

    def get_vision(x, y, radius: 5)
      vision = {}
      
      # Scan all positions within the radius
      (-radius..radius).each do |dy|
        (-radius..radius).each do |dx|
          next if dx == 0 && dy == 0 # Skip center position
          
          vision_x = x + dx
          vision_y = y + dy
          
          # Create relative coordinate key
          relative_key = "#{dx},#{dy}"
          
          if valid_position?(vision_x, vision_y)
            cell = @grid[vision_y][vision_x]
            if cell.nil?
              # Empty space - skip (don't add to vision hash to reduce data)
              next
            elsif cell.is_a?(DeadAgent)
              # Dead agent - only include energy if non-zero
              vision[relative_key] = { type: 'dead_agent' }
            elsif cell.alive?
              # Living agent - include energy
              vision[relative_key] = { type: 'living_agent', energy: cell.energy }
            else
              # Dead agent (should not happen with current logic but safe fallback)
              vision[relative_key] = { type: 'dead_agent' }
            end
          else
            # Out of bounds - include for boundary detection
            vision[relative_key] = { type: 'boundary' }
          end
        end
      end
      
      vision
    end

    def living_agents
      @agent_manager.living_agents
    end

    def agent_count
      living_agents.count
    end
    
    def mutation_count
      # Count only agents tracked externally as mutations
      living = living_agents
      mutation_count = living.count do |agent|
        @mutation_agents.include?(agent.agent_id)
      end
      
      # Debug logging every 10 ticks or at tick 0 (spawn)
      if @tick % 10 == 0 || @tick == 0
        total_agents = living.count
        tracked_mutations = @mutation_agents.size
        puts "MUTATION_COUNT_DEBUG: T:#{@tick} Total:#{total_agents} TrackedMutations:#{tracked_mutations} CountedMutations:#{mutation_count}"
        
        # Show sample of which agents are/aren't counted as mutations (first 3 only)
        living.first(3).each do |agent|
          is_tracked = @mutation_agents.include?(agent.agent_id)
          puts "  Sample Agent #{agent.agent_id}: tracked=#{is_tracked}"
        end
      end
      
      mutation_count
    end
    
    def grid_agent_count
      count = 0
      @grid.each do |row|
        row.each do |cell|
          count += 1 if cell&.alive?
        end
      end
      count
    end

    def process_count
      @agent_manager.agents.size
    end

    def all_dead?
      # Check both agent manager and grid to ensure consistency
      agent_count == 0 && grid_agent_count == 0
    end

    def average_energy
      agents = living_agents
      return 0.0 if agents.empty?
      
      agents.sum(&:energy) / agents.count.to_f
    end

    def fittest_agent
      living_agents.max_by(&:fitness)
    end

    # External mutation tracking methods (secure - agents can't modify these)
    def is_mutation?(agent_id)
      @mutation_agents.include?(agent_id)
    end

    def get_mutation_metadata(agent_id)
      @mutation_metadata[agent_id] || {}
    end
    
    def agent_counts_by_type
      counts = Hash.new(0)
      
      living_agents.each do |agent|
        # Extract base name from executable path
        base_name = File.basename(agent.executable_path, '.rb')
        
        # Remove mutation suffixes to group by original type
        # Handle various naming patterns:
        # - "active_explorer_agent_mutation_123" -> "active_explorer_agent"
        # - "active_explorer_agent_mutation_gen1_timestamp" -> "active_explorer_agent" 
        # - "cautious_economist_125719_629281511_mutation_gen1_timestamp" -> "cautious_economist"
        # - "reproductive_colonizer_125717_084253360_125724_198537629_mutation_gen1_timestamp" -> "reproductive_colonizer"
        # - "temp_agent_gen1_timestamp" -> "temp_agent" (legacy format)
        
        # First remove any hash/timestamp patterns before _mutation
        base_name = base_name.gsub(/_\d{6}_\d{9}/, '')  # Remove _125719_629281511 patterns
        # Then remove mutation suffixes
        base_name = base_name.gsub(/_mutation(_gen\d+)?_\d+/, '')
        
        counts[base_name] += 1
      end
      
      counts
    end
    
    def top_agents_by_population(limit = 3)
      agent_counts_by_type
        .sort_by { |_, count| -count }
        .first(limit)
        .map { |name, count| { name: name, count: count } }
    end


    # Clean up mutation tracking when agent is removed
    def cleanup_mutation_tracking(agent_id)
      @mutation_agents.delete(agent_id)
      @mutation_metadata.delete(agent_id)
    end

    # Create an exact duplicate of the parent agent
    def create_duplicate_offspring(parent_agent, x, y)
      offspring_energy = Mutation.configuration.random_initial_energy
      offspring_generation = parent_agent.generation + 1
      
      # Use the exact same executable as the parent
      @agent_manager.spawn_agent(
        parent_agent.executable_path,
        x, y,
        offspring_energy,
        offspring_generation,
        {} # Empty memory for offspring
      )
    end

    # Create a mutated version of the parent agent
    def create_mutated_offspring(parent_agent, x, y)
      offspring_energy = Mutation.configuration.random_initial_energy
      offspring_generation = parent_agent.generation + 1
      
      # Get the parent's code and mutate it
      begin
        parent_code = File.read(parent_agent.executable_path)
        mutated_code = @mutation_engine.mutate_code(parent_code)
        
        # Get parent name for temp file naming
        parent_name = File.basename(parent_agent.executable_path, '.rb')
        # Remove any existing mutation suffix to get the base name
        parent_base_name = parent_name.gsub(/_mutation_gen\d+_\d+/, '')
        
        # Create temporary file for mutated code
        temp_file = create_temp_agent_file(mutated_code, parent_base_name)
        
        offspring = @agent_manager.spawn_agent(
          temp_file,
          x, y,
          offspring_energy,
          offspring_generation,
          { temp_file_path: temp_file } # Track temp file for cleanup
        )
        
        # Track this as a mutation since it was actively mutated
        if offspring
          @mutation_agents.add(offspring.agent_id)
          @mutation_metadata[offspring.agent_id] = {
            original_agent: parent_base_name,
            code: mutated_code
          }
        end
        
        offspring
      rescue StandardError => e
        Mutation.logger.error("Failed to create mutated offspring: #{e.message}")
        # Fallback to duplicate if mutation fails
        create_duplicate_offspring(parent_agent, x, y)
      end
    end

    def status_line
      "T:#{@tick.to_s.rjust(3)} G:#{@generation} A:#{agent_count} | #{@width}x#{@height} grid"
    end

    def detailed_status
      agents = living_agents
      if agents.any?
        avg_energy = average_energy
        max_energy = agents.map(&:energy).max
        min_energy = agents.map(&:energy).min
        
        "Energy: avg=#{avg_energy.round(1)} max=#{max_energy} min=#{min_energy}"
      else
        "No living agents"
      end
    end

    def coverage_percentage
      return 0.0 if @size == 0
      
      (agent_count / @size.to_f * 100).round(1)
    end

    def prepare_for_reset
      # Log current generation stats before reset
      if living_agents.any?
        max_fitness = living_agents.map(&:fitness).max
        @statistics[:max_fitness_achieved] = [@statistics[:max_fitness_achieved], max_fitness].max
        @statistics[:longest_survival_ticks] = [@statistics[:longest_survival_ticks], @tick].max
      end
      
      # Clean up current agents
      prepare_cleanup_start = Time.now
      puts "PERF: Starting agent cleanup for prepare_for_reset..."
      @agent_manager.kill_all_agents
      prepare_cleanup_time = Time.now - prepare_cleanup_start
      puts "PERF: prepare_for_reset cleanup completed in #{(prepare_cleanup_time * 1000).round(2)}ms"
    end
    
    def cleanup
      Mutation.logger.info("Starting ProcessWorld cleanup...")
      # Ensure all agent processes are properly terminated
      @agent_manager.kill_all_agents
      Mutation.logger.info("ProcessWorld cleanup complete.")
    end

    private

    def initialize_world_logging
      # Get the current simulation log path from log manager
      @world_log_file = Mutation.log_manager.current_log_path('world_events.log')
      
      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(@world_log_file))
      
      # Initialize world events log
      File.open(@world_log_file, 'w') do |f|
        f.puts "=== WORLD EVENTS LOG - Started at #{Time.now} ==="
      end
    rescue => e
      Mutation.logger.debug("Failed to initialize world logging: #{e.message}")
    end

    def log_world_event(event_type, agent_id, position, details = {})
      return unless @world_log_file
      
      timestamp = Time.now.strftime("%H:%M:%S.%3N")
      position_str = position ? "(#{position[0]},#{position[1]})" : "(?)"
      details_str = details.empty? ? "" : " - #{details.inspect}"
      
      File.open(@world_log_file, 'a') do |f|
        f.puts "[T:#{@tick} #{timestamp}] #{event_type}: Agent #{agent_id} at #{position_str}#{details_str}"
      end
    rescue => e
      # Don't let logging errors break the simulation
      Mutation.logger.debug("Failed to log world event: #{e.message}")
    end

    def default_executable
      # Use provided executables or fall back to base agent
      if @agent_executables&.any?
        @agent_executables.sample
      else
        Mutation.configuration.default_agent_executable
      end
    end

    def update_statistics
      # Update max fitness if we have living agents
      if living_agents.any?
        max_fitness = living_agents.map(&:fitness).max
        @statistics[:max_fitness_achieved] = [@statistics[:max_fitness_achieved], max_fitness].max
      end
    end
  end
end