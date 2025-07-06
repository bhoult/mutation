# Fingerprint: c5a30e11357a9f5f
# Created: 2025-07-05T22:15:40Z
# Generation: 1
#!/usr/bin/env ruby
# frozen_string_literal: true

# Example Ruby agent for the mutation simulator
# This agent implements a simple aggressive strategy

require 'json'



def choose_action(world_state, memory)
  neighbors = world_state['neighbors'] || {}
  my_energy = world_state['energy'] || 0
  
  # Find the neighbor with the highest energy (handle empty neighbors)
  if neighbors.empty?
    target_direction, target_info = ['north', { 'energy' => 0 }]
  else
    best_target = neighbors.max_by { |direction, info| (info || {})['energy'] || 0 }
    target_direction, target_info = best_target
  end
  
  # Update memory with observations
  memory['turns_played'] = (memory['turns_played'] || 0) + 1
  memory['last_position'] = world_state['position']
  memory['energy_history'] = (memory['energy_history'] || [])
  memory['energy_history'] << my_energy
  memory['energy_history'] = memory['energy_history'].last(10) # Keep last 10
  
  # Initialize agent personality if not set (adds variation)
  if memory['personality'].nil?
    memory['personality'] = {
      'aggression' => rand(0.3..0.9),        # How likely to attack
      'greed' => rand(0.2..0.8),            # Energy thresholds
      'cooperation' => rand(0.1..0.6),      # Willingness to not attack
      'death_threshold' => rand(1..3)       # When to give up
    }
  end
  
  personality = memory['personality']
  
  # Strategy: Dynamic behavior with personality variation
  if my_energy <= personality['death_threshold'] && (memory['energy_history'][-3..-1] || []).all? { |e| e <= personality['death_threshold'] + 1 }
    # Die if consistently very low energy - makes room for evolution
    action = { action: 'die' }
  elsif my_energy >= (6 + personality['greed'] * 4).round && any_empty_neighbors?(neighbors) && should_replicate?(memory)
    action = { action: 'replicate' }
    memory['replications_made'] = (memory['replications_made'] || 0) + 1
  elsif target_info['energy'] >= 3 && my_energy >= 3 && target_info['energy'] > my_energy && rand < personality['aggression']
    # Attack if target has more energy than us and we're feeling aggressive
    action = { action: 'attack', target: target_direction }
    memory['attacks_made'] = (memory['attacks_made'] || 0) + 1
  elsif my_energy < (4 + personality['greed'] * 3).round
    # Rest if we need energy (threshold varies by personality)
    action = { action: 'rest' }
    memory['rests_made'] = (memory['rests_made'] || 0) + 1
  else
    # If we have good energy but can't replicate, maybe attack
    if target_info['energy'] >= 2 && my_energy >= 4 && rand < personality['aggression'] * 0.7
      action = { action: 'attack', target: target_direction }
      memory['attacks_made'] = (memory['attacks_made'] || 0) + 1
    else
      action = { action: 'rest' }
      memory['rests_made'] = (memory['rests_made'] || 0) + 1
    end
  end
  
  [action, memory]
end

def any_empty_neighbors?(neighbors)
  neighbors.any? { |_, info| info['energy'] == 0 }
end

def should_replicate?(memory)
  # Only replicate occasionally to prevent population explosion
  replications = memory['replications_made'] || 0
  turns = memory['turns_played'] || 1
  
  # Limit replication to once every 3 turns minimum, and allow more replications early on
  return false if replications > 2 && turns - (memory['last_replication_turn'] || 0) < 3
  
  # Update last replication turn
  memory['last_replication_turn'] = turns
  true
end

# Main agent loop
begin
  while input = $stdin.gets
    message = JSON.parse(input.strip)
    
    # Handle death command from world
    if message['command'] == 'die'
      # No persistent memory to save for this agent type
      exit(0)
    end
    
    # Regular world state processing
    world_state = message
    memory = world_state['memory'] || {}
    
    action, updated_memory = choose_action(world_state, memory)
    
    response = action.merge(memory: updated_memory)
    puts JSON.generate(response)
    $stdout.flush
    
    # Exit gracefully if we decided to die
    if action[:action] == 'die'
      exit(0)
    end
  end
rescue => e
  # Fallback to rest if anything goes wrong
  error_response = { 
    action: 'rest', 
    message: "Error: #{e.message}",
    memory: {}
  }
  puts JSON.generate(error_response)
  $stdout.flush
end