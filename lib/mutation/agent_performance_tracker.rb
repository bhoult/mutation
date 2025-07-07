# frozen_string_literal: true

require 'json'
require 'fileutils'
require 'set'

module Mutation
  class AgentPerformanceTracker
    STATS_FILE = 'agent_performance_stats.log'

    def initialize(log_dir: nil)
      @log_dir = log_dir || File.join(Dir.pwd, 'logs')
      @stats_file_path = File.join(@log_dir, STATS_FILE)
      @stats = load_existing_stats
    end

    # Extract agent type from agent object or path
    def extract_agent_type(agent_or_path)
      if agent_or_path.respond_to?(:executable_path)
        # It's an agent object
        path = agent_or_path.executable_path
      else
        # It's already a path
        path = agent_or_path.to_s
      end
      
      # Extract base name from path
      basename = File.basename(path, '.rb')
      
      # Remove mutation suffixes and timestamps
      # Examples:
      # active_explorer_agent_18e6ed0b_survival_150_gen_4_20250707_124051 -> active_explorer_agent
      # aggressive_hunter_mutation_gen14_20250707_131713_321396629 -> aggressive_hunter
      
      # First, handle mutation variants with fingerprints
      if basename =~ /^(.+?)_[a-f0-9]{8}_survival_/
        return $1
      end
      
      # Handle temp mutation files
      if basename =~ /^(.+?)_mutation_gen\d+_/
        return $1
      end
      
      # Handle timestamped mutation files
      if basename =~ /^(.+?)_\d{8}_\d{6}/
        return $1
      end
      
      # Return as-is for regular agent files
      basename
    end
    
    # Record a simulation with its participants and winner
    def record_simulation(participating_agents, winning_agent = nil)
      # Extract unique agent types from participating agents
      agent_types = Set.new
      participating_agents.each do |agent|
        agent_type = extract_agent_type(agent)
        agent_types.add(agent_type)
      end
      
      # Update participation counts for all unique agent types
      agent_types.each do |agent_type|
        @stats[agent_type] ||= { participations: 0, wins: 0 }
        @stats[agent_type][:participations] += 1
      end

      # Update win count if there was a winner
      if winning_agent
        winning_type = extract_agent_type(winning_agent)
        @stats[winning_type] ||= { participations: 0, wins: 0 }
        @stats[winning_type][:wins] += 1
      end

      save_stats
    end

    # Get sorted statistics
    def sorted_stats
      @stats.map do |agent_type, data|
        win_percentage = if data[:participations] > 0
                          (data[:wins].to_f / data[:participations] * 100).round(2)
                        else
                          0.0
                        end
        
        {
          agent_type: agent_type,
          participations: data[:participations],
          wins: data[:wins],
          win_percentage: win_percentage
        }
      end.sort_by { |stat| -stat[:win_percentage] }
    end

    private

    def load_existing_stats
      return {} unless File.exist?(@stats_file_path)

      # Parse the existing stats file
      stats = {}
      current_section = nil
      
      File.readlines(@stats_file_path).each do |line|
        line = line.strip
        
        # Skip empty lines and headers
        next if line.empty? || line.start_with?('=') || line.start_with?('AGENT PERFORMANCE')
        
        # Parse agent entries
        if line.match(/^(\d+)\.\s+(.+?)\s*:/)
          agent_match = line.match(/^(\d+)\.\s+(.+?)\s*:\s*(.+)$/)
          next unless agent_match
          
          agent_type = agent_match[2].strip
          stats_text = agent_match[3]
          
          # Parse participations and wins
          participations = stats_text.match(/Participated:\s*(\d+)/)&.captures&.first&.to_i || 0
          wins = stats_text.match(/Won:\s*(\d+)/)&.captures&.first&.to_i || 0
          
          stats[agent_type] = {
            participations: participations,
            wins: wins
          }
        end
      end

      stats
    rescue StandardError => e
      Mutation.logger.warn("Failed to load existing performance stats: #{e.message}")
      {}
    end

    def save_stats
      FileUtils.mkdir_p(@log_dir) unless Dir.exist?(@log_dir)

      File.open(@stats_file_path, 'w') do |file|
        file.puts '=' * 80
        file.puts 'AGENT PERFORMANCE STATISTICS'
        file.puts '=' * 80
        file.puts "Generated: #{Time.now.strftime('%Y-%m-%d %H:%M:%S')}"
        file.puts '=' * 80
        file.puts

        sorted_stats.each_with_index do |stat, index|
          file.puts "#{index + 1}. #{stat[:agent_type]}:"
          file.puts "   Participated: #{stat[:participations]} | Won: #{stat[:wins]} | Win Rate: #{stat[:win_percentage]}%"
          file.puts
        end

        # Add summary
        total_simulations = @stats.values.map { |s| s[:participations] }.max || 0
        file.puts '=' * 80
        file.puts "Total Simulations Tracked: #{total_simulations}"
        file.puts '=' * 80
      end

      Mutation.logger.info("Updated agent performance statistics in #{@stats_file_path}")
    rescue StandardError => e
      Mutation.logger.error("Failed to save performance stats: #{e.message}")
    end
  end
end