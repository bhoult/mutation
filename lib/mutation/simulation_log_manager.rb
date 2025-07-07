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
      File.join(@current_simulation_dir, filename)
    end
    
    private
    
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