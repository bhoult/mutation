require 'spec_helper'

RSpec.describe Mutation::Agent do
  let(:agent) { described_class.new }
  
  describe '#initialize' do
    it 'creates an agent with default values' do
      expect(agent.id).to be_a(String)
      expect(agent.energy).to eq(10)
      expect(agent.generation).to eq(0)
      expect(agent.behavior).to be_a(Proc)
    end
    
    it 'accepts custom parameters' do
      custom_agent = described_class.new(
        energy: 20,
        generation: 5,
        parent_id: 'test-parent'
      )
      
      expect(custom_agent.energy).to eq(20)
      expect(custom_agent.generation).to eq(5)
      expect(custom_agent.parent_id).to eq('test-parent')
    end
  end
  
  describe '#generate_base_code' do
    it 'generates valid Ruby code' do
      code = agent.generate_base_code
      expect(code).to include('Proc.new')
      expect(code).to include('env[:neighbor_energy]')
      expect(code).to include(':attack')
      expect(code).to include(':rest')
      expect(code).to include(':replicate')
    end
  end
  
  describe '#act' do
    let(:env) { { neighbor_energy: 5 } }
    
    it 'returns a valid action' do
      action = agent.act(env)
      expect([:attack, :rest, :replicate, :die]).to include(action)
    end
    
    it 'returns :die when energy is 0' do
      agent.energy = 0
      expect(agent.act(env)).to eq(:die)
    end
    
    it 'returns :die when behavior is nil' do
      agent.behavior = nil
      expect(agent.act(env)).to eq(:die)
    end
  end
  
  describe '#alive?' do
    it 'returns true when energy > 0' do
      agent.energy = 5
      expect(agent.alive?).to be true
    end
    
    it 'returns false when energy <= 0' do
      agent.energy = 0
      expect(agent.alive?).to be false
      
      agent.energy = -1
      expect(agent.alive?).to be false
    end
  end
  
  describe '#fitness' do
    it 'calculates fitness based on energy and generation' do
      agent.energy = 10
      agent.generation = 2
      expect(agent.fitness).to eq(30) # 10 * (2 + 1)
    end
  end
  
  describe '#to_hash' do
    it 'returns a hash representation' do
      hash = agent.to_hash
      expect(hash).to include(:id, :energy, :generation, :fitness)
      expect(hash[:id]).to eq(agent.id)
      expect(hash[:energy]).to eq(agent.energy)
    end
  end
end 