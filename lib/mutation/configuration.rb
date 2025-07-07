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
                  :max_agent_count, :parallel_processing_threshold, :max_parallel_threads, :max_agent_lifespan,
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
                  # Agent logging
                  :max_agent_logs_per_simulation,
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
      @max_agent_lifespan = 1000
      
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
      
      # Agent logging
      @max_agent_logs_per_simulation = 100
      
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
      @agent_memory_base_path = File.join(Dir.pwd, 'agents', 'memory')
      
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
      @default_agent_executable = File.join(Dir.pwd, 'agents', 'active_explorer_agent.rb') # Default agent executable path
    end

    def load_config_file
      config = YAML.load_file(config_file_path)
      
      # Handle flat structure (legacy) and nested structure (new)
      if config.key?('world') || config.key?('energy') || config.key?('action_costs')
        # New nested structure
        load_nested_config(config)
      else
        # Legacy flat structure
        load_flat_config(config)
      end
    rescue StandardError => e
      # Use warn instead of puts so it can be suppressed during curses mode
      warn "Warning: Could not load config file: #{e.message}"
    end
    
    def load_nested_config(config)
      # Map nested config sections to flat attribute names
      config.each do |section, values|
        case section
        when 'world'
          load_section(values, {
            'size' => :world_size,
            'width' => :world_width,
            'height' => :world_height,
            'initial_coverage' => :initial_coverage,
            'agent_vision_radius' => :agent_vision_radius,
            'performance_log_frequency' => :world_performance_log_frequency,
            'agent_check_frequency' => :world_agent_check_frequency
          })
        when 'energy'
          load_section(values, {
            'decay' => :energy_decay,
            'precision_threshold' => :energy_precision_threshold,
            'initial_min' => :initial_energy_min,
            'initial_max' => :initial_energy_max,
            'initial_legacy' => :initial_energy
          })
        when 'action_costs'
          load_action_costs(values)
        when 'agent_management'
          load_section(values, {
            'max_agent_count' => :max_agent_count,
            'parallel_processing_threshold' => :parallel_processing_threshold,
            'max_parallel_threads' => :max_parallel_threads,
            'max_lifespan' => :max_agent_lifespan,
            'response_timeout' => :agent_response_timeout,
            'process_cleanup_delay' => :process_cleanup_delay,
            'graceful_death_timeout' => :graceful_death_timeout,
            'default_timeout_ms' => :default_timeout_ms,
            'timeout_ms' => :agent_timeout_ms
          })
        when 'simulation'
          load_section(values, {
            'delay' => :simulation_delay,
            'max_ticks' => :max_ticks,
            'auto_reset' => :auto_reset,
            'safe_mode' => :safe_mode,
            'status_log_frequency' => :simulator_status_log_frequency,
            'status_log_early_threshold' => :simulator_status_log_early_threshold,
            'loop_sleep_interval' => :simulator_loop_sleep_interval,
            'min_world_size' => :simulator_min_world_size,
            'fallback_width' => :simulator_fallback_width,
            'fallback_height' => :simulator_fallback_height
          })
        when 'parallel'
          load_section(values, {
            'enabled' => :parallel_agents,
            'processor_count' => :processor_count
          })
        when 'mutation'
          load_section(values, {
            'rate' => :mutation_rate,
            'probability' => :mutation_probability,
            'small_variation_min' => :mutation_small_variation_min,
            'small_variation_max' => :mutation_small_variation_max,
            'large_variation_percent' => :mutation_large_variation_percent,
            'probability_variation_min' => :mutation_probability_variation_min,
            'probability_variation_max' => :mutation_probability_variation_max,
            'probability_min_bound' => :mutation_probability_min_bound,
            'probability_max_bound' => :mutation_probability_max_bound,
            'threshold_variation_min' => :mutation_threshold_variation_min,
            'threshold_variation_max' => :mutation_threshold_variation_max,
            'operator_probability' => :mutation_operator_probability,
            'personality_shift_min' => :mutation_personality_shift_min,
            'personality_shift_max' => :mutation_personality_shift_max,
            'personality_min_bound' => :mutation_personality_min_bound,
            'personality_max_bound' => :mutation_personality_max_bound,
            'personality_int_shift_min' => :mutation_personality_int_shift_min,
            'personality_int_shift_max' => :mutation_personality_int_shift_max,
            'personality_int_max_bound' => :mutation_personality_int_max_bound
          })
        when 'genetic_pool'
          load_section(values, {
            'fingerprint_length' => :genetic_fingerprint_length,
            'survival_threshold' => :genetic_survival_threshold,
            'sample_size' => :genetic_sample_size
          })
        when 'logging'
          load_section(values, {
            'level' => :log_level,
            'max_agent_logs_per_simulation' => :max_agent_logs_per_simulation,
            'survivor_filename' => :survivors_log,
            'survivor_max_count' => :survivor_log_max_count
          })
        when 'display'
          load_section(values, {
            'visual_mode' => :visual_mode,
            'bottom_panel_height' => :display_bottom_panel_height,
            'help_lines' => :display_help_lines,
            'border_size' => :display_border_size,
            'fps' => :display_fps,
            'status_panel_width_ratio' => :display_status_panel_width_ratio,
            'energy_very_high_threshold' => :display_energy_very_high_threshold,
            'energy_high_threshold' => :display_energy_high_threshold,
            'energy_medium_threshold' => :display_energy_medium_threshold,
            'energy_low_threshold' => :display_energy_low_threshold,
            'color_high_threshold' => :display_color_high_threshold,
            'color_medium_threshold' => :display_color_medium_threshold,
            'color_low_threshold' => :display_color_low_threshold
          })
        when 'benchmark'
          load_section(values, {
            'default_size' => :benchmark_default_size,
            'default_generations' => :benchmark_default_generations,
            'default_runs' => :benchmark_default_runs
          })
        when 'file_paths'
          load_section(values, {
            'agents_directory' => :agents_directory,
            'base_agent_path' => :base_agent_path,
            'agent_memory_base_path' => :agent_memory_base_path,
            'default_agent_executable' => :default_agent_executable
          })
        when 'fitness'
          load_section(values, {
            'energy_multiplier' => :fitness_energy_multiplier,
            'generation_multiplier' => :fitness_generation_multiplier
          })
        when 'agent_behavior'
          load_section(values, {
            'personality_aggression_min' => :agent_personality_aggression_min,
            'personality_aggression_max' => :agent_personality_aggression_max,
            'personality_greed_min' => :agent_personality_greed_min,
            'personality_greed_max' => :agent_personality_greed_max,
            'personality_cooperation_min' => :agent_personality_cooperation_min,
            'personality_cooperation_max' => :agent_personality_cooperation_max,
            'personality_death_threshold_min' => :agent_personality_death_threshold_min,
            'personality_death_threshold_max' => :agent_personality_death_threshold_max,
            'death_history_check_length' => :agent_death_history_check_length,
            'replication_energy_base' => :agent_replication_energy_base,
            'replication_energy_greed_multiplier' => :agent_replication_energy_greed_multiplier,
            'max_replications' => :agent_max_replications,
            'min_replication_interval' => :agent_min_replication_interval,
            'attack_min_energy' => :agent_attack_min_energy,
            'weak_attack_min_energy' => :agent_weak_attack_min_energy,
            'weak_attack_min_self_energy' => :agent_weak_attack_min_self_energy,
            'rest_energy_base' => :agent_rest_energy_base,
            'rest_energy_greed_multiplier' => :agent_rest_energy_greed_multiplier
          })
        end
      end
    end
    
    def load_flat_config(config)
      # Legacy flat structure loading
      config.each do |key, value|
        if key == 'action_costs' && value.is_a?(Hash)
          load_action_costs(value)
        elsif respond_to?("#{key}=")
          instance_variable_set("@#{key}", value)
        end
      end
    end
    
    def load_section(section_values, mapping)
      return unless section_values.is_a?(Hash)
      
      section_values.each do |key, value|
        if mapping[key] && respond_to?("#{mapping[key]}=")
          instance_variable_set("@#{mapping[key]}", value)
        end
      end
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
