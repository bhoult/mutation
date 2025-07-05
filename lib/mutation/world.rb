require 'parallel'

module Mutation
  class World
    attr_accessor :grid, :tick, :last_survivor_code, :generation, :statistics
    
    def initialize(width: nil, height: nil, size: nil, seed_code: nil)
      # Support both 1D (size) and 2D (width/height) initialization
      if width && height
        @width = width
        @height = height
        @size = @width * @height
      elsif size
        # Convert 1D size to 2D (square grid)
        @size = size
        @width = Math.sqrt(size).ceil
        @height = Math.sqrt(size).ceil
        @size = @width * @height
      else
        # Use configuration
        config_size = Mutation.configuration.world_size
        @size = config_size
        @width = Math.sqrt(config_size).ceil
        @height = Math.sqrt(config_size).ceil
        @size = @width * @height
      end
      
      @tick = 0
      @generation = 0
      @last_survivor_code = seed_code
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
      # Create empty grid
      @grid = Array.new(@height) { Array.new(@width) { nil } }
      
      # Calculate 10% coverage
      total_positions = @width * @height
      agent_count = (total_positions * Mutation.configuration.initial_coverage).round
      agent_count = [agent_count, 1].max  # Ensure at least 1 agent
      
      # Place agents randomly in 10% of positions
      positions = []
      (0...@height).each do |y|
        (0...@width).each do |x|
          positions << [x, y]
        end
      end
      
      # Randomly select positions for agents
      selected_positions = positions.sample(agent_count)
      
      selected_positions.each do |x, y|
        @grid[y][x] = create_initial_agent
      end
      
      @generation += 1
      @statistics[:total_generations] = @generation
      @statistics[:total_agents_created] += agent_count
      
      coverage_percent = (agent_count.to_f / total_positions * 100).round(1)
      Mutation.logger.generation("🌱 Generation #{@generation} seeded with #{agent_count} agents (#{coverage_percent}% of #{@width}x#{@height})")
    end
    
    def create_initial_agent
      if @last_survivor_code
        Agent.new(code_str: @last_survivor_code, generation: @generation)
      else
        Agent.new(generation: @generation)
      end
    end
    
    def step
      new_grid = Array.new(@height) { Array.new(@width) }
      
      # Phase 1: Process agent decisions in parallel
      agent_actions = if Mutation.configuration.parallel_agents && living_agents.size > 10
        process_agents_parallel
      else
        process_agents_sequential
      end
      
      # Phase 2: Apply actions and effects sequentially to avoid race conditions
      agent_actions.each do |agent_data|
        agent = agent_data[:agent]
        action = agent_data[:action]
        x, y = agent_data[:position]
        
        next unless agent&.alive?
        
        execute_action(agent, action, x, y, new_grid)
        
        # Apply energy decay
        agent.energy -= Mutation.configuration.energy_decay
        
        # Keep agent if still alive
        new_grid[y][x] = agent if agent.alive?
      end
      
      @grid = new_grid
      @tick += 1
      
      update_statistics
    end
    
    def build_environment(x, y)
      neighbors = get_neighbors(x, y)
      
      {
        neighbor_energy: calculate_neighbor_energy(neighbors),
        neighbors: neighbors.map { |n| n&.energy || 0 },
        position: [x, y],
        world_size: [@width, @height],
        tick: @tick
      }
    end
    
    def get_neighbors(x, y)
      neighbors = []
      
      # 8-directional neighbors (Moore neighborhood)
      (-1..1).each do |dy|
        (-1..1).each do |dx|
          next if dx == 0 && dy == 0  # Skip center cell
          
          nx, ny = x + dx, y + dy
          if valid_position?(nx, ny)
            neighbors << @grid[ny][nx]
          else
            neighbors << nil
          end
        end
      end
      
      neighbors
    end
    
    def valid_position?(x, y)
      x >= 0 && x < @width && y >= 0 && y < @height
    end
    
    def calculate_neighbor_energy(neighbors)
      energies = neighbors.map { |n| n&.energy || 0 }
      energies.max
    end
    
    def execute_action(agent, action, x, y, new_grid)
      case action
      when :attack
        execute_attack(agent, x, y)
      when :rest
        execute_rest(agent)
      when :replicate
        execute_replication(agent, x, y, new_grid)
      when :die
        # Agent dies, don't add to new grid
      end
    end
    
    def execute_attack(agent, x, y)
      target_x, target_y = find_attack_target(x, y)
      return unless target_x && target_y
      
      target = @grid[target_y][target_x]
      return unless target&.alive?
      
      damage = Mutation.configuration.attack_damage
      gain = Mutation.configuration.attack_energy_gain
      
      target.energy -= damage
      agent.energy += gain
      
      Mutation.logger.debug("Agent #{agent.id} attacked #{target.id} at (#{target_x},#{target_y}) for #{damage} damage")
    end
    
    def execute_rest(agent)
      gain = Mutation.configuration.rest_energy_gain
      agent.energy += gain
      
      Mutation.logger.debug("Agent #{agent.id} rested, gained #{gain} energy")
    end
    
    def execute_replication(agent, x, y, new_grid)
      return unless agent.energy >= Mutation.configuration.replication_cost
      
      empty_x, empty_y = find_empty_adjacent_position(x, y)
      return unless empty_x && empty_y
      
      cost = Mutation.configuration.replication_cost
      offspring = @mutation_engine.mutate(agent)
      
      new_grid[empty_y][empty_x] = offspring
      agent.energy -= cost
      @statistics[:total_agents_created] += 1
      
      Mutation.logger.debug("Agent #{agent.id} replicated at (#{empty_x},#{empty_y}), created #{offspring.id}")
    end
    
    def find_attack_target(x, y)
      candidates = []
      
      # Check all 8 neighbors for attack targets
      (-1..1).each do |dy|
        (-1..1).each do |dx|
          next if dx == 0 && dy == 0  # Skip center cell
          
          nx, ny = x + dx, y + dy
          if valid_position?(nx, ny) && @grid[ny][nx]&.alive?
            candidates << [nx, ny]
          end
        end
      end
      
      return nil if candidates.empty?
      
      # Attack the neighbor with highest energy
      target_x, target_y = candidates.max_by { |tx, ty| @grid[ty][tx].energy }
      [target_x, target_y]
    end
    
    def find_empty_adjacent_position(x, y)
      candidates = []
      
      # Check all 8 neighbors for empty positions
      (-1..1).each do |dy|
        (-1..1).each do |dx|
          next if dx == 0 && dy == 0  # Skip center cell
          
          nx, ny = x + dx, y + dy
          if valid_position?(nx, ny) && @grid[ny][nx].nil?
            candidates << [nx, ny]
          end
        end
      end
      
      return nil if candidates.empty?
      candidates.sample
    end
    
    def all_dead?
      @grid.all? { |row| row.all? { |agent| agent.nil? || agent.dead? } }
    end
    
    def living_agents
      @grid.flatten.compact.select(&:alive?)
    end
    
    def agent_count
      living_agents.count
    end
    
    def average_energy
      agents = living_agents
      return 0 if agents.empty?
      
      agents.sum(&:energy) / agents.size.to_f
    end
    
    def fittest_agent
      living_agents.max_by(&:fitness)
    end
    
    def update_statistics
      current_max_fitness = fittest_agent&.fitness || 0
      @statistics[:max_fitness_achieved] = [
        @statistics[:max_fitness_achieved], 
        current_max_fitness
      ].max
      
      @statistics[:longest_survival_ticks] = [
        @statistics[:longest_survival_ticks], 
        @tick
      ].max
    end
    
    def prepare_for_reset
      survivor = fittest_agent
      if survivor
        @last_survivor_code = survivor.code_str
        Mutation.logger.generation("🔬 Survivor: #{survivor}")
        Mutation.logger.debug("Survivor code:\n#{survivor.code_str}")
      else
        Mutation.logger.warn("No survivors found, using default code")
        @last_survivor_code = nil
      end
      
      @tick = 0
    end
    
    def status_line
      agents = living_agents
      "T:#{@tick.to_s.rjust(3)} G:#{@generation} A:#{agents.size} | #{@width}x#{@height} grid"
    end
    
    def grid_display
      @grid.map do |row|
        row.map do |agent|
          if agent&.alive?
            agent.energy.to_s.rjust(2, '0')
          else
            ' . '
          end
        end.join(' ')
      end.join("\n")
    end
    
    def detailed_status
      agents = living_agents
      return "No living agents" if agents.empty?
      
      avg_energy = average_energy.round(1)
      max_fitness = fittest_agent&.fitness || 0
      
      "Agents: #{agents.size}, Avg Energy: #{avg_energy}, Max Fitness: #{max_fitness}"
    end
    
    private
    
    def process_agents_parallel
      processor_count = Mutation.configuration.processor_count || Parallel.processor_count
      
      # Create agent data for parallel processing
      agent_data = []
      @grid.each_with_index do |row, y|
        row.each_with_index do |agent, x|
          if agent&.alive?
            agent_data << { agent: agent, position: [x, y], environment: build_environment(x, y) }
          end
        end
      end
      
      # Process agents in parallel using threads (not processes to avoid marshalling Procs)
      Parallel.map(agent_data, in_threads: processor_count) do |data|
        agent = data[:agent]
        env = data[:environment]
        action = agent.act(env)
        
        {
          agent: agent,
          action: action,
          position: data[:position]
        }
      end
    end
    
    def process_agents_sequential
      agent_actions = []
      
      @grid.each_with_index do |row, y|
        row.each_with_index do |agent, x|
          if agent&.alive?
            env = build_environment(x, y)
            action = agent.act(env)
            
            agent_actions << {
              agent: agent,
              action: action,
              position: [x, y]
            }
          end
        end
      end
      
      agent_actions
    end
  end
end 