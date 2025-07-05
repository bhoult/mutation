# frozen_string_literal: true

require_relative 'mutation/version'
require_relative 'mutation/configuration'
require_relative 'mutation/logger'
require_relative 'mutation/agent'
require_relative 'mutation/agent_process'
require_relative 'mutation/agent_manager'
require_relative 'mutation/world'
require_relative 'mutation/mutation_engine'
require_relative 'mutation/curses_display'
require_relative 'mutation/survivor_logger'
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

    def reset!
      @configuration = nil
      @logger = nil
    end
  end
end
