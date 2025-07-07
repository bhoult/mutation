# frozen_string_literal: true

require 'fileutils'
require 'time'

module Mutation
  class SimulationLogManager
    LOGS_DIR = 'logs'
    MAX_SIMULATIONS_TO_KEEP = 3
    
    attr_reader :current_simulation_dir
    
    def initialize
      @current_simulation_dir = nil
      cleanup_old_logs_on_startup
    end
    
    def start_new_simulation
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S_%L')
      @current_simulation_dir = File.join(LOGS_DIR, "simulation_#{timestamp}")
      FileUtils.mkdir_p(@current_simulation_dir)
      
      # Clean up old simulation folders
      cleanup_old_simulations
      
      @current_simulation_dir
    end
    
    def current_log_path(filename)
      return File.join(LOGS_DIR, filename) unless @current_simulation_dir
      
      # Handle agent log rotation
      if filename.start_with?('agent_')
        manage_agent_log_rotation
      end
      
      File.join(@current_simulation_dir, filename)
    end
    
    private
    
    def manage_agent_log_rotation
      return unless @current_simulation_dir
      
      # Find all agent log files in current simulation
      agent_logs = Dir.glob(File.join(@current_simulation_dir, 'agent_*.log'))
      
      # If we're at or over the limit, remove oldest logs
      max_logs = Mutation.configuration.max_agent_logs_per_simulation
      if agent_logs.size >= max_logs
        # Sort by modification time (oldest first)
        agent_logs.sort_by! { |file| File.mtime(file) }
        
        # Calculate how many to remove (keep room for one new log)
        logs_to_remove = agent_logs.size - max_logs + 1
        
        if logs_to_remove > 0
          agent_logs.first(logs_to_remove).each do |log_file|
            File.delete(log_file) if File.exist?(log_file)
          end
        end
      end
    rescue StandardError => e
      # Don't let log rotation errors break the simulation
      warn "Warning: Agent log rotation failed: #{e.message}"
    end
    
    def cleanup_old_logs_on_startup
      # Remove all logs when program starts
      if Dir.exist?(LOGS_DIR)
        Dir.glob(File.join(LOGS_DIR, '*')).each do |path|
          if File.directory?(path) && path.include?('simulation_')
            FileUtils.rm_rf(path)
          elsif File.file?(path)
            FileUtils.rm_f(path)
          end
        end
      end
      
      # Ensure logs directory exists
      FileUtils.mkdir_p(LOGS_DIR)
    end
    
    def cleanup_old_simulations
      simulation_dirs = Dir.glob(File.join(LOGS_DIR, 'simulation_*')).select { |f| File.directory?(f) }
      
      # Sort by creation time (newest first)
      simulation_dirs.sort_by! { |dir| File.mtime(dir) }.reverse!
      
      # Keep only the most recent MAX_SIMULATIONS_TO_KEEP
      if simulation_dirs.size > MAX_SIMULATIONS_TO_KEEP
        dirs_to_remove = simulation_dirs[MAX_SIMULATIONS_TO_KEEP..-1]
        dirs_to_remove.each do |dir|
          FileUtils.rm_rf(dir)
        end
      end
    end
  end
end