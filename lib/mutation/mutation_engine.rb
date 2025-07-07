# frozen_string_literal: true

require 'fileutils'
require 'digest'
require_relative 'genetic_pool'

module Mutation
  class MutationEngine
    MUTATION_TYPES = %i[numeric probability threshold operator personality].freeze

    def initialize
      @mutation_strategies = {
        numeric: method(:mutate_numeric),
        probability: method(:mutate_probability),
        threshold: method(:mutate_threshold),
        operator: method(:mutate_operator),
        personality: method(:mutate_personality)
      }
      @genetic_pool = GeneticPool.new
    end

    def create_mutated_agent_script(parent_agent)
      # Read the parent agent script
      parent_script_path = parent_agent.executable_path
      parent_code = read_agent_code(parent_script_path)
      
      # Get parent fingerprint for lineage tracking
      parent_fingerprint = extract_fingerprint(parent_script_path)
      
      # Apply mutations to the code
      mutated_code = mutate_code(parent_code)
      
      # Add mutated agent to genetic pool
      offspring_script_path = @genetic_pool.add_agent(mutated_code, parent_fingerprint)
      
      Mutation.logger.debug("Created mutated agent: #{File.basename(offspring_script_path)}") if should_log_mutation?
      
      offspring_script_path
    end

    def random_agent_from_pool
      @genetic_pool.random_agent_path
    end

    def genetic_pool_statistics
      @genetic_pool.statistics
    end

    def mutate_code(code)
      lines = code.lines.map do |line|
        if should_mutate_line?
          mutate_line(line)
        else
          line
        end
      end

      lines.join
    end

    private

    def should_mutate_line?
      rand < Mutation.configuration.mutation_rate
    end

    def should_log_mutation?
      rand < Mutation.configuration.mutation_probability
    end

    def mutate_line(line)
      mutation_type = detect_mutation_type(line)
      return line unless mutation_type

      @mutation_strategies[mutation_type].call(line)
    end

    def detect_mutation_type(line)
      case line
      when /rand\(\d+\.\.\d+\)/, /rand\(\d+\)/
        :numeric
      when /rand < \d+\.\d+/, /rand > \d+\.\d+/
        :probability  
      when /energy.*[<>]=?\s*\d+/, /my_energy.*[<>]=?\s*\d+/
        :threshold
      when /[<>]=?/
        # Only mutate comparison operators, not array append (<<) or other operators
        return nil if line.include?('<<') || line.include?('>>')
        :operator
      when /'aggression'.*rand/, /'greed'.*rand/, /'cooperation'.*rand/, /'death_threshold'.*rand/
        :personality
      end
    end

    def mutate_numeric(line)
      line.gsub(/\d+/) do |match|
        old_value = match.to_i
        if old_value < 5
          # For small numbers (thresholds), vary by configured range
          variation = rand(Mutation.configuration.mutation_small_variation_min..Mutation.configuration.mutation_small_variation_max)
          new_value = old_value + rand(-variation..variation)
          [new_value, 1].max.to_s
        else
          # For larger numbers, vary by configured percentage
          variation = [old_value * Mutation.configuration.mutation_large_variation_percent, 1].max.to_i
          new_value = old_value + rand(-variation..variation)
          [new_value, 1].max.to_s
        end
      end
    end

    def mutate_probability(line)
      line.gsub(/rand < \d+\.\d+|rand > \d+\.\d+/) do |match|
        operator = match.include?('<') ? '<' : '>'
        old_prob = match.match(/\d+\.\d+/)[0].to_f
        
        # Mutate probability by configured range
        variation = rand(Mutation.configuration.mutation_probability_variation_min..Mutation.configuration.mutation_probability_variation_max)
        new_prob = old_prob + rand(-variation..variation)
        new_prob = [[new_prob, Mutation.configuration.mutation_probability_min_bound].max, Mutation.configuration.mutation_probability_max_bound].min
        
        "rand #{operator} #{new_prob.round(1)}"
      end
    end

    def mutate_threshold(line)
      line.gsub(/[<>]=?\s*\d+/) do |match|
        operator = match.match(/[<>]=?/)[0]
        old_threshold = match.match(/\d+/)[0].to_i
        
        # Mutate threshold by configured range
        variation = rand(Mutation.configuration.mutation_threshold_variation_min..Mutation.configuration.mutation_threshold_variation_max)
        new_threshold = old_threshold + rand(-variation..variation)
        new_threshold = [new_threshold, 1].max # Keep positive
        
        "#{operator} #{new_threshold}"
      end
    end

    def mutate_operator(line)
      # Occasionally change comparison operators
      return line unless rand < Mutation.configuration.mutation_operator_probability
      
      operators = ['<', '>', '<=', '>=']
      line.gsub(/[<>]=?/) do |match|
        current_operators = operators.dup
        current_operators.delete(match) # Don't pick the same operator
        current_operators.sample
      end
    end

    def mutate_personality(line)
      # Mutate personality trait ranges and fixed values
      line.gsub(/rand\((\d+\.\d+)\.\.(\d+\.\d+)\)/) do |match|
        min_val = $1.to_f
        max_val = $2.to_f
        
        # Shift the range slightly
        shift = rand(Mutation.configuration.mutation_personality_shift_min..Mutation.configuration.mutation_personality_shift_max)
        new_min = [min_val + shift, Mutation.configuration.mutation_personality_min_bound].max
        new_max = [max_val + shift, new_min + 0.1].max
        new_max = [new_max, Mutation.configuration.mutation_personality_max_bound].min
        
        "rand(#{new_min.round(1)}..#{new_max.round(1)})"
      end.gsub(/rand\((\d+)\.\.(\d+)\)/) do |match|
        # Mutate integer ranges (like death_threshold)
        min_val = $1.to_i
        max_val = $2.to_i
        
        # Shift range by configured amount
        shift = rand(Mutation.configuration.mutation_personality_int_shift_min..Mutation.configuration.mutation_personality_int_shift_max)
        new_min = [min_val + shift, 1].max
        new_max = [max_val + shift, new_min + 1].max
        new_max = [new_max, Mutation.configuration.mutation_personality_int_max_bound].min
        
        "rand(#{new_min}..#{new_max})"
      end
    end

    def read_agent_code(script_path)
      content = File.read(script_path)
      lines = content.lines
      
      # Filter out ALL metadata lines and keep only the actual code
      filtered_lines = []
      found_shebang = false
      
      lines.each do |line|
        stripped = line.strip
        
        # Skip metadata headers entirely
        if stripped.start_with?('# Fingerprint:') ||
           stripped.start_with?('# Created:') ||
           stripped.start_with?('# Parent:') ||
           stripped.start_with?('# Generation:')
          next
        elsif line.start_with?('#!/usr/bin/env ruby')
          # Include shebang only once
          unless found_shebang
            filtered_lines << line
            found_shebang = true
          end
        else
          # Include all other lines (code, comments, etc.)
          filtered_lines << line
        end
      end
      
      # Return the clean code
      filtered_lines.join
    end

    def extract_fingerprint(script_path)
      return nil unless File.exist?(script_path)
      
      content = File.read(script_path)
      content.lines.each do |line|
        if line =~ /^# Fingerprint: (.+)$/
          return $1.strip
        end
      end
      
      nil
    end
  end
end