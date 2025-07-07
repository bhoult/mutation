# frozen_string_literal: true

require 'json'
require 'open3'
require 'timeout'
require 'fileutils'

module Mutation
  class Agent
    attr_reader :agent_id, :executable_path, :position, :energy, :generation, :pid, :age
    attr_accessor :alive, :memory
    
    @@firejail_warning_shown = false

    def initialize(agent_id, executable_path, x, y, energy = nil, generation = 1, memory = {})
      @agent_id = agent_id
      @executable_path = executable_path
      @position = [x, y]
      @energy = energy || Mutation.configuration.random_initial_energy
      @generation = generation
      @alive = true
      @age = 0  # Track agent age in cycles
      @pid = nil
      @stdin = nil
      @stdout = nil
      @stderr = nil
      @process_thread = nil
      @last_action = 'rest'
      @memory = memory
      
      spawn_process
    end

    def act(world_state)
      return default_action unless @alive && process_alive?
      
      begin
        start_time = Time.now
        
        # Send world state to agent
        input_data = build_input_data(world_state)
        json_data = JSON.generate(input_data)
        
        input_sent_time = Time.now
        
        # Log input to agent
        log_agent_interaction("INPUT", json_data)
        
        @stdin.puts(json_data)
        @stdin.flush
        
        # Wait for response with timeout
        response = nil
        timeout_seconds = Mutation.configuration.agent_response_timeout
        
        Timeout.timeout(timeout_seconds) do
          response_line = @stdout.gets
          response = JSON.parse(response_line) if response_line
          
          response_time = Time.now
          total_time_ms = ((response_time - start_time) * 1000).round(2)
          think_time_ms = ((response_time - input_sent_time) * 1000).round(2)
          
          # Log output from agent with timing
          log_agent_interaction("OUTPUT", "#{response_line} [TIMING: #{total_time_ms}ms total, #{think_time_ms}ms think]") if response_line
        end
        
        action = parse_action(response)
        @last_action = action[:type]
        action
        
      rescue Timeout::Error
        timeout_time = Time.now
        total_time_ms = ((timeout_time - start_time) * 1000).round(2)
        log_agent_interaction("TIMEOUT", "Agent timed out after #{total_time_ms}ms")
        Mutation.logger.warn("Agent #{@agent_id} timed out, using default action")
        default_action
      rescue JSON::ParserError => e
        error_time = Time.now
        total_time_ms = ((error_time - start_time) * 1000).round(2)
        log_agent_interaction("ERROR", "JSON parse error after #{total_time_ms}ms: #{e.message}")
        Mutation.logger.warn("Agent #{@agent_id} sent invalid JSON: #{e.message}")
        default_action
      rescue => e
        error_time = Time.now
        total_time_ms = ((error_time - start_time) * 1000).round(2)
        log_agent_interaction("ERROR", "Exception after #{total_time_ms}ms: #{e.message}")
        Mutation.logger.error("Agent #{@agent_id} error: #{e.message}")
        kill_process
        default_action
      end
    end

    def kill_process
      return unless @pid
      
      begin
        # Close stdin first to signal agent to exit
        @stdin&.close rescue nil
        
        # Give process a chance to exit gracefully
        sleep(Mutation.configuration.process_cleanup_delay)
        
        # Check if process is still alive
        if process_alive?
          # Try graceful termination first
          Mutation.logger.warn("⚠️  Agent #{@agent_id} process still alive, sending TERM signal")
          Process.kill('TERM', @pid)
          sleep(Mutation.configuration.process_cleanup_delay)
          
          # Force kill if still alive
          if process_alive?
            Mutation.logger.warn("💀 Agent #{@agent_id} process unresponsive, force killing with KILL signal")
            Process.kill('KILL', @pid)
            sleep(Mutation.configuration.process_cleanup_delay)
          else
            Mutation.logger.info("✅ Agent #{@agent_id} process terminated gracefully with TERM signal")
          end
        else
          Mutation.logger.info("✅ Agent #{@agent_id} process already exited")
        end
        
        cleanup_process
      rescue Errno::ESRCH
        # Process already dead
        Mutation.logger.info("✅ Agent #{@agent_id} process already dead (ESRCH)")
        cleanup_process
      rescue => e
        Mutation.logger.error("❌ Failed to kill agent process #{@pid}: #{e.message}")
        cleanup_process
      end
    end

    def die!
      @alive = false
      Mutation.logger.info("🏴 Agent #{@agent_id} died naturally (energy: #{@energy}, age: #{@age})")
      # Defer graceful death to avoid blocking simulation
      # The agent cleanup will be handled by the cleanup queue
    end

    # Age the agent by one cycle and check for maximum lifespan
    def age_one_cycle!
      @age += 1
      
      # Check if agent has exceeded maximum lifespan
      max_lifespan = Mutation.configuration.max_agent_lifespan
      if @age >= max_lifespan
        Mutation.logger.info("⏳ Agent #{@agent_id} died of old age (age: #{@age})")
        die!
        return true  # Indicate agent died of old age
      end
      
      false  # Agent still alive
    end

    # Check if agent has exceeded maximum lifespan
    def exceeds_max_lifespan?
      max_lifespan = Mutation.configuration.max_agent_lifespan
      @age >= max_lifespan
    end

    def request_graceful_death
      return unless process_alive?
      
      begin
        # Send death instruction to agent
        death_instruction = JSON.generate({
          command: 'die',
          message: 'Agent termination requested'
        })
        
        @stdin.puts(death_instruction)
        @stdin.flush
        
        # Schedule cleanup in background thread to avoid blocking simulation
        Thread.new do
          begin
            Mutation.logger.info("💌 Sent graceful death message to agent #{@agent_id}")
            # Give the agent time to exit gracefully
            sleep(Mutation.configuration.graceful_death_timeout)
            
            # If still alive, fall back to manual killing
            if process_alive?
              Mutation.logger.warn("⏰ Agent #{@agent_id} did not exit gracefully after #{Mutation.configuration.graceful_death_timeout}s, forcing termination")
              kill_process
            else
              Mutation.logger.info("😇 Agent #{@agent_id} exited gracefully after die message")
              cleanup_process
            end
          rescue => e
            Mutation.logger.warn("Failed to cleanup agent #{@agent_id}: #{e.message}")
            kill_process
          end
        end
        
      rescue => e
        Mutation.logger.warn("Failed to request graceful death for agent #{@agent_id}: #{e.message}")
        # Even if we can't send the die message, schedule cleanup
        Thread.new { kill_process }
      end
    end

    def alive?
      @alive
    end

    def dead?
      !@alive
    end

    def fitness
      # Simple fitness calculation based on survival time and energy
      (@energy * Mutation.configuration.fitness_energy_multiplier) + (@generation * Mutation.configuration.fitness_generation_multiplier)
    end

    def id
      @agent_id
    end

    def mutations_count
      # AgentProcess doesn't track mutations in the same way as regular agents
      0
    end

    def code_str
      # For process-based agents, the code is the executable path
      "Process Agent: #{@executable_path}"
    end

    private

    

    def spawn_process
      # Skip firejail for now - go straight to direct execution
      begin
        @stdin, @stdout, @stderr, @process_thread = Open3.popen3(@executable_path)
        @pid = @process_thread.pid
        
        # Give the process a moment to start
        sleep(0.01)
        
        unless process_alive?
          # Try to get error output
          error_output = ""
          begin
            @stderr.each_line do |line|
              error_output += line
              break if error_output.length > 500 # Limit error output
            end
          rescue
            # Ignore stderr read errors
          end
          
          Mutation.logger.error("Agent #{@agent_id} process died immediately after spawn. Error: #{error_output}")
          @alive = false
        end
      rescue => e
        Mutation.logger.error("Failed to spawn agent #{@agent_id}: #{e.message}")
        @alive = false
        @pid = nil
      end
    end

    def process_alive?
      return false unless @pid
      
      begin
        Process.getpgid(@pid)
        true
      rescue Errno::ESRCH
        false
      end
    end

    def cleanup_process
      [@stdin, @stdout, @stderr].each do |io|
        io&.close rescue nil
      end
      
      @process_thread&.join(0.1) rescue nil
      @pid = nil
    end

    def build_input_data(world_state)
      # World is now the authoritative source of all agent state
      {
        tick: world_state[:tick],
        agent_id: world_state[:agent_id],
        position: world_state[:position],
        energy: world_state[:energy],  # World-controlled energy, not agent's
        world_size: world_state[:world_size],
        vision: world_state[:vision] || {},  # Pass vision data to agent
        generation: world_state[:generation],
        timeout_ms: world_state[:timeout_ms] || Mutation.configuration.default_timeout_ms,
        memory: @memory # Pass agent's memory to the process
      }
    end


    def parse_action(response)
      return default_action unless response.is_a?(Hash)
      
      action_type = response['action']&.to_sym
      @memory = response['memory'] || {}
      
      case action_type
      when :attack
        target = response['target']
        return default_action unless valid_direction?(target)
        { type: :attack, target: target.to_sym }
      when :rest
        { type: :rest }
      when :replicate
        { type: :replicate }
      when :move
        target = response['target']
        return default_action unless valid_direction?(target)
        { type: :move, target: target.to_sym }
      when :die
        { type: :die }
      else
        default_action
      end
    end

    def valid_direction?(direction)
      %w[north south east west north_east north_west south_east south_west].include?(direction)
    end

    def default_action
      { type: :rest }
    end

    def log_agent_interaction(direction, data)
      # Get the current simulation log path from log manager
      log_file = Mutation.log_manager.current_log_path("agent_#{@agent_id}.log")
      
      # Ensure directory exists
      FileUtils.mkdir_p(File.dirname(log_file))
      
      timestamp = Time.now.strftime("%H:%M:%S.%3N")
      File.open(log_file, 'a') do |f|
        f.puts "[#{timestamp}] #{direction}: #{data}"
      end
    rescue => e
      # Don't let logging errors break the simulation
      Mutation.logger.debug("Failed to log agent interaction: #{e.message}")
    end
  end
end