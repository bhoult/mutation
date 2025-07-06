# frozen_string_literal: true

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
    attr_reader :agent_manager

    def initialize(width: nil, height: nil, size: nil, seed_code: nil, agent_executables: nil)
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
      @statistics = {
        total_agents_created: 0,
        total_generations: 0,
        max_fitness_achieved: 0,
        longest_survival_ticks: 0
      }

      reset_grid
    end

    def reset_grid
      # Kill all existing agents
      @agent_manager.kill_all_agents

      # Create empty grid
      @grid = Array.new(@height) { Array.new(@width) { nil } }

      # Calculate initial agent count
      total_positions = @width * @height
      agent_count = (total_positions * Mutation.configuration.initial_coverage).round
      agent_count = [agent_count, 1].max # Ensure at least 1 agent

      # Get available positions
      positions = []
      (0...@height).each do |y|
        (0...@width).each do |x|
          positions << [x, y]
        end
      end
      positions.shuffle!

      # Spawn initial agents from genetic pool or provided executables
      agent_count.times do |i|
        break if positions.empty?

        x, y = positions.pop
        
        # Prefer genetic pool over provided executables
        executable = if @mutation_engine.respond_to?(:random_agent_from_pool)
          @mutation_engine.random_agent_from_pool || default_executable
        else
          default_executable
        end
        
        agent = @agent_manager.spawn_agent(
          executable, x, y, 
          Mutation.configuration.random_initial_energy, 
          @generation + 1,
          {} # Initial empty memory
        )
        
        if agent
          @grid[y][x] = agent
          @statistics[:total_agents_created] += 1
        end
      end

      @generation += 1
      @statistics[:total_generations] = @generation

      Mutation.logger.generation("🌱 Generation #{@generation} seeded with #{living_agents.count} agents (#{coverage_percentage}% of #{@width}x#{@height})")
    end

    def step
      step_start = Time.now
      
      # Build individual world states for each agent including their neighbors
      world_state_start = Time.now
      agent_world_states = {}
      
      @grid.each_with_index do |row, y|
        row.each_with_index do |agent, x|
          next unless agent&.alive?

          # Get neighbors for this specific agent
          neighbors = get_neighbors(x, y)
          
          agent_world_states[agent.agent_id] = {
            tick: @tick,
            agent_id: agent.agent_id,
            position: [x, y],
            energy: agent.energy,
            world_size: [@width, @height],
            timeout_ms: Mutation.configuration.agent_timeout_ms,
            neighbors: neighbors,
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
      @grid.each_with_index do |row, y|
        row.each_with_index do |agent, x|
          next unless agent&.alive?

          action_response = actions[agent.agent_id] || { type: :rest }
          action = { type: action_response[:type], target: action_response[:target] }
          agent.memory = action_response[:memory] || {} # Update agent's memory

          # Convert action type to symbol for consistency
          action_type = action[:type].to_s.to_sym if action[:type]

          execute_action(agent, action, x, y, new_grid)

          # Apply additional energy decay (aging/metabolism)
          current_energy = agent.energy
          new_energy = current_energy - Mutation.configuration.energy_decay
          @agent_manager.update_agent_energy(agent.agent_id, new_energy)

          # Keep agent if still alive after all energy deductions (fix floating point precision)
          if agent.alive && new_energy > 0.001
            # Only place agent at original position if it didn't move
            # (Movement already places the agent in the new position)
            unless action_type == :move
              new_grid[y][x] = agent
            end
          else
            # Agent died - only remove if not already removed by execute_action
            if agent.alive
              Mutation.logger.debug("Agent #{agent.agent_id} at (#{x},#{y}) dying (energy: #{new_energy})")
              agent.die!
              @agent_manager.remove_agent(agent.agent_id)
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

      update_statistics
      
      total_step_time = Time.now - step_start
      
      # Log timing every 50 ticks for performance monitoring
      if @tick % 50 == 0
        Mutation.logger.debug("PROFILE T:#{@tick} | Total: #{(total_step_time * 1000).round(2)}ms | WorldState: #{(world_state_time * 1000).round(2)}ms | Actions: #{(actions_time * 1000).round(2)}ms | GridSetup: #{(grid_setup_time * 1000).round(2)}ms | Execution: #{(action_execution_time * 1000).round(2)}ms")
      end
      
      # Optional: Debug agent tracking mismatch
      # if @tick % 20 == 0
      #   living = living_agents
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
    end

    def execute_action(agent, action, x, y, new_grid)
      action_start = Time.now
      
      # Calculate base action cost (all actions cost energy)
      base_action_cost = Mutation.configuration.base_action_cost
      
      action_type = action[:type].to_s.to_sym if action[:type]
      
      case action_type
      when :attack
        action_cost = base_action_cost + Mutation.configuration.attack_action_cost
        execute_attack(agent, action[:target], x, y)
      when :rest
        action_cost = base_action_cost  # Resting still costs some energy
        execute_rest(agent)
      when :replicate
        action_cost = base_action_cost + Mutation.configuration.replication_cost
        execute_replicate(agent, x, y, new_grid)
      when :move
        action_cost = base_action_cost  # Moving costs base energy
        execute_move(agent, action[:target], x, y, new_grid)
      when :die
        action_cost = 0  # Dying is free
        agent.die!
      else
        Mutation.logger.debug("Agent #{agent.agent_id} unknown action #{action[:type]} (#{action_type}), defaulting to rest")
        action_cost = base_action_cost  # Default to rest cost
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
        @grid[target_y][target_x] = dead_agent
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
        # Mutation.logger.debug("Agent #{agent.agent_id} moved from (#{x},#{y}) to (#{target_x},#{target_y})")
      elsif target_cell.is_a?(DeadAgent)
        # Dead agent - eat it and gain energy
        dead_agent_energy_gain = 10  # Default energy gain from eating dead agents
        new_energy = agent.energy + dead_agent_energy_gain
        @agent_manager.update_agent_energy(agent.agent_id, new_energy)
        @agent_manager.move_agent(agent.agent_id, target_x, target_y)
        new_grid[target_y][target_x] = agent
        new_grid[y][x] = nil  # Clear old position
        # Mutation.logger.debug("Agent #{agent.agent_id} ate dead agent and gained #{dead_agent_energy_gain} energy")
      else
        # Position occupied by living agent - movement fails, stay at original position
        new_grid[y][x] = agent
      end
    end

    def execute_replicate(agent, x, y, new_grid)
      total_replication_cost = Mutation.configuration.additional_replication_cost + Mutation.configuration.replication_cost
      return if agent.energy < total_replication_cost

      # Population cap to prevent excessive spawning
      return if agent_count >= @size # Don't exceed grid capacity

      # Find empty adjacent position (check new_grid to avoid conflicts)
      empty_positions = get_empty_adjacent_positions(x, y, new_grid)
      return if empty_positions.empty?

      offspring_x, offspring_y = empty_positions.sample

      # Create offspring with mutation
      offspring = @agent_manager.create_offspring(agent, offspring_x, offspring_y, @mutation_engine, agent.memory)
      return unless offspring

      # Note: Replication cost is now handled in execute_action, not here
      # Place offspring in grid
      new_grid[offspring_y][offspring_x] = offspring
      @statistics[:total_agents_created] += 1
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

    def living_agents
      @agent_manager.living_agents
    end

    def agent_count
      living_agents.count
    end

    def process_count
      @agent_manager.agents.size
    end

    def all_dead?
      agent_count == 0
    end

    def average_energy
      agents = living_agents
      return 0.0 if agents.empty?
      
      agents.sum(&:energy) / agents.count.to_f
    end

    def fittest_agent
      living_agents.max_by(&:fitness)
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
      @agent_manager.kill_all_agents
    end
    
    def cleanup
      Mutation.logger.info("Starting ProcessWorld cleanup...")
      # Ensure all agent processes are properly terminated
      @agent_manager.kill_all_agents
      Mutation.logger.info("ProcessWorld cleanup complete.")
    end

    private

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