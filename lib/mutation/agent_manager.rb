# frozen_string_literal: true

require 'fileutils'
require_relative 'mutation_engine'

module Mutation
  class AgentManager
    attr_reader :agents

    def initialize
      @agents = {}
      @agent_counter = 0
    end

    def spawn_agent(executable_path, x, y, energy = nil, generation = 1, memory = {})
      # Safety check to prevent too many agents
      return nil if @agents.size >= Mutation.configuration.max_agent_count
      
      agent_id = generate_agent_id
      
      begin
        agent = Agent.new(agent_id, executable_path, x, y, energy, generation, memory)
        if agent.alive?
          @agents[agent_id] = agent
          agent
        else
          nil
        end
      rescue => e
        Mutation.logger.error("Failed to spawn agent: #{e.message}")
        nil
      end
    end

    def get_agent_actions(world_state)
      timeout_ms = world_state[:timeout_ms] || 1000
      actions = {}
      
      # Process all agents in parallel
      threads = @agents.map do |agent_id, agent|
        Thread.new do
          begin
            if agent.alive
              action = agent.act(world_state.merge(agent_id: agent_id))
              actions[agent_id] = action
            end
          rescue => e
            Mutation.logger.error("Error getting action from agent #{agent_id}: #{e.message}")
            actions[agent_id] = { type: :rest }
          end
        end
      end
      
      # Wait for all threads with global timeout
      threads.each { |t| t.join(timeout_ms / 1000.0 + 0.5) }
      
      actions
    end

    def get_agent_actions_with_individual_states(agent_world_states)
      method_start = Time.now
      actions = {}
      
      # Use parallel processing for better performance with many agents
      if @agents.size > Mutation.configuration.parallel_processing_threshold && Mutation.configuration.parallel_agents
        require 'parallel'
        
        # Process agents in parallel using threads
        agent_pairs = @agents.select { |agent_id, agent| agent.alive && agent_world_states[agent_id] }
        
        results = Parallel.map(agent_pairs, in_threads: [agent_pairs.size, Mutation.configuration.max_parallel_threads].min) do |agent_id, agent|
          begin
            action = agent.act(agent_world_states[agent_id].merge(agent_id: agent_id))
            [agent_id, action]
          rescue => e
            Mutation.logger.error("Error getting action from agent #{agent_id}: #{e.message}")
            [agent_id, { type: :rest }]
          end
        end
        
        # Convert results back to hash
        results.each { |agent_id, action| actions[agent_id] = action }
      else
        # Process all agents sequentially for small populations
        @agents.each do |agent_id, agent|
          begin
            if agent.alive && agent_world_states[agent_id]
              action = agent.act(agent_world_states[agent_id].merge(agent_id: agent_id))
              actions[agent_id] = action
            end
          rescue => e
            Mutation.logger.error("Error getting action from agent #{agent_id}: #{e.message}")
            actions[agent_id] = { type: :rest }
          end
        end
      end
      
      method_time = Time.now - method_start
      if @agents.size > 0 && method_time > 0.01 # Log if > 10ms
        Mutation.logger.debug("PROFILE AgentActions: #{(@agents.size)} agents, #{(method_time * 1000).round(2)}ms")
      end
      
      actions
    end

    def remove_agent(agent_id)
      agent = @agents.delete(agent_id)
      if agent
        # Mark agent as dead but defer expensive cleanup operations
        agent.die!
        
        # Add to cleanup queue for batch processing
        @cleanup_queue ||= []
        @cleanup_queue << agent
        
        # Minimal logging to avoid performance impact
        Mutation.logger.debug("Marked agent #{agent_id} for cleanup. Remaining: #{@agents.size}") if @agents.size % 10 == 0
      end
    end
    
    def process_cleanup_queue
      return unless @cleanup_queue&.any?
      
      # Separate alive and dead processes to avoid unnecessary work
      alive_agents = @cleanup_queue.select { |agent| agent.send(:process_alive?) }
      dead_agents = @cleanup_queue.reject { |agent| agent.send(:process_alive?) }
      
      if alive_agents.any?
        Mutation.logger.debug("Cleanup queue: #{alive_agents.size} alive processes need killing, #{dead_agents.size} already dead")
      else
        Mutation.logger.debug("Cleanup queue: All #{@cleanup_queue.size} processes already exited")
      end
      
      # Process cleanup asynchronously to avoid blocking the simulation
      cleanup_thread = Thread.new do
        @cleanup_queue.each do |agent|
          begin
            # Only try to kill if process is still alive
            if agent.send(:process_alive?)
              agent.kill_process
            else
              # Process already exited, just clean up
              agent.send(:cleanup_process)
            end
            cleanup_agent_files(agent.agent_id)
          rescue => e
            Mutation.logger.error("Failed to cleanup agent #{agent.agent_id}: #{e.message}")
          end
        end
        
        Mutation.logger.debug("Processed cleanup queue: #{@cleanup_queue.size} agents")
      end
      
      # Don't wait for cleanup to complete - let it run in background
      cleanup_thread.join(0.001) # Very short timeout to avoid blocking
      @cleanup_queue.clear
    end

    def kill_all_agents
      method_start = Time.now
      
      if @agents.empty?
        Mutation.logger.debug("AgentManager: No active agents to kill. No workspace cleanup needed.")
      else
        # Check which agents actually need killing
        check_start = Time.now
        agents_to_kill = @agents.select do |agent_id, agent|
          agent.send(:process_alive?)
        end
        check_time = Time.now - check_start
        Mutation.logger.debug("Process alive check took #{(check_time * 1000).round(2)}ms for #{@agents.size} agents")
        
        if agents_to_kill.empty?
          Mutation.logger.debug("AgentManager: All #{@agents.size} agent processes already exited. No kills needed.")
        else
          Mutation.logger.debug("AgentManager: Performing final sweep, killing #{agents_to_kill.size} of #{@agents.size} remaining agents...")
          kill_start = Time.now
          
          # Kill agents in parallel to avoid blocking
          threads = agents_to_kill.map do |agent_id, agent|
            Thread.new do
              begin
                agent_kill_start = Time.now
                agent.kill_process
                agent_kill_time = Time.now - agent_kill_start
                Mutation.logger.debug("Killed agent #{agent_id} in #{(agent_kill_time * 1000).round(2)}ms")
              rescue => e
                Mutation.logger.error("Failed to kill agent #{agent_id}: #{e.message}")
              end
            end
          end
          
          # Wait for all kills to complete with a reasonable timeout
          threads.each { |t| t.join(1.0) } # 1 second timeout per thread
          
          kill_time = Time.now - kill_start
          Mutation.logger.debug("All agent kills completed in #{(kill_time * 1000).round(2)}ms")
        end
      end
      @agents.clear
      
      method_time = Time.now - method_start
      Mutation.logger.debug("kill_all_agents total time: #{(method_time * 1000).round(2)}ms")
    end

    def living_agents
      @agents.values.select(&:alive)
    end

    def agent_count
      living_agents.count
    end

    def get_agent_at(x, y)
      @agents.values.find { |agent| agent.position == [x, y] && agent.alive }
    end

    def move_agent(agent_id, new_x, new_y)
      agent = @agents[agent_id]
      return false unless agent&.alive
      
      agent.position[0] = new_x
      agent.position[1] = new_y
      true
    end

    def update_agent_energy(agent_id, new_energy)
      agent = @agents[agent_id]
      return false unless agent
      
      agent.instance_variable_set(:@energy, new_energy)
      
      if new_energy <= 0
        agent.die!
        false
      else
        true
      end
    end

    def create_offspring(parent_agent, x, y, mutation_engine, parent_memory = {})
      return nil unless parent_agent&.alive
      
      offspring_energy = Mutation.configuration.random_initial_energy
      offspring_generation = parent_agent.generation + 1
      
      # Use existing agent from genetic pool to avoid blocking file I/O during simulation
      if mutation_engine.is_a?(MutationEngine)
        # Get random existing agent from pool (fast, no file creation)
        offspring_script_path = mutation_engine.random_agent_from_pool
        
        # Fallback to parent if no agents in pool
        offspring_script_path ||= parent_agent.executable_path
        
        spawn_agent(
          offspring_script_path,
          x, y,
          offspring_energy,
          offspring_generation,
          parent_memory
        )
      else
        # Fallback to using parent's executable (no mutation)
        spawn_agent(
          parent_agent.executable_path,
          x, y,
          offspring_energy,
          offspring_generation,
          parent_memory
        )
      end
    end

    def statistics
      agents = living_agents
      return {} if agents.empty?
      
      {
        total_agents: agents.count,
        average_energy: agents.sum(&:energy) / agents.count.to_f,
        max_energy: agents.map(&:energy).max,
        min_energy: agents.map(&:energy).min,
        average_generation: agents.sum(&:generation) / agents.count.to_f,
        max_generation: agents.map(&:generation).max
      }
    end

    private

    def generate_agent_id
      @agent_counter += 1
      "agent_#{@agent_counter}_#{Time.now.to_i}"
    end

    def cleanup_agent_files(agent_id)
      # Clean up agent memory files
      agent_dir = File.join(Mutation.configuration.agent_memory_base_path, agent_id)
      if Dir.exist?(agent_dir)
        begin
          FileUtils.rm_rf(agent_dir)
          Mutation.logger.debug("Cleaned up agent directory: #{agent_dir}")
        rescue => e
          Mutation.logger.warn("Failed to clean up agent directory #{agent_dir}: #{e.message}")
        end
      end
    end
  end
end