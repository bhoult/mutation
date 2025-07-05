# frozen_string_literal: true

require 'yaml'

module Mutation
  class Configuration
    attr_accessor :world_size, :world_width, :world_height, :initial_energy, :energy_decay, :attack_damage,
                  :attack_energy_gain, :rest_energy_gain, :replication_cost,
                  :mutation_rate, :mutation_probability, :log_level,
                  :simulation_delay, :max_ticks, :auto_reset, :safe_mode,
                  :parallel_agents, :processor_count, :visual_mode, :survivors_log,
                  :initial_coverage, :process_based_agents, :agent_timeout_ms,
                  :default_agent_executable

    def initialize
      set_defaults
      load_config_file if config_file_exists?
    end

    def set_defaults
      @world_size = 20
      @world_width = nil   # nil means use square grid from world_size
      @world_height = nil  # nil means use square grid from world_size
      @initial_energy = 10
      @energy_decay = 0.3  # Reduced metabolic cost
      @attack_damage = 3
      @attack_energy_gain = 2   # Successful attacks are rewarding
      @rest_energy_gain = 1.0  # Resting provides some energy
      @replication_cost = 5
      @mutation_rate = 0.15  # More frequent mutations
      @mutation_probability = 0.1  # More mutation logging
      @log_level = :info
      @simulation_delay = 0.2
      @max_ticks = nil
      @auto_reset = true
      @safe_mode = true
      @parallel_agents = true # Enabled for process-based agents (GIL doesn't affect external processes)
      @processor_count = nil   # nil means use all available processors
      @visual_mode = false     # Use curses display
      @survivors_log = 'survivors.log' # Survivor codes log file
      @initial_coverage = 0.1 # 10% initial world coverage
      @process_based_agents = true # Use external process agents instead of in-process Ruby
      @agent_timeout_ms = 1000 # Timeout for agent responses in milliseconds
      @default_agent_executable = File.join(Dir.pwd, 'examples', 'agents', 'ruby_agent.rb') # Default agent executable path
    end

    def load_config_file
      config = YAML.load_file(config_file_path)
      config.each do |key, value|
        instance_variable_set("@#{key}", value) if respond_to?("#{key}=")
      end
    rescue StandardError => e
      puts "Warning: Could not load config file: #{e.message}"
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
  end
end
