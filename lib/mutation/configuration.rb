# frozen_string_literal: true

require 'yaml'

module Mutation
  class Configuration
    attr_accessor :world_size, :world_width, :world_height, :initial_energy, :energy_decay, :action_costs,
                  :attack_damage, :attack_energy_gain, :rest_energy_gain, :replication_cost, :dead_agent_energy_gain,
                  :mutation_rate, :mutation_probability, :log_level,
                  :simulation_delay, :max_ticks, :auto_reset, :safe_mode,
                  :parallel_agents, :processor_count, :visual_mode, :survivors_log,
                  :initial_coverage, :agent_timeout_ms, :default_agent_executable,
                  # Initial energy range
                  :initial_energy_min, :initial_energy_max,
                  # Action costs
                  :base_action_cost, :attack_action_cost, :additional_replication_cost,
                  # Agent management
                  :max_agent_count, :parallel_processing_threshold, :max_parallel_threads,
                  # Process management
                  :agent_response_timeout, :process_cleanup_delay, :graceful_death_timeout, :default_timeout_ms,
                  # Fitness calculation
                  :fitness_energy_multiplier, :fitness_generation_multiplier,
                  # Mutation engine parameters
                  :mutation_small_variation_min, :mutation_small_variation_max, :mutation_large_variation_percent,
                  :mutation_probability_variation_min, :mutation_probability_variation_max,
                  :mutation_probability_min_bound, :mutation_probability_max_bound,
                  :mutation_threshold_variation_min, :mutation_threshold_variation_max,
                  :mutation_operator_probability, :mutation_personality_shift_min, :mutation_personality_shift_max,
                  :mutation_personality_min_bound, :mutation_personality_max_bound,
                  :mutation_personality_int_shift_min, :mutation_personality_int_shift_max,
                  :mutation_personality_int_max_bound,
                  # Genetic pool settings
                  :genetic_fingerprint_length, :genetic_survival_threshold, :genetic_sample_size,
                  # Display settings
                  :display_bottom_panel_height, :display_help_lines, :display_border_size, :display_fps,
                  :display_status_panel_width_ratio, :display_energy_very_high_threshold,
                  :display_energy_high_threshold, :display_energy_medium_threshold, :display_energy_low_threshold,
                  :display_color_high_threshold, :display_color_medium_threshold, :display_color_low_threshold,
                  # Simulation flow control
                  :simulator_fallback_width, :simulator_fallback_height, :simulator_status_log_frequency,
                  :simulator_status_log_early_threshold, :simulator_loop_sleep_interval,
                  # Benchmark defaults
                  :benchmark_default_size, :benchmark_default_generations, :benchmark_default_runs,
                  # Survivor logging
                  :survivor_log_max_count,
                  # Agent behavior defaults
                  :agent_personality_aggression_min, :agent_personality_aggression_max,
                  :agent_personality_greed_min, :agent_personality_greed_max,
                  :agent_personality_cooperation_min, :agent_personality_cooperation_max,
                  :agent_personality_death_threshold_min, :agent_personality_death_threshold_max,
                  :agent_death_history_check_length, :agent_replication_energy_base,
                  :agent_replication_energy_greed_multiplier, :agent_attack_min_energy,
                  :agent_rest_energy_base, :agent_rest_energy_greed_multiplier,
                  :agent_weak_attack_min_energy, :agent_weak_attack_min_self_energy,
                  :agent_max_replications, :agent_min_replication_interval,
                  # File system paths
                  :agents_directory, :base_agent_path, :agent_memory_base_path

    def initialize
      set_defaults
      load_config_file if config_file_exists?
    end

    def set_defaults
      # World settings
      @world_size = 20
      @world_width = nil   # nil means use square grid from world_size
      @world_height = nil  # nil means use square grid from world_size
      @initial_energy = 10
      @initial_coverage = 0.1 # 10% initial world coverage
      
      # Energy system
      @energy_decay = 1
      
      # Initial energy range
      @initial_energy_min = 8
      @initial_energy_max = 12
      
      # Action costs (structured format)
      @action_costs = {
        base_cost: 0.2,
        attack: {
          cost: 1.0,
          damage: 3,
          energy_gain: 1
        },
        rest: {
          energy_gain: 1
        },
        replicate: {
          cost: 5
        },
        move: {
          dead_agent_energy_gain: 10
        }
      }
      
      # Legacy individual cost settings (for backward compatibility)
      @base_action_cost = @action_costs[:base_cost]
      @attack_action_cost = @action_costs[:attack][:cost]
      @additional_replication_cost = 0.5
      @attack_damage = @action_costs[:attack][:damage]
      @attack_energy_gain = @action_costs[:attack][:energy_gain]
      @rest_energy_gain = @action_costs[:rest][:energy_gain]
      @replication_cost = @action_costs[:replicate][:cost]
      @dead_agent_energy_gain = @action_costs[:move][:dead_agent_energy_gain]
      
      # Agent management
      @max_agent_count = 100
      @parallel_processing_threshold = 5
      @max_parallel_threads = 8
      
      # Process management
      @agent_response_timeout = 0.1
      @process_cleanup_delay = 0.1
      @graceful_death_timeout = 0.5
      @default_timeout_ms = 1000
      @agent_timeout_ms = 1000 # Timeout for agent responses in milliseconds
      
      # Fitness calculation
      @fitness_energy_multiplier = 10
      @fitness_generation_multiplier = 5
      
      # Mutation engine parameters
      @mutation_small_variation_min = 1
      @mutation_small_variation_max = 2
      @mutation_large_variation_percent = 0.2
      @mutation_probability_variation_min = 0.1
      @mutation_probability_variation_max = 0.3
      @mutation_probability_min_bound = 0.1
      @mutation_probability_max_bound = 0.9
      @mutation_threshold_variation_min = 1
      @mutation_threshold_variation_max = 3
      @mutation_operator_probability = 0.1
      @mutation_personality_shift_min = -0.2
      @mutation_personality_shift_max = 0.2
      @mutation_personality_min_bound = 0.1
      @mutation_personality_max_bound = 1.0
      @mutation_personality_int_shift_min = -1
      @mutation_personality_int_shift_max = 1
      @mutation_personality_int_max_bound = 5
      
      # Genetic pool settings
      @genetic_fingerprint_length = 16
      @genetic_survival_threshold = 100
      @genetic_sample_size = 5
      
      # Display settings
      @display_bottom_panel_height = 5
      @display_help_lines = 1
      @display_border_size = 3
      @display_fps = 30
      @display_status_panel_width_ratio = 0.25
      @display_energy_very_high_threshold = 15
      @display_energy_high_threshold = 10
      @display_energy_medium_threshold = 5
      @display_energy_low_threshold = 1
      @display_color_high_threshold = 8
      @display_color_medium_threshold = 4
      @display_color_low_threshold = 1
      
      # Simulation flow control
      @simulator_fallback_width = 80
      @simulator_fallback_height = 24
      @simulator_status_log_frequency = 10
      @simulator_status_log_early_threshold = 5
      @simulator_loop_sleep_interval = 0.01
      
      # Benchmark defaults
      @benchmark_default_size = 20
      @benchmark_default_generations = 10
      @benchmark_default_runs = 3
      
      # Survivor logging
      @survivor_log_max_count = 3
      
      # Agent behavior defaults
      @agent_personality_aggression_min = 0.3
      @agent_personality_aggression_max = 0.9
      @agent_personality_greed_min = 0.2
      @agent_personality_greed_max = 0.8
      @agent_personality_cooperation_min = 0.1
      @agent_personality_cooperation_max = 0.6
      @agent_personality_death_threshold_min = 1
      @agent_personality_death_threshold_max = 3
      @agent_death_history_check_length = 3
      @agent_replication_energy_base = 6
      @agent_replication_energy_greed_multiplier = 4
      @agent_attack_min_energy = 3
      @agent_rest_energy_base = 4
      @agent_rest_energy_greed_multiplier = 3
      @agent_weak_attack_min_energy = 2
      @agent_weak_attack_min_self_energy = 4
      @agent_max_replications = 2
      @agent_min_replication_interval = 3
      
      # File system paths
      @agents_directory = 'agents'
      @base_agent_path = 'examples/agents/ruby_agent.rb'
      @agent_memory_base_path = '/tmp/agents'
      
      # Core simulation settings
      @mutation_rate = 0.5
      @mutation_probability = 0.05
      @log_level = :info
      @simulation_delay = 0.2
      @max_ticks = nil
      @auto_reset = true
      @safe_mode = true
      @parallel_agents = true # Enabled for agents (true parallelism with processes)
      @processor_count = nil   # nil means use all available processors
      @visual_mode = false     # Use curses display
      @survivors_log = 'survivors.log' # Survivor codes log file
      @default_agent_executable = File.join(Dir.pwd, 'examples', 'agents', 'ruby_agent.rb') # Default agent executable path
    end

    def load_config_file
      config = YAML.load_file(config_file_path)
      config.each do |key, value|
        if key == 'action_costs' && value.is_a?(Hash)
          # Handle nested action_costs structure
          load_action_costs(value)
        elsif respond_to?("#{key}=")
          instance_variable_set("@#{key}", value)
        end
      end
    rescue StandardError => e
      # Use warn instead of puts so it can be suppressed during curses mode
      warn "Warning: Could not load config file: #{e.message}"
    end
    
    def load_action_costs(costs_hash)
      # Convert string keys to symbols and merge with defaults
      symbolized_costs = deep_symbolize_keys(costs_hash)
      @action_costs = @action_costs.merge(symbolized_costs)
      
      # Update legacy individual cost settings for backward compatibility
      @base_action_cost = @action_costs[:base_cost] if @action_costs[:base_cost]
      
      if @action_costs[:attack]
        @attack_action_cost = @action_costs[:attack][:cost] if @action_costs[:attack][:cost]
        @attack_damage = @action_costs[:attack][:damage] if @action_costs[:attack][:damage]
        @attack_energy_gain = @action_costs[:attack][:energy_gain] if @action_costs[:attack][:energy_gain]
      end
      
      if @action_costs[:rest]
        @rest_energy_gain = @action_costs[:rest][:energy_gain] if @action_costs[:rest][:energy_gain]
      end
      
      if @action_costs[:replicate]
        @replication_cost = @action_costs[:replicate][:cost] if @action_costs[:replicate][:cost]
      end
      
      if @action_costs[:move]
        @dead_agent_energy_gain = @action_costs[:move][:dead_agent_energy_gain] if @action_costs[:move][:dead_agent_energy_gain]
      end
    end
    
    def deep_symbolize_keys(hash)
      hash.each_with_object({}) do |(key, value), result|
        new_key = key.to_sym
        new_value = value.is_a?(Hash) ? deep_symbolize_keys(value) : value
        result[new_key] = new_value
      end
    end

    def config_file_exists?
      File.exist?(config_file_path)
    end

    def config_file_path
      File.join(Dir.pwd, 'config', 'mutation.yml')
    end

    def to_hash
      instance_variables.each_with_object({}) do |var, hash|
        key = var.to_s.delete('@')
        hash[key] = instance_variable_get(var)
      end
    end

    def random_initial_energy
      # Validate that min <= max
      min_val = [initial_energy_min || 1, 1].max
      max_val = [initial_energy_max || min_val, min_val].max
      
      rand(min_val..max_val)
    end
  end
end
