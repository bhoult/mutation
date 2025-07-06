# frozen_string_literal: true

require 'json'
require 'open3'
require 'timeout'
require 'fileutils'

module Mutation
  class Agent
    attr_reader :agent_id, :executable_path, :position, :energy, :generation, :pid
    attr_accessor :alive, :memory
    
    @@firejail_warning_shown = false

    def initialize(agent_id, executable_path, x, y, energy = nil, generation = 1, memory = {})
      @agent_id = agent_id
      @executable_path = executable_path
      @position = [x, y]
      @energy = energy || Mutation.configuration.random_initial_energy
      @generation = generation
      @alive = true
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
        # Send world state to agent
        input_data = build_input_data(world_state)
        json_data = JSON.generate(input_data)
        
        @stdin.puts(json_data)
        @stdin.flush
        
        # Wait for response with timeout
        response = nil
        timeout_seconds = Mutation.configuration.agent_response_timeout
        
        Timeout.timeout(timeout_seconds) do
          response_line = @stdout.gets
          response = JSON.parse(response_line) if response_line
        end
        
        action = parse_action(response)
        @last_action = action[:type]
        action
        
      rescue Timeout::Error
        Mutation.logger.warn("Agent #{@agent_id} timed out, using default action")
        default_action
      rescue JSON::ParserError => e
        Mutation.logger.warn("Agent #{@agent_id} sent invalid JSON: #{e.message}")
        default_action
      rescue => e
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
          Process.kill('TERM', @pid)
          sleep(Mutation.configuration.process_cleanup_delay)
          
          # Force kill if still alive
          if process_alive?
            Process.kill('KILL', @pid)
            sleep(Mutation.configuration.process_cleanup_delay)
          end
        end
        
        cleanup_process
      rescue Errno::ESRCH
        # Process already dead
        cleanup_process
      rescue => e
        Mutation.logger.error("Failed to kill agent process #{@pid}: #{e.message}")
        cleanup_process
      end
    end

    def die!
      @alive = false
      request_graceful_death
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
        
        # Give the agent time to exit gracefully
        sleep(Mutation.configuration.graceful_death_timeout)
        
        # If still alive, fall back to manual killing
        if process_alive?
          Mutation.logger.debug("Agent #{@agent_id} did not exit gracefully, forcing termination")
          kill_process
        else
          Mutation.logger.debug("Agent #{@agent_id} exited gracefully")
          cleanup_process
        end
        
      rescue => e
        Mutation.logger.warn("Failed to request graceful death for agent #{@agent_id}: #{e.message}")
        kill_process
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
        
        unless process_alive?
          Mutation.logger.error("Agent #{@agent_id} process died immediately after spawn")
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
        neighbors: format_neighbors(world_state[:neighbors]),
        generation: world_state[:generation],
        timeout_ms: world_state[:timeout_ms] || Mutation.configuration.default_timeout_ms,
        memory: @memory # Pass agent's memory to the process
      }
    end

    def format_neighbors(neighbors)
      directions = ['north_west', 'north', 'north_east', 'west', 'east', 'south_west', 'south', 'south_east']
      
      result = {}
      
      if neighbors.is_a?(Hash)
        # neighbors is already a hash, just format it
        neighbors.each do |direction, neighbor|
          if neighbor && neighbor.respond_to?(:energy)
            result[direction] = {
              energy: neighbor.energy,
              agent_id: neighbor.agent_id
            }
          else
            result[direction] = {
              energy: 0,
              agent_id: nil
            }
          end
        end
      else
        # neighbors is an array
        neighbors.each_with_index do |neighbor, index|
          direction = directions[index]
          if neighbor && neighbor.respond_to?(:energy)
            result[direction] = {
              energy: neighbor.energy,
              agent_id: neighbor.agent_id
            }
          else
            result[direction] = {
              energy: 0,
              agent_id: nil
            }
          end
        end
      end
      
      result
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
  end
end