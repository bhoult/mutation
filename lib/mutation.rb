# frozen_string_literal: true

require_relative 'mutation/version'
require_relative 'mutation/configuration'
require_relative 'mutation/logger'
require_relative 'mutation/simulation_log_manager'
require_relative 'mutation/agent'
require_relative 'mutation/agent_manager'
require_relative 'mutation/genetic_pool'
require_relative 'mutation/mutation_engine'
require_relative 'mutation/world_impl'
require_relative 'mutation/world'
require_relative 'mutation/curses_display'
require_relative 'mutation/survivor_logger'
require_relative 'mutation/mutated_agent_manager'
require_relative 'mutation/simulator'
require_relative 'mutation/cli'

module Mutation
  class Error < StandardError; end

  class << self
    def configuration
      @configuration ||= Configuration.new
    end

    def configure
      yield(configuration)
    end

    def logger
      @logger ||= Logger.new(configuration.log_level)
    end
    
    def log_manager
      @log_manager ||= SimulationLogManager.new
    end

    def reset!
      @configuration = nil
      @logger = nil
      @log_manager = nil
    end
  end
end
