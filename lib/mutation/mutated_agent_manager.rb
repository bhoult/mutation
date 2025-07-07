# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'time'

module Mutation
  class MutatedAgentManager
    AGENTS_DIR = 'agents'
    MUTATIONS_SUFFIX = '_mutations'
    MAX_MUTATIONS_PER_AGENT = 50

    def initialize
      @mutation_engine = MutationEngine.new
    end

    # Create initial mutated agents (10% of population)
    def create_initial_mutations(agent_count)
      mutation_count = (agent_count * 0.1).ceil
      original_agents = get_original_agents
      
      return [] if original_agents.empty?
      
      mutations = []
      mutation_count.times do
        original_agent = original_agents.sample
        mutated_code = create_mutation(original_agent)
        
        mutations << {
          code: mutated_code,
          original_agent: File.basename(original_agent, '.rb'),
          is_mutation: true
        }
      end
      
      mutations
    end

    # Save a surviving mutated agent
    def save_survivor(agent_data, simulation_stats)
      return unless agent_data[:is_mutation]
      
      original_name = agent_data[:original_agent]
      mutations_dir = File.join(AGENTS_DIR, "#{original_name}#{MUTATIONS_SUFFIX}")
      FileUtils.mkdir_p(mutations_dir)
      
      # Generate watermark (content hash)
      content_hash = Digest::SHA256.hexdigest(agent_data[:code])[0...8]
      
      # Check if this exact mutation already exists
      return if mutation_exists?(mutations_dir, content_hash)
      
      # Create filename with survival stats and timestamp
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      survival_ticks = simulation_stats[:survival_ticks] || 0
      generation = simulation_stats[:generation] || 1
      filename = "survival_#{survival_ticks}_ticks_gen_#{generation}_#{timestamp}.rb"
      filepath = File.join(mutations_dir, filename)
      
      # Create file content with metadata header
      file_content = create_mutated_file_content(
        agent_data[:code], 
        simulation_stats.merge(
          content_hash: content_hash,
          original_agent: original_name,
          filename: filename
        )
      )
      
      # Write the file
      File.write(filepath, file_content)
      
      # Manage folder size (keep only top 50 by survival time)
      manage_mutation_folder_size(mutations_dir)
      
      Mutation.logger.info("Saved surviving mutation: #{filename} (lived #{survival_ticks} ticks)")
      
      filepath
    end

    # Get all available agents (original + mutations) for random selection
    def get_all_available_agents
      agents = []
      
      # Get original agents
      get_original_agents.each do |agent_path|
        agents << {
          path: agent_path,
          name: File.basename(agent_path, '.rb'),
          is_mutation: false,
          original_agent: nil
        }
      end
      
      # Get mutated agents
      mutation_dirs = Dir.glob(File.join(AGENTS_DIR, "*#{MUTATIONS_SUFFIX}"))
      mutation_dirs.each do |dir|
        original_name = File.basename(dir, MUTATIONS_SUFFIX)
        
        Dir.glob(File.join(dir, "*.rb")).each do |mutation_path|
          agents << {
            path: mutation_path,
            name: File.basename(mutation_path, '.rb'),
            is_mutation: true,
            original_agent: original_name
          }
        end
      end
      
      agents
    end

    # Select a random agent (weighted equally between originals and mutations)
    def select_random_agent
      available_agents = get_all_available_agents
      return nil if available_agents.empty?
      
      selected = available_agents.sample
      
      {
        code: File.read(selected[:path]),
        name: selected[:name],
        is_mutation: selected[:is_mutation],
        original_agent: selected[:original_agent]
      }
    end

    private

    def get_original_agents
      Dir.glob(File.join(AGENTS_DIR, "*.rb")).reject do |path|
        # Skip any files that might be in mutation subdirectories
        path.include?(MUTATIONS_SUFFIX)
      end
    end

    def create_mutation(original_agent_path)
      original_code = File.read(original_agent_path)
      @mutation_engine.mutate_code(original_code)
    end

    def mutation_exists?(mutations_dir, content_hash)
      Dir.glob(File.join(mutations_dir, "*.rb")).any? do |existing_file|
        existing_content = File.read(existing_file)
        existing_content.include?("# Content Hash: #{content_hash}")
      end
    end

    def create_mutated_file_content(code, metadata)
      header = <<~HEADER
        #!/usr/bin/env ruby
        # =============================================================================
        # MUTATED AGENT - AUTO-GENERATED
        # =============================================================================
        # Original Agent: #{metadata[:original_agent]}
        # Content Hash: #{metadata[:content_hash]}
        # Created: #{metadata[:created_at] || Time.now.strftime('%Y-%m-%d %H:%M:%S')}
        # Survival Time: #{metadata[:survival_ticks]} ticks
        # Generation: #{metadata[:generation]}
        # World Size: #{metadata[:world_size] || 'Unknown'}
        # Total Agents: #{metadata[:total_agents] || 'Unknown'}
        # Simulation Delay: #{metadata[:simulation_delay] || 'Unknown'}
        # Final Agent Count: #{metadata[:final_agent_count] || 1}
        # =============================================================================

      HEADER
      
      # Remove any existing shebang from the original code
      clean_code = code.gsub(/^#!/, '# !')
      
      header + clean_code
    end

    def manage_mutation_folder_size(mutations_dir)
      mutation_files = Dir.glob(File.join(mutations_dir, "*.rb"))
      
      return if mutation_files.size <= MAX_MUTATIONS_PER_AGENT
      
      # Parse survival times from filenames and sort by survival time (descending)
      files_with_survival = mutation_files.map do |file|
        filename = File.basename(file)
        survival_match = filename.match(/survival_(\d+)_ticks/)
        survival_ticks = survival_match ? survival_match[1].to_i : 0
        
        {
          path: file,
          survival_ticks: survival_ticks,
          filename: filename
        }
      end
      
      # Sort by survival time (highest first) and keep only the top MAX_MUTATIONS_PER_AGENT
      files_with_survival.sort_by! { |f| -f[:survival_ticks] }
      files_to_remove = files_with_survival[MAX_MUTATIONS_PER_AGENT..-1] || []
      
      files_to_remove.each do |file_info|
        File.delete(file_info[:path])
        Mutation.logger.debug("Removed low-survival mutation: #{file_info[:filename]} (#{file_info[:survival_ticks]} ticks)")
      end
      
      if files_to_remove.any?
        Mutation.logger.info("Cleaned mutation folder: removed #{files_to_remove.size} low-survival mutations")
      end
    end
  end
end