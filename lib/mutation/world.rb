# frozen_string_literal: true

require_relative 'world_impl'

module Mutation
  # World is now a thin wrapper around WorldImpl
  # All agents run as separate OS processes
  class World < WorldImpl
    def initialize(width: nil, height: nil, size: nil, seed_code: nil, agent_executables: nil)
      # Use provided agent executables or default to configured default agent
      executables = agent_executables || [Mutation.configuration.default_agent_executable].compact
      
      if executables.empty?
        raise "No agent executables provided and no default agent executable configured"
      end
      
      super(width: width, height: height, size: size, seed_code: seed_code, agent_executables: executables)
    end
  end
end