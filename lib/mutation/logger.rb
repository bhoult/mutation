# frozen_string_literal: true

require 'logger'
require 'colorize'

module Mutation
  class Logger
    LEVELS = {
      debug: 0,
      info: 1,
      warn: 2,
      error: 3,
      fatal: 4
    }.freeze

    def initialize(level = :info)
      @level = LEVELS[level] || LEVELS[:info]
      @appenders = [create_default_appender]
      @suppress_output = false
    end

    def add_appender(appender)
      @appenders << appender
    end

    attr_writer :suppress_output

    def suppress_output?
      @suppress_output
    end

    def debug(message)
      log(:debug, message.to_s.colorize(:light_black))
    end

    def info(message)
      log(:info, message.to_s.colorize(:white))
    end

    def warn(message)
      log(:warn, message.to_s.colorize(:yellow))
    end

    def error(message)
      log(:error, message.to_s.colorize(:red))
    end

    def fatal(message)
      log(:fatal, message.to_s.colorize(:red).bold)
    end

    def simulation(message)
      log(:info, message.to_s.colorize(:cyan))
    end

    def mutation(message)
      log(:info, message.to_s.colorize(:magenta))
    end

    def generation(message)
      log(:info, message.to_s.colorize(:green))
    end

    private

    def create_default_appender
      default_logger = ::Logger.new($stdout)
      default_logger.formatter = proc do |severity, datetime, _progname, msg|
        timestamp = datetime.strftime('%H:%M:%S')
        "[#{timestamp}] #{severity}: #{msg}
"
      end
      default_logger
    end

    def log(level, message)
      return unless should_log?(level)
      return if @suppress_output

      @appenders.each do |appender|
        if appender.is_a?(::Logger)
          appender.send(level, message)
        elsif appender.respond_to?(:log_message)
          appender.log_message(level, message)
        end
      end
    end

    def should_log?(level)
      LEVELS[level] >= @level
    end
  end
end
