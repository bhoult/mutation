# frozen_string_literal: true

module Mutation
  class AgentCodePool
    attr_reader :agent_codes

    def initialize(directory = 'agents')
      @agent_codes = load_agent_codes(directory)
      raise 'No agent codes found in agents/ directory' if @agent_codes.empty?
    end

    def random_code
      @agent_codes.sample
    end

    private

    def load_agent_codes(directory)
      codes = []
      Dir.glob("#{directory}/*.rb").each do |file_path|
        codes << File.read(file_path)
      end
      codes
    end
  end
end
