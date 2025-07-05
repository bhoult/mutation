require 'securerandom'

module Mutation
  class Agent
    attr_accessor :id, :energy, :code_str, :behavior, :generation, :parent_id, :mutations_count
    
    def initialize(code_str: nil, energy: nil, generation: 0, parent_id: nil)
      @id = SecureRandom.hex(4)
      @energy = energy || Mutation.configuration.initial_energy
      @generation = generation
      @parent_id = parent_id
      @mutations_count = 0
      @code_str = code_str || generate_base_code
      @behavior = compile_behavior(@code_str)
      
      validate_agent
    end
    
    def generate_base_code
      threshold = rand(3..8)
      probability = rand(0.1..0.4).round(1)
      
      <<~RUBY
        Proc.new do |env|
          if env[:neighbor_energy] < #{threshold}
            :attack
          elsif rand < #{probability}
            :replicate
          else
            :rest
          end
        end
      RUBY
    end
    
    def compile_behavior(code)
      if Mutation.configuration.safe_mode
        compile_safe(code)
      else
        eval(code)
      end
    rescue SyntaxError, StandardError => e
      Mutation.logger.error "Failed to compile behavior for agent #{@id}: #{e.message}"
      nil
    end
    
    def compile_safe(code)
      # Basic safety checks
      dangerous_patterns = [
        /system\s*\(/,
        /`[^`]*`/,
        /exec\s*\(/,
        /File\./,
        /Dir\./,
        /IO\./,
        /Process\./,
        /require/,
        /load/
      ]
      
      dangerous_patterns.each do |pattern|
        if code.match?(pattern)
          raise SecurityError, "Dangerous pattern detected: #{pattern}"
        end
      end
      
      eval(code)
    end
    
    def validate_agent
      unless @behavior.is_a?(Proc)
        @behavior = create_fallback_behavior
        Mutation.logger.warn "Agent #{@id} using fallback behavior"
      end
    end
    
    def create_fallback_behavior
      Proc.new { |env| :rest }
    end
    
    def act(env)
      return :die if @energy <= 0 || @behavior.nil?
      
      begin
        action = @behavior.call(env)
        validate_action(action)
      rescue => e
        Mutation.logger.debug "Agent #{@id} behavior error: #{e.message}"
        :die
      end
    end
    
    def validate_action(action)
      valid_actions = [:attack, :rest, :replicate, :die]
      return action if valid_actions.include?(action)
      
      Mutation.logger.warn "Agent #{@id} returned invalid action: #{action}"
      :rest
    end
    
    def alive?
      @energy > 0
    end
    
    def dead?
      !alive?
    end
    
    def fitness
      @energy * (@generation + 1)
    end
    
    def to_hash
      {
        id: @id,
        energy: @energy,
        generation: @generation,
        parent_id: @parent_id,
        mutations_count: @mutations_count,
        fitness: fitness
      }
    end
    
    def to_s
      "Agent(#{@id}, E:#{@energy}, G:#{@generation})"
    end
  end
end 