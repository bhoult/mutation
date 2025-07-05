# frozen_string_literal: true

require 'fileutils'

module Mutation
  class ProcessMutationEngine
    MUTATION_TYPES = %i[numeric probability threshold operator personality].freeze

    def initialize
      @mutation_strategies = {
        numeric: method(:mutate_numeric),
        probability: method(:mutate_probability),
        threshold: method(:mutate_threshold),
        operator: method(:mutate_operator),
        personality: method(:mutate_personality)
      }
    end

    def create_mutated_agent_script(parent_agent)
      # Read the base agent script
      base_script_path = parent_agent.executable_path
      base_code = File.read(base_script_path)
      
      # Apply mutations to the code
      mutated_code = mutate_code(base_code)
      
      # Create a new script file for the offspring
      offspring_script_path = create_offspring_script(mutated_code, parent_agent.agent_id)
      
      Mutation.logger.debug("Created mutated script for offspring of #{parent_agent.agent_id}") if should_log_mutation?
      
      offspring_script_path
    end

    private

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
        :operator
      when /'aggression'.*rand/, /'greed'.*rand/, /'cooperation'.*rand/, /'death_threshold'.*rand/
        :personality
      end
    end

    def mutate_numeric(line)
      line.gsub(/\d+/) do |match|
        old_value = match.to_i
        if old_value < 5
          # For small numbers (thresholds), vary by ±1-2
          variation = rand(1..2)
          new_value = old_value + rand(-variation..variation)
          [new_value, 1].max.to_s
        else
          # For larger numbers, vary by 20%
          variation = [old_value * 0.2, 1].max.to_i
          new_value = old_value + rand(-variation..variation)
          [new_value, 1].max.to_s
        end
      end
    end

    def mutate_probability(line)
      line.gsub(/rand < \d+\.\d+|rand > \d+\.\d+/) do |match|
        operator = match.include?('<') ? '<' : '>'
        old_prob = match.match(/\d+\.\d+/)[0].to_f
        
        # Mutate probability by ±0.1-0.3
        variation = rand(0.1..0.3)
        new_prob = old_prob + rand(-variation..variation)
        new_prob = [[new_prob, 0.1].max, 0.9].min # Keep between 0.1 and 0.9
        
        "rand #{operator} #{new_prob.round(1)}"
      end
    end

    def mutate_threshold(line)
      line.gsub(/[<>]=?\s*\d+/) do |match|
        operator = match.match(/[<>]=?/)[0]
        old_threshold = match.match(/\d+/)[0].to_i
        
        # Mutate threshold by ±1-3
        variation = rand(1..3)
        new_threshold = old_threshold + rand(-variation..variation)
        new_threshold = [new_threshold, 1].max # Keep positive
        
        "#{operator} #{new_threshold}"
      end
    end

    def mutate_operator(line)
      # Occasionally change comparison operators
      return line unless rand < 0.1 # Only 10% chance
      
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
        shift = rand(-0.2..0.2)
        new_min = [min_val + shift, 0.1].max
        new_max = [max_val + shift, new_min + 0.1].max
        new_max = [new_max, 1.0].min
        
        "rand(#{new_min.round(1)}..#{new_max.round(1)})"
      end.gsub(/rand\((\d+)\.\.(\d+)\)/) do |match|
        # Mutate integer ranges (like death_threshold)
        min_val = $1.to_i
        max_val = $2.to_i
        
        # Shift range by ±1
        shift = rand(-1..1)
        new_min = [min_val + shift, 1].max
        new_max = [max_val + shift, new_min + 1].max
        new_max = [new_max, 5].min # Cap at reasonable value
        
        "rand(#{new_min}..#{new_max})"
      end
    end

    def create_offspring_script(mutated_code, parent_id)
      # Create a unique script file for the offspring
      offspring_id = "offspring_#{parent_id}_#{Time.now.to_i}_#{rand(1000)}"
      script_dir = "/tmp/agents/scripts"
      FileUtils.mkdir_p(script_dir)
      
      script_path = File.join(script_dir, "#{offspring_id}.rb")
      
      # Write the mutated code to the new script
      File.write(script_path, mutated_code)
      File.chmod(0755, script_path) # Make executable
      
      script_path
    end
  end
end