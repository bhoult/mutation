# frozen_string_literal: true

require 'fileutils'

module Mutation
  class Simulator
    attr_reader :world, :running, :statistics

    def initialize(world_size: nil, width: nil, height: nil, seed_code: nil, curses_mode: false, agent_executables: nil)
      # Auto-size world to screen if curses mode and no size specified
      if curses_mode && !world_size && !width && !height
        begin
          require 'curses'
          Curses.init_screen
          
          # Replicate the exact CursesDisplay calculations
          total_lines = Curses.lines
          total_cols = Curses.cols
          
          # Step 1: Calculate @screen_height and @screen_width (from CursesDisplay initialization)
          screen_height = total_lines - CursesDisplay::TOTAL_BOTTOM_LINES - CursesDisplay::BORDER_SIZE
          screen_width = total_cols - CursesDisplay::BORDER_SIZE # Only left border now
          
          # Step 2: Calculate viewport dimensions (from update_viewport method)
          # @viewport_width = [@screen_width - BORDER_SIZE, world_width].min
          # @viewport_height = [@screen_height - BORDER_SIZE, world_width].min
          # We want world size to exactly match the max viewport, so:
          max_viewport_width = screen_width - CursesDisplay::BORDER_SIZE # Only left border
          max_viewport_height = screen_height - CursesDisplay::BORDER_SIZE
          
          Curses.close_screen

          width = [max_viewport_width, 5].max  # Ensure minimum size
          height = [max_viewport_height, 5].max # Ensure minimum size
        rescue StandardError
          # Fallback to default size if curses initialization fails
          width = 80
          height = 24
        end
      end

      @world = World.new(size: world_size, width: width, height: height, seed_code: seed_code, agent_executables: agent_executables)
      @curses_mode = curses_mode
      @curses_display = nil
      @survivor_logger = nil  # Will be initialized when simulation starts
      @running = false
      @quit_requested = false
      @statistics = {
        start_time: nil,
        total_runtime: 0,
        total_ticks: 0,
        extinctions: 0
      }
    end

    def start
      @running = true
      @statistics[:start_time] = Time.now
      
      # Start a new simulation log folder
      Mutation.log_manager.start_new_simulation
      
      # Initialize survivor logger with simulation-specific path
      survivor_log_path = Mutation.log_manager.current_log_path('survivors.log')
      @survivor_logger = SurvivorLogger.new(log_file: survivor_log_path)

      if @curses_mode
        # Mutation.logger.suppress_output = true # Temporarily disable for debugging
        # Force disable parallel processing in curses mode
        Mutation.configuration.parallel_agents = false
        start_curses_mode
      else
        Mutation.logger.info('🚀 Starting mutation simulation')
        Mutation.logger.info("Configuration: #{Mutation.configuration.to_hash}")
        run_simulation_loop
      end
    end

    def stop
      @running = false
      @quit_requested = true
      @statistics[:total_runtime] = Time.now - @statistics[:start_time]

      # Stop curses display if active
      @curses_display&.stop

      # Clean up any running processes
      @world.cleanup

      Mutation.logger.info('⏹️  Simulation stopped')

      # Log survivors when simulation ends
      log_final_survivors

      print_final_statistics unless @curses_mode
    end

    def pause
      @running = false
      Mutation.logger.info('⏸️  Simulation paused')
    end

    def resume
      @running = true
      Mutation.logger.info('▶️  Simulation resumed')
      run_simulation_loop
    end

    def request_quit
      @quit_requested = true
      @running = false
    end

    def step
      return unless @running  # Don't step if stopped
      return if @quit_requested  # Don't step if quit was requested
      
      @world.step
      @statistics[:total_ticks] += 1

      # Only handle extinction if we're still running and quit wasn't requested
      handle_extinction if @running && !@quit_requested && @world.all_dead?

      log_status if should_log_status?
    end

    def run_for_ticks(ticks)
      Mutation.logger.info("Running simulation for #{ticks} ticks")

      ticks.times do |i|
        Mutation.logger.info("Simulator.run_for_ticks: Starting tick #{i+1}/#{ticks}")
        step
        Mutation.logger.info("Simulator.run_for_ticks: Step #{i+1} completed")
        
        if @world.all_dead? && !Mutation.configuration.auto_reset
          Mutation.logger.info("Simulator.run_for_ticks: Breaking due to all dead and no auto-reset")
          break
        end

        if Mutation.configuration.simulation_delay.positive?
          Mutation.logger.info("Simulator.run_for_ticks: Sleeping for #{Mutation.configuration.simulation_delay}s")
          sleep(Mutation.configuration.simulation_delay)
        end
      end
      
      Mutation.logger.info("Simulator.run_for_ticks: Completed all #{ticks} ticks")
    end

    def run_until_extinction
      Mutation.logger.info('Running simulation until extinction')

      until @world.all_dead?
        step
        sleep(Mutation.configuration.simulation_delay) if Mutation.configuration.simulation_delay.positive?
      end

      handle_extinction
    end

    

    def reset
      @world.reset_grid
      @world.reset_tick
      @statistics[:extinctions] = 0
      @quit_requested = false

      Mutation.logger.info('🔄 Simulation reset')
    end

    def current_status
      {
        tick: @world.tick,
        generation: @world.generation,
        agents_alive: @world.agent_count,
        average_energy: @world.average_energy,
        max_fitness: @world.fittest_agent&.fitness || 0,
        extinctions: @statistics[:extinctions],
        total_ticks: @statistics[:total_ticks]
      }
    end

    def detailed_report
      status = current_status
      world_stats = @world.statistics

      report = []
      report << '=' * 50
      report << 'MUTATION SIMULATION REPORT'
      report << '=' * 50
      report << ''
      report << 'Current Status:'
      report << "  Tick: #{status[:tick]}"
      report << "  Generation: #{status[:generation]}"
      report << "  Agents Alive: #{status[:agents_alive]}"
      report << "  Average Energy: #{status[:average_energy].round(2)}"
      report << "  Max Fitness: #{status[:max_fitness]}"
      report << ''
      report << 'World Statistics:'
      report << "  Total Agents Created: #{world_stats[:total_agents_created]}"
      report << "  Total Generations: #{world_stats[:total_generations]}"
      report << "  Max Fitness Achieved: #{world_stats[:max_fitness_achieved]}"
      report << "  Longest Survival: #{world_stats[:longest_survival_ticks]} ticks"
      report << ''
      report << 'Simulation Statistics:'
      report << "  Total Extinctions: #{@statistics[:extinctions]}"
      report << "  Total Ticks: #{@statistics[:total_ticks]}"
      report << "  Runtime: #{format_runtime(@statistics[:total_runtime])}"
      report << ''
      report << 'Fittest Agent:'

      if @world.fittest_agent
        agent = @world.fittest_agent
        report << "  ID: #{agent.id}"
        report << "  Energy: #{agent.energy}"
        report << "  Generation: #{agent.generation}"
        report << "  Fitness: #{agent.fitness}"
        report << "  Mutations: #{agent.mutations_count}"
      else
        report << '  None'
      end

      report.join("\n")
    end

    private

    def save_single_survivor(agent)
      # Only save if the agent has mutation metadata
      return unless agent.memory && agent.memory['is_mutation']
      
      # Gather simulation statistics for the metadata
      simulation_stats = {
        survival_ticks: @world.tick,
        generation: @world.generation,
        world_size: "#{@world.width}x#{@world.height}",
        total_agents: @statistics[:total_agents_created],
        simulation_delay: Mutation.configuration.simulation_delay,
        final_agent_count: 1,
        created_at: Time.now.strftime('%Y-%m-%d %H:%M:%S')
      }
      
      # Reconstruct agent data from memory
      agent_data = {
        code: get_agent_code(agent),
        is_mutation: agent.memory['is_mutation'],
        original_agent: agent.memory['original_agent']
      }
      
      # Save the survivor using the mutated agent manager
      saved_path = @world.instance_variable_get(:@mutated_agent_manager)&.save_survivor(agent_data, simulation_stats)
      
      if saved_path
        Mutation.logger.info("🏆 Saved last surviving mutated agent: #{File.basename(saved_path)}")
      end
    rescue StandardError => e
      Mutation.logger.warn("Failed to save surviving mutated agent: #{e.message}")
    end

    def get_agent_code(agent)
      # Get the stored agent code from memory
      if agent.memory && agent.memory['agent_code']
        return agent.memory['agent_code']
      end
      
      # Fallback if code not found in memory
      return "# Agent code could not be retrieved\n# Agent ID: #{agent.agent_id}\n# This was a surviving mutated agent"
    end

    def run_simulation_loop
      while @running
        step

        break if should_exit?

        sleep(Mutation.configuration.simulation_delay) if Mutation.configuration.simulation_delay.positive?
      end
    rescue Interrupt
      Mutation.logger.info('Simulation interrupted by user')
      stop
    ensure
      # Always cleanup processes on exit
      @world.cleanup
    end

    def handle_extinction
      @statistics[:extinctions] += 1

      # Check for single surviving mutated agent to save
      survivors = @world.living_agents
      if survivors.size == 1
        save_single_survivor(survivors.first)
      end

      # Log survivors before extinction
      @survivor_logger&.log_survivors(survivors)

      @world.prepare_for_reset

      Mutation.logger.generation("💀 Extinction ##{@statistics[:extinctions]} - Generation #{@world.generation}")

      # Don't auto-reset if simulator has been stopped or quit was requested
      if @running && !@quit_requested && Mutation.configuration.auto_reset
        @world.reset_grid
        @world.reset_tick
        
        # Start a new simulation log folder for the new generation
        Mutation.log_manager.start_new_simulation
        
        # Re-initialize survivor logger with new simulation-specific path
        survivor_log_path = Mutation.log_manager.current_log_path('survivors.log')
        @survivor_logger = SurvivorLogger.new(log_file: survivor_log_path)
        
        # Re-initialize world logging to use new folder
        @world.reinitialize_logging if @world.respond_to?(:reinitialize_logging)
        
        Mutation.logger.generation('🔄 Auto-reset enabled, starting new generation')
      else
        Mutation.logger.info('Auto-reset disabled, stopping simulation')
        # Don't stop the simulator in curses mode - let curses display control it
        @running = false unless @curses_mode
      end
    end

    

    def should_log_status?
      (@world.tick % 10).zero? || @world.tick < 5
    end

    def should_exit?
      max_ticks = Mutation.configuration.max_ticks
      return false unless max_ticks

      @statistics[:total_ticks] >= max_ticks
    end

    def log_status
      status = @world.status_line
      detail = @world.detailed_status

      Mutation.logger.simulation(status)
      Mutation.logger.debug(detail)
    end

    def format_runtime(seconds)
      return '0s' unless seconds

      hours = (seconds / 3600).to_i
      minutes = ((seconds % 3600) / 60).to_i
      secs = (seconds % 60).to_i

      if hours.positive?
        "#{hours}h #{minutes}m #{secs}s"
      elsif minutes.positive?
        "#{minutes}m #{secs}s"
      else
        "#{secs}s"
      end
    end

    def print_final_statistics
      puts detailed_report
    end

    def start_curses_mode
      # Suppress console output during curses mode to prevent display interference
      Mutation.logger.suppress_output = true
      
      # Redirect stdout and stderr to log file instead of /dev/null to capture debug info
      original_stdout = $stdout
      original_stderr = $stderr
      debug_log_path = Mutation.log_manager.current_log_path('curses_debug.log')
      
      begin
        # Ensure log directory exists
        FileUtils.mkdir_p(File.dirname(debug_log_path))
        
        # Redirect output to debug log file
        debug_log = File.open(debug_log_path, 'a')
        debug_log.puts "\n=== CURSES SESSION STARTED: #{Time.now} ==="
        debug_log.flush
        
        $stdout = debug_log
        $stderr = debug_log
        
        @curses_display = CursesDisplay.new(@world, self)

        # Start the display (blocks until user quits)
        # Display will handle simulation stepping internally
        @curses_display.start

        # Clean up
        @running = false
        
        # Log session end
        debug_log.puts "=== CURSES SESSION ENDED: #{Time.now} ==="
        debug_log.flush
      ensure
        # Restore original streams
        $stdout.close if $stdout != original_stdout && !$stdout.closed?
        $stderr.close if $stderr != original_stderr && !$stderr.closed?
        $stdout = original_stdout
        $stderr = original_stderr
        
        # Re-enable logging for final results display
        Mutation.logger.suppress_output = false
      end
      
      show_final_results
    end

    def curses_simulation_loop
      last_step_time = Time.now

      while @running && @curses_display&.running
        current_time = Time.now

        # Only step if display is not paused and enough time has passed
        unless @curses_display.send(:paused?)
          time_since_last_step = current_time - last_step_time
          simulation_delay = Mutation.configuration.simulation_delay

          if time_since_last_step >= simulation_delay
            step
            last_step_time = current_time

            break if should_exit?
          end
        end

        # Short sleep to prevent busy waiting and allow input processing
        sleep(0.01)
      end
    end

    def log_final_survivors
      survivors = @world.living_agents
      return unless survivors.any?

      count = @survivor_logger&.log_survivors(survivors) || 0
      return unless count.positive?

      Mutation.logger.info("Final simulation: logged #{count} new survivor codes")
    end

    def show_final_results
      # Only show results if logging is not suppressed (i.e., not in curses mode)
      return if Mutation.logger.suppress_output?

      puts "\n#{'=' * 60}"
      puts 'SIMULATION COMPLETED'
      puts '=' * 60

      # Show final statistics
      puts detailed_report

      # Show final survivor codes if any
      survivors = @world.living_agents.select(&:alive?).sort_by(&:fitness).reverse.first(3)

      if survivors.any?
        puts "\n#{'=' * 60}"
        puts 'FINAL SURVIVOR CODES'
        puts '=' * 60

        survivors.each_with_index do |agent, index|
          puts "\n--- Survivor #{index + 1} (Fitness: #{agent.fitness}, Generation: #{agent.generation}) ---"
          puts agent.code_str
        end
      else
        puts "\nNo survivors found."
      end

      puts "\n#{'=' * 60}"
    end
  end
end
