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
      threads.each { |t| t.join(timeout_ms / 1000.0 + 0.1) }
      
      actions
    end

    def get_agent_actions_with_individual_states(agent_world_states)
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
      
      actions
    end

    def remove_agent(agent_id)
      Mutation.logger.debug("Attempting to remove agent #{agent_id}")
      agent = @agents.delete(agent_id)
      if agent
        # Only try to kill if process is still alive
        if agent.send(:process_alive?)
          agent.kill_process
        else
          # Process already exited, just clean up
          agent.send(:cleanup_process)
        end
        cleanup_agent_files(agent_id)
        Mutation.logger.debug("Successfully removed agent #{agent_id}. Remaining agents: #{@agents.size}")
      else
        Mutation.logger.warn("Agent #{agent_id} not found for removal.")
      end
    end

    def kill_all_agents
      if @agents.empty?
        Mutation.logger.info("AgentManager: No active agents to kill. No workspace cleanup needed.")
      else
        Mutation.logger.info("AgentManager: Performing final sweep, killing #{@agents.size} remaining agents...")
        @agents.each do |agent_id, agent|
          begin
            agent.kill_process
          rescue => e
            Mutation.logger.error("Failed to kill agent #{agent_id}: #{e.message}")
          end
        end
      end
      @agents.clear
      Mutation.logger.info("AgentManager: Final sweep complete.")
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
      
      # Create mutated script for offspring
      if mutation_engine.is_a?(MutationEngine)
        # Use process-based mutation
        offspring_script_path = mutation_engine.create_mutated_agent_script(parent_agent)
        
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