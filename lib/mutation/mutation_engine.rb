# frozen_string_literal: true

module Mutation
  class MutationEngine
    MUTATION_TYPES = %i[numeric probability threshold operator].freeze

    def initialize
      @mutation_strategies = {
        numeric: method(:mutate_numeric),
        probability: method(:mutate_probability),
        threshold: method(:mutate_threshold),
        operator: method(:mutate_operator)
      }
    end

    def mutate(agent)
      mutated_code = mutate_code(agent.code_str)

      Mutation.logger.mutation("Mutation from #{agent.id}:\n#{mutated_code}") if should_log_mutation?

      new_agent = Agent.new(
        code_str: mutated_code,
        generation: agent.generation + 1,
        parent_id: agent.id
      )

      new_agent.mutations_count = agent.mutations_count + 1
      new_agent
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
      when /< \d+/, /> \d+/, /== \d+/, /!= \d+/
        :threshold
      when /rand < 0\.\d+/, /rand > 0\.\d+/
        :probability
      when /\d+/
        :numeric
      when /</
        :operator
      end
    end

    def mutate_numeric(line)
      line.gsub(/\d+/) do |match|
        old_value = match.to_i
        variation = [old_value * 0.2, 1].max.to_i
        new_value = old_value + rand(-variation..variation)
        [new_value, 1].max.to_s
      end
    end

    def mutate_probability(line)
      line.gsub(/rand [<>] 0\.\d+/) do |match|
        operator = match.include?('<') ? '<' : '>'
        new_prob = rand(0.1..0.9).round(1)
        "rand #{operator} #{new_prob}"
      end
    end

    def mutate_threshold(line)
      line.gsub(/[<>]=? \d+/) do |match|
        operator = match.match(/[<>]=?/)[0]
        new_threshold = rand(1..15)
        "#{operator} #{new_threshold}"
      end
    end

    def mutate_operator(line)
      # Simple operator mutation
      operators = ['<', '>', '<=', '>=', '==', '!=']

      line.gsub(/[<>]=?/) do |_match|
        operators.sample
      end
    end

    def add_mutation_strategy(type, strategy)
      @mutation_strategies[type] = strategy
    end

    def remove_mutation_strategy(type)
      @mutation_strategies.delete(type)
    end
  end
end
