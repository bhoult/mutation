# frozen_string_literal: true

require_relative '../mutation'
require_relative 'genetic_pool'
require_relative 'process_mutation_engine'

module Mutation
  # Demo class to showcase genetic pool functionality
  class GeneticPoolDemo
    def initialize
      @genetic_pool = GeneticPool.new
      @mutation_engine = ProcessMutationEngine.new
    end
    
    def run_demo
      puts "🧬 Genetic Pool Demo"
      puts "=" * 50
      
      # Show initial pool state
      show_pool_status
      
      # Create a few mutations manually
      puts "\n🔬 Creating 3 mutations from base agent..."
      3.times do |i|
        create_mutation_demo(i + 1)
        sleep(0.1) # Ensure different timestamps
      end
      
      # Show final pool state
      puts "\n📊 Final genetic pool state:"
      show_pool_status
      show_agent_details
    end
    
    private
    
    def show_pool_status
      stats = @genetic_pool.statistics
      puts "\n📁 Genetic Pool Status:"
      puts "   Directory: #{stats[:directory]}"
      puts "   Total agents: #{stats[:total_agents]}"
      puts "   Sample agents: #{stats[:sample_agents].join(', ')}"
    end
    
    def create_mutation_demo(iteration)
      base_agent_path = @genetic_pool.random_agent_path
      return unless base_agent_path
      
      # Simulate agent replication by reading and mutating base code
      base_code = File.read(base_agent_path)
      
      # Extract original code (without metadata)
      code_lines = base_code.lines
      code_start = code_lines.find_index { |line| line.start_with?('#!/usr/bin/env ruby') } || 0
      clean_code = code_lines[code_start..-1].join
      
      # Apply mutations
      mutated_code = @mutation_engine.send(:mutate_code, clean_code)
      
      # Add to genetic pool
      parent_fingerprint = @mutation_engine.send(:extract_fingerprint, base_agent_path)
      new_agent_path = @genetic_pool.add_agent(mutated_code, parent_fingerprint)
      
      puts "   ✨ Mutation #{iteration}: #{File.basename(new_agent_path)}"
    end
    
    def show_agent_details
      puts "\n🔍 Agent lineage details:"
      @genetic_pool.agent_files.each do |filepath|
        info = @genetic_pool.get_lineage_info(filepath)
        filename = File.basename(filepath)
        puts "   #{filename}:"
        puts "     Generation: #{info['Generation'] || 'Unknown'}"
        puts "     Created: #{info['Created'] || 'Unknown'}"
        puts "     Parent: #{info['Parent'] || 'None (Base)'}"
      end
    end
  end
end

# Run the demo if this file is executed directly
if __FILE__ == $0
  demo = Mutation::GeneticPoolDemo.new
  demo.run_demo
end