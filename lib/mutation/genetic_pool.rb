# frozen_string_literal: true

require 'digest'
require 'fileutils'

module Mutation
  class GeneticPool
    AGENTS_DIR = File.join(Dir.pwd, 'agents')
    
    def initialize
      ensure_agents_directory
      seed_initial_population if empty?
    end
    
    def empty?
      agent_files.empty?
    end
    
    def size
      agent_files.size
    end
    
    def agent_files
      Dir.glob(File.join(AGENTS_DIR, '*.rb')).sort
    end
    
    def random_agent_path
      files = agent_files
      return nil if files.empty?
      files.sample
    end
    
    def add_agent(code, parent_fingerprint = nil)
      # Generate fingerprint from code content
      fingerprint = generate_fingerprint(code)
      filename = "agent_#{fingerprint}.rb"
      filepath = File.join(AGENTS_DIR, filename)
      
      # Skip if agent already exists (genetic diversity preservation)
      return filepath if File.exist?(filepath)
      
      # Extract shebang line and rest of code
      lines = code.lines
      shebang_line = ""
      code_lines = []
      
      lines.each do |line|
        if line.start_with?('#!/usr/bin/env ruby')
          shebang_line = line
        else
          code_lines << line
        end
      end
      
      # Add generation metadata as comments
      metadata = build_metadata(fingerprint, parent_fingerprint)
      
      # Assemble final code: shebang first, then metadata, then code
      full_code = shebang_line + metadata + code_lines.join
      
      # Write agent to genetic pool
      File.write(filepath, full_code)
      File.chmod(0755, filepath)
      
      Mutation.logger.debug("Added new agent to genetic pool: #{filename}")
      filepath
    end
    
    def remove_agent(filepath)
      return unless File.exist?(filepath)
      File.delete(filepath)
      Mutation.logger.debug("Removed agent from genetic pool: #{File.basename(filepath)}")
    end
    
    def cleanup_extinct_lineages(survival_threshold = nil)
      survival_threshold ||= Mutation.configuration.genetic_survival_threshold
      # Remove agents that haven't been selected for a long time
      # This can be implemented later with usage tracking
    end
    
    def get_lineage_info(filepath)
      return {} unless File.exist?(filepath)
      
      content = File.read(filepath)
      metadata = {}
      
      content.lines.each do |line|
        if line =~ /^# (\w+): (.+)$/
          metadata[$1] = $2.strip
        end
      end
      
      metadata
    end
    
    def statistics
      {
        total_agents: size,
        directory: AGENTS_DIR,
        sample_agents: agent_files.first(Mutation.configuration.genetic_sample_size).map { |f| File.basename(f) }
      }
    end
    
    private
    
    def ensure_agents_directory
      FileUtils.mkdir_p(AGENTS_DIR)
    end
    
    def seed_initial_population
      # Copy the base agent to start the genetic pool
      base_agent_path = File.join(Dir.pwd, 'examples', 'agents', 'ruby_agent.rb')
      
      if File.exist?(base_agent_path)
        base_code = File.read(base_agent_path)
        add_agent(base_code)
        Mutation.logger.info("Seeded genetic pool with base agent")
      else
        # Create a minimal agent if no base exists
        minimal_agent = create_minimal_agent
        add_agent(minimal_agent)
        Mutation.logger.info("Created minimal agent for genetic pool")
      end
    end
    
    def generate_fingerprint(code)
      # Remove comments and whitespace for fingerprinting
      normalized_code = code.gsub(/^#.*$/, '').gsub(/\s+/, ' ').strip
      Digest::SHA256.hexdigest(normalized_code)[0..(Mutation.configuration.genetic_fingerprint_length - 1)]
    end
    
    def build_metadata(fingerprint, parent_fingerprint)
      timestamp = Time.now.utc.iso8601
      
      metadata = []
      metadata << "# Fingerprint: #{fingerprint}"
      metadata << "# Created: #{timestamp}"
      metadata << "# Parent: #{parent_fingerprint}" if parent_fingerprint
      metadata << "# Generation: #{calculate_generation(parent_fingerprint)}"
      metadata << ""
      
      metadata.join("\n")
    end
    
    def calculate_generation(parent_fingerprint)
      return 1 unless parent_fingerprint
      
      # Find parent agent and increment its generation
      agent_files.each do |filepath|
        info = get_lineage_info(filepath)
        if info['Fingerprint'] == parent_fingerprint
          return (info['Generation']&.to_i || 0) + 1
        end
      end
      
      1  # Default if parent not found
    end
    
    def create_minimal_agent
      <<~RUBY
        #!/usr/bin/env ruby
        # frozen_string_literal: true
        
        # Minimal agent for mutation simulator
        
        require 'json'
        
        # Agent memory file
        MEMORY_FILE = "/tmp/agents/\#{ENV['AGENT_ID']}/\#{ENV['AGENT_ID']}.json"
        
        def load_memory
          return {} unless File.exist?(MEMORY_FILE)
          JSON.parse(File.read(MEMORY_FILE))
        rescue
          {}
        end
        
        def save_memory(memory)
          File.write(MEMORY_FILE, JSON.pretty_generate(memory))
        rescue
          # Ignore errors - memory is optional
        end
        
        def choose_action(world_state, memory)
          neighbors = world_state['neighbors'] || {}
          my_energy = world_state['energy'] || 0
          
          # Find the neighbor with the highest energy
          if neighbors.empty?
            target_direction, target_info = ['north', { 'energy' => 0 }]
          else
            best_target = neighbors.max_by { |direction, info| (info || {})['energy'] || 0 }
            target_direction, target_info = best_target
          end
          
          # Update memory
          memory['turns_played'] = (memory['turns_played'] || 0) + 1
          
          # Simple strategy: replicate if enough energy, attack if target has energy, otherwise rest
          if my_energy >= 8 && neighbors.any? { |_, info| info['energy'] == 0 }
            action = { action: 'replicate' }
          elsif target_info['energy'] >= 3 && my_energy >= 3
            action = { action: 'attack', target: target_direction }
          else
            action = { action: 'rest' }
          end
          
          [action, memory]
        end
        
        # Main agent loop
        begin
          memory = load_memory
          
          while input = $stdin.gets
            world_state = JSON.parse(input.strip)
            
            action, updated_memory = choose_action(world_state, memory)
            save_memory(updated_memory)
            
            puts JSON.generate(action)
            $stdout.flush
            
            memory = updated_memory
          end
        rescue => e
          # Fallback to rest if anything goes wrong
          puts JSON.generate({ action: 'rest', message: "Error: \#{e.message}" })
          $stdout.flush
        end
      RUBY
    end
  end
end