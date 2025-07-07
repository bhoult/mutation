# frozen_string_literal: true

require 'thor'

module Mutation
  class CLI < Thor
    desc 'start', 'Start the mutation simulation'
    option :size, type: :numeric, aliases: '-s', desc: 'World size (for square grid)'
    option :width, type: :numeric, aliases: '-w', desc: 'World width (for rectangular grid)'
    option :height, type: :numeric, aliases: '-h', desc: 'World height (for rectangular grid)'
    option :energy, type: :numeric, aliases: '-e', desc: 'Initial energy'
    option :delay, type: :numeric, aliases: '-d', desc: 'Simulation delay'
    option :ticks, type: :numeric, aliases: '-t', desc: 'Max ticks to run'
    option :config, type: :string, aliases: '-c', desc: 'Configuration file'
    option :verbose, type: :boolean, aliases: '-v', desc: 'Verbose output'
    option :safe, type: :boolean, desc: 'Safe mode (default: true)'
    option :parallel, type: :boolean, aliases: '-p', desc: 'Enable parallel processing'
    option :processors, type: :numeric, desc: 'Number of processors to use'
    option :agents, type: :array, desc: 'Agent executable paths'
    option :simulations, type: :numeric, aliases: '-n', desc: 'Number of simulations to run'
    option :visual, type: :boolean, aliases: '-V', desc: 'Enable visual mode'
    def start
      configure_from_options

      agent_executables = options[:agents]
      
      simulator = Simulator.new(
        world_size: options[:size],
        width: options[:width],
        height: options[:height],
        agent_executables: agent_executables,
        curses_mode: options[:visual]
      )

      if options[:simulations]
        count = options[:simulations]
        count.times do |i|
          Mutation.logger.info("--- Simulation #{i + 1}/#{count} ---")
          simulator.start
          simulator.reset unless i == count - 1
        end
      elsif options[:ticks]
        simulator.run_for_ticks(options[:ticks])
      else
        simulator.start
      end
    end

    desc 'interactive', 'Start interactive simulation mode'
    option :size, type: :numeric, aliases: '-s', desc: 'World size (for square grid)'
    option :width, type: :numeric, aliases: '-w', desc: 'World width (for rectangular grid)'
    option :height, type: :numeric, aliases: '-h', desc: 'World height (for rectangular grid)'
    option :config, type: :string, aliases: '-c', desc: 'Configuration file'
    option :parallel, type: :boolean, aliases: '-p', desc: 'Enable parallel processing'
    option :processors, type: :numeric, desc: 'Number of processors to use'
    option :agents, type: :array, desc: 'Agent executable paths'
    def interactive
      configure_from_options

      agent_executables = options[:agents]
      
      simulator = Simulator.new(
        world_size: options[:size],
        width: options[:width],
        height: options[:height],
        agent_executables: agent_executables
      )

      puts 'Interactive Mutation Simulation'
      puts 'Commands: start, stop, pause, resume, step, status, report, reset, grid, quit'
      puts "Type 'help' for more information"

      loop do
        print '> '
        input = gets.chomp.split
        command = input[0]&.downcase

        case command
        when 'start'
          simulator.start
        when 'stop'
          simulator.stop
        when 'pause'
          simulator.pause
        when 'resume'
          simulator.resume
        when 'step'
          count = input[1]&.to_i || 1
          count.times { simulator.step }
        when 'status'
          puts simulator.current_status
        when 'report'
          puts simulator.detailed_report
        when 'grid'
          puts simulator.world.grid_display
        when 'reset'
          simulator.reset
        when 'help'
          print_interactive_help
        when 'quit', 'exit', 'q'
          break
        else
          puts "Unknown command: #{command}"
        end
      end
    end

    desc 'config', 'Show current configuration'
    def config
      puts 'Current Configuration:'
      puts '=' * 30

      Mutation.configuration.to_hash.each do |key, value|
        puts "#{key.to_s.ljust(20)}: #{value}"
      end
    end

    desc 'benchmark', 'Run benchmark tests'
    option :size, type: :numeric, default: 20, desc: 'World size'
    option :generations, type: :numeric, default: 10, desc: 'Number of generations'
    option :runs, type: :numeric, default: 3, desc: 'Number of runs'
    def benchmark
      puts 'Running benchmark tests...'

      results = []

      options[:runs].times do |run|
        puts "Run #{run + 1}/#{options[:runs]}"

        start_time = Time.now
        simulator = Simulator.new(world_size: options[:size])

        # Run until specified number of extinctions
        extinctions = 0
        while extinctions < options[:generations]
          simulator.run_until_extinction
          extinctions += 1
        end

        end_time = Time.now
        runtime = end_time - start_time

        results << {
          run: run + 1,
          runtime: runtime,
          extinctions: extinctions,
          total_ticks: simulator.statistics[:total_ticks]
        }
      end

      print_benchmark_results(results)
    end

    desc 'version', 'Show version information'
    def version
      puts "Mutation Simulator v#{Mutation::VERSION}"
    end

    private

    def configure_from_options
      if options[:config]
        # Load custom config file
        config_path = options[:config]
        if File.exist?(config_path)
          config = YAML.load_file(config_path)
          Mutation.configure do |c|
            config.each do |key, value|
              c.send("#{key}=", value) if c.respond_to?("#{key}=")
            end
          end
        else
          puts "Config file not found: #{config_path}"
          exit 1
        end
      end

      # Override with command line options
      Mutation.configure do |config|
        config.world_size = options[:size] if options[:size]
        config.world_width = options[:width] if options[:width]
        config.world_height = options[:height] if options[:height]
        config.initial_energy = options[:energy] if options[:energy]
        config.simulation_delay = options[:delay] if options[:delay]
        config.max_ticks = options[:ticks] if options[:ticks]
        config.safe_mode = options[:safe] if options.key?(:safe)
        config.parallel_agents = options[:parallel] if options.key?(:parallel)
        config.processor_count = options[:processors] if options[:processors]

        config.log_level = :debug if options[:verbose]
      end
    end

    def print_interactive_help
      puts <<~HELP
        Interactive Commands:

        start       - Start the simulation
        stop        - Stop the simulation
        pause       - Pause the simulation
        resume      - Resume the simulation
        step [n]    - Run n steps (default: 1)
        status      - Show current status
        report      - Show detailed report
        grid        - Show 2D grid visualization
        reset       - Reset the simulation
        help        - Show this help
        quit/exit   - Exit the program
      HELP
    end

    def print_benchmark_results(results)
      puts "\nBenchmark Results:"
      puts '=' * 50

      results.each do |result|
        puts "Run #{result[:run]}:"
        puts "  Runtime: #{format_time(result[:runtime])}"
        puts "  Extinctions: #{result[:extinctions]}"
        puts "  Total Ticks: #{result[:total_ticks]}"
        puts "  Ticks/sec: #{(result[:total_ticks] / result[:runtime]).round(2)}"
        puts
      end

      avg_runtime = results.sum { |r| r[:runtime] } / results.size
      avg_ticks = results.sum { |r| r[:total_ticks] } / results.size

      puts 'Averages:'
      puts "  Runtime: #{format_time(avg_runtime)}"
      puts "  Total Ticks: #{avg_ticks.round(2)}"
      puts "  Ticks/sec: #{(avg_ticks / avg_runtime).round(2)}"
    end

    def format_time(seconds)
      if seconds < 60
        "#{seconds.round(2)}s"
      else
        minutes = (seconds / 60).to_i
        secs = (seconds % 60).round(2)
        "#{minutes}m #{secs}s"
      end
    end
  end
end
