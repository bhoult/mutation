# frozen_string_literal: true

module Mutation
  class ProcessWorld
    attr_accessor :grid, :tick, :last_survivor_code, :generation, :statistics

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

      # Spawn initial agents
      agent_count.times do |i|
        break if positions.empty?
        break if @agent_executables.empty?

        x, y = positions.pop
        executable = @agent_executables.sample # Random executable
        
        agent = @agent_manager.spawn_agent(
          executable, x, y, 
          Mutation.configuration.initial_energy, 
          @generation + 1
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
      # Build individual world states for each agent including their neighbors
      agent_world_states = {}
      
      @grid.each_with_index do |row, y|
        row.each_with_index do |agent, x|
          next unless agent&.alive

          # Get neighbors for this specific agent
          neighbors = get_neighbors(x, y)
          
          agent_world_states[agent.agent_id] = {
            tick: @tick,
            world_size: [@width, @height],
            timeout_ms: Mutation.configuration.agent_timeout_ms,
            neighbors: neighbors
          }
        end
      end

      # Get all agent actions
      actions = @agent_manager.get_agent_actions_with_individual_states(agent_world_states)

      # Apply actions sequentially to avoid race conditions
      new_grid = Array.new(@height) { Array.new(@width) { nil } }

      @grid.each_with_index do |row, y|
        row.each_with_index do |agent, x|
          next unless agent&.alive

          action = actions[agent.agent_id] || { type: :rest }
          execute_action(agent, action, x, y, new_grid)

          # Apply energy decay
          new_energy = agent.energy - Mutation.configuration.energy_decay
          @agent_manager.update_agent_energy(agent.agent_id, new_energy)

          # Keep agent if still alive
          if agent.alive && new_energy > 0
            new_grid[y][x] = agent
          else
            @agent_manager.remove_agent(agent.agent_id)
          end
        end
      end

      @grid = new_grid
      @tick += 1

      update_statistics
    end

    def execute_action(agent, action, x, y, new_grid)
      case action[:type]
      when :attack
        execute_attack(agent, action[:target], x, y)
      when :rest
        execute_rest(agent)
      when :replicate
        execute_replicate(agent, x, y, new_grid)
      when :die
        agent.die!
      else
        execute_rest(agent) # Default action
      end
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
        @agent_manager.remove_agent(target_agent.agent_id)
        @grid[target_y][target_x] = nil
      end
    end

    def execute_rest(agent)
      energy_gain = Mutation.configuration.rest_energy_gain
      new_energy = agent.energy + energy_gain
      @agent_manager.update_agent_energy(agent.agent_id, new_energy)
    end

    def execute_replicate(agent, x, y, new_grid)
      return if agent.energy < Mutation.configuration.replication_cost

      # Find empty adjacent position
      empty_positions = get_empty_adjacent_positions(x, y)
      return if empty_positions.empty?

      offspring_x, offspring_y = empty_positions.sample

      # Create offspring (for now, use same executable)
      offspring = @agent_manager.create_offspring(agent, offspring_x, offspring_y, nil)
      return unless offspring

      # Subtract replication cost from parent
      cost = Mutation.configuration.replication_cost
      new_parent_energy = agent.energy - cost
      @agent_manager.update_agent_energy(agent.agent_id, new_parent_energy)

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

    def get_empty_adjacent_positions(x, y)
      positions = []
      (-1..1).each do |dx|
        (-1..1).each do |dy|
          next if dx == 0 && dy == 0 # Skip center position
          
          new_x, new_y = x + dx, y + dy
          next unless valid_position?(new_x, new_y)
          next if @grid[new_y][new_x] # Position occupied
          
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
      # Ensure all agent processes are properly terminated
      @agent_manager.kill_all_agents
    end

    private

    def update_statistics
      # Update max fitness if we have living agents
      if living_agents.any?
        max_fitness = living_agents.map(&:fitness).max
        @statistics[:max_fitness_achieved] = [@statistics[:max_fitness_achieved], max_fitness].max
      end
    end
  end
end