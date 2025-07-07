# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'time'
require 'set'

module Mutation
  class MutatedAgentManager
    # Use mutations directory in the project agents folder
    MUTATIONS_DIR = File.join(File.expand_path('../../../', __FILE__), 'agents')
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
        
        mutation_data = {
          code: mutated_code,
          original_agent: File.basename(original_agent, '.rb'),
          is_mutation: true,
          path: nil # No path for in-memory mutations
        }
        
        mutations << mutation_data
        puts "CREATE_MUTATION: #{mutation_data[:original_agent]} is_mutation=#{mutation_data[:is_mutation]}"
      end
      
      mutations
    end

    # Save a surviving mutated agent
    def save_survivor(agent_data, simulation_stats)
      Mutation.logger.info("SAVE_SURVIVOR: Starting save process...")
      Mutation.logger.info("SAVE_SURVIVOR: agent_data[:is_mutation] = #{agent_data[:is_mutation]}")
      return unless agent_data[:is_mutation]
      
      # Skip saving if survival time is too short (less than 10 ticks)
      survival_ticks = simulation_stats[:survival_ticks] || 0
      if survival_ticks < 10
        Mutation.logger.info("SAVE_SURVIVOR: Skipping - only survived #{survival_ticks} ticks (minimum 10)")
        return
      end
      
      original_name = agent_data[:original_agent]
      
      # Only save mutations for agents that exist in the main agents folder
      main_agent_path = File.join(MUTATIONS_DIR, "#{original_name}.rb")
      unless File.exist?(main_agent_path)
        Mutation.logger.info("SAVE_SURVIVOR: Skipping - #{original_name} not in main agents folder")
        return
      end
      
      mutations_dir = File.join(MUTATIONS_DIR, "#{original_name}#{MUTATIONS_SUFFIX}")
      Mutation.logger.info("SAVE_SURVIVOR: Creating directory #{mutations_dir}")
      FileUtils.mkdir_p(mutations_dir)
      
      # Generate watermark (content hash)
      content_hash = Digest::SHA256.hexdigest(agent_data[:code])[0...8]
      
      # Check if this exact mutation already exists
      if mutation_exists?(mutations_dir, content_hash)
        Mutation.logger.info("SAVE_SURVIVOR: Skipping duplicate - content hash #{content_hash} already exists")
        return
      end
      
      # Create filename with survival stats, fingerprint, and timestamp
      timestamp = Time.now.strftime('%Y%m%d_%H%M%S')
      survival_ticks = simulation_stats[:survival_ticks] || 0
      generation = simulation_stats[:generation] || 1
      filename = "#{original_name}_#{content_hash}_survival_#{survival_ticks}_gen_#{generation}_#{timestamp}.rb"
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
      Mutation.logger.debug("SAVE_SURVIVOR: Writing file to #{filepath}")
      File.write(filepath, file_content)
      Mutation.logger.debug("SAVE_SURVIVOR: File written successfully")
      
      # Manage folder size (keep only top 50 by survival time)
      manage_mutation_folder_size(mutations_dir)
      
      Mutation.logger.info("Saved surviving mutation: #{filename} (lived #{survival_ticks} ticks)")
      Mutation.logger.debug("SAVE_SURVIVOR: Save completed successfully")
      
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
      mutation_dirs = Dir.glob(File.join(MUTATIONS_DIR, "*#{MUTATIONS_SUFFIX}"))
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
        original_agent: selected[:original_agent],
        path: selected[:path]
      }
    end

    # Select only original (non-mutation) agents for population base
    def select_original_agent
      original_agents = get_original_agents
      return nil if original_agents.empty?
      
      selected_path = original_agents.sample
      
      result = {
        code: File.read(selected_path),
        name: File.basename(selected_path, '.rb'),
        is_mutation: false,
        original_agent: nil,
        path: selected_path
      }
      
      puts "SELECT_ORIGINAL: #{result[:name]} is_mutation=#{result[:is_mutation]}"
      result
    end

    private

    def get_original_agents
      # Look for agent files in the main agents directory only
      project_root = File.expand_path('../../../', __FILE__)
      agent_paths = []
      
      # Check main agents directory
      agents_dir = File.join(project_root, 'agents')
      if Dir.exist?(agents_dir)
        # Get all .rb files but exclude mutation directories and temp files
        all_rb_files = Dir.glob(File.join(agents_dir, "*.rb"))
        agent_paths = all_rb_files.reject do |path|
          basename = File.basename(path)
          # Exclude temp mutation files and any files in subdirectories
          basename.start_with?('temp_') || path.include?('/temp_mutation_agents/')
        end
      end
      
      # Don't include examples - those are just examples, not part of the simulation
      
      Mutation.logger.debug("GET_ORIGINAL_AGENTS: Found #{agent_paths.size} agents: #{agent_paths.map {|p| File.basename(p)}}")
      agent_paths
    end

    def create_mutation(original_agent_path)
      original_code = File.read(original_agent_path)
      @mutation_engine.mutate_code(original_code)
    end

    def mutation_exists?(mutations_dir, content_hash)
      # First check if we've already saved this hash in memory (for current session)
      @saved_hashes ||= Set.new
      return true if @saved_hashes.include?(content_hash)
      
      # Then check existing files
      exists = Dir.glob(File.join(mutations_dir, "*.rb")).any? do |existing_file|
        existing_content = File.read(existing_file)
        existing_content.include?("# Content Hash: #{content_hash}")
      end
      
      # Add to saved hashes if we're going to save it
      @saved_hashes.add(content_hash) unless exists
      
      exists
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