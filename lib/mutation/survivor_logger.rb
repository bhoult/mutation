# frozen_string_literal: true

require 'digest'

module Mutation
  class SurvivorLogger
    SURVIVORS_LOG_FILE = 'survivors.log'

    def initialize(log_file: nil)
      @log_file = log_file || File.join(Dir.pwd, SURVIVORS_LOG_FILE)
      @existing_codes = load_existing_codes
    end

    def log_survivors(agents)
      return if agents.empty?

      # Get up to 3 survivors, sorted by fitness
      survivors = agents.select(&:alive?)
                        .sort_by(&:fitness)
                        .reverse
                        .first(3)

      return if survivors.empty?

      new_codes = []
      survivors.each_with_index do |agent, index|
        code_hash = Digest::SHA256.hexdigest(agent.code_str)

        # Only log if this code hasn't been seen before
        next if @existing_codes.include?(code_hash)

        new_codes << {
          rank: index + 1,
          agent: agent,
          code_hash: code_hash,
          timestamp: Time.now
        }
        @existing_codes.add(code_hash)
      end

      # Write new codes to log file
      write_survivors_to_log(new_codes) unless new_codes.empty?

      new_codes.size
    end

    private

    def load_existing_codes
      codes = Set.new

      return codes unless File.exist?(@log_file)

      File.readlines(@log_file).each do |line|
        codes.add(::Regexp.last_match(1).strip) if line.match(/^# Code Hash: (.+)$/)
      end

      codes
    rescue StandardError => e
      Mutation.logger.warn("Failed to load existing survivor codes: #{e.message}")
      Set.new
    end

    def write_survivors_to_log(new_codes)
      File.open(@log_file, 'a') do |file|
        new_codes.each do |entry|
          agent = entry[:agent]

          file.puts
          file.puts '=' * 80
          file.puts "# Survivor #{entry[:rank]} logged at #{entry[:timestamp]}"
          file.puts "# Generation: #{agent.generation}"
          file.puts "# Energy: #{agent.energy}"
          file.puts "# Fitness: #{agent.fitness}"
          file.puts "# Mutations: #{agent.mutations_count}"
          file.puts "# Code Hash: #{entry[:code_hash]}"
          file.puts '=' * 80
          file.puts
          file.puts '```ruby'
          file.puts agent.code_str
          file.puts '```'
          file.puts
        end
      end

      Mutation.logger.info("Logged #{new_codes.size} new survivor code(s) to #{@log_file}")
    rescue StandardError => e
      Mutation.logger.error("Failed to write survivors to log: #{e.message}")
    end
  end
end
