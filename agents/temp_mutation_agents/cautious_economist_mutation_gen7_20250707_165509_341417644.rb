#!/usr/bin/env ruby
# frozen_string_literal: true

# Cautious Economist - Carefully manages energy like a resource
# Strategy: Calculates risk/reward for every action, maintains reserves
# Tracks energy efficiency and makes data-driven decisions

require 'json'

begin
  while (input = $stdin.gets)
    message = JSON.parse(input.strip)
    
    # Handle death command from world
    exit(0) if message['command'] == 'die'
    
    # Get world state info
    vision = message['vision'] || {}
    my_energy = message['energy'] || 0
    tick = message['tick'] || 0
    memory = message['memory'] || {}
    
    # Economic tracking
    energy_history = memory['energy_history'] || []
    last_action = memory['last_action'] || 'rest'
    last_energy = memory['last_energy'] || my_energy
    successful_attacks = memory['successful_attacks'] || 0
    failed_attacks = memory['failed_attacks'] || 0
    
    # Calculate energy delta from last tick
    energy_delta = my_energy - last_energy
    
    # Update energy history (keep last 5)
    energy_history = (energy_history + [my_energy]).last(5)
    avg_energy = energy_history.sum.to_f / energy_history.size
    
    direction_offsets = {
      'north' => [0, -1],
      'south' => [0, 1], 
      'east' => [1, 0],
      'west' => [-1, 0],
      'north_east' => [1, -1],
      'north_west' => [-1, -1],
      'south_east' => [1, 1],
      'south_west' => [-1, 1]
    }
    
    # Analyze environment
    opportunities = {
      attacks: [],
      corpses: [],
      empty: [],
      threats: []
    }
    
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      
      if cell_info.nil?
        opportunities[:empty] << dir
      elsif cell_info['type'] == 'living_agent'
        agent_energy = cell_info['energy'] || 10
        if agent_energy < my_energy - 2
          opportunities[:attacks] << { direction: dir, energy: agent_energy, profit: agent_energy * 0.3 }
        else
          opportunities[:threats] << { direction: dir, energy: agent_energy }
        end
      elsif cell_info['type'] == 'dead_agent'
        opportunities[:corpses] << { direction: dir, profit: 10 }
      end
    end
    
    # Calculate attack success rate
    total_attacks = successful_attacks + failed_attacks
    attack_success_rate = total_attacks > 0 ? successful_attacks.to_f / total_attacks : 0.5
    
    # Energy management thresholds
    critical_energy = 3
    low_energy = 6
    comfortable_energy = 10
    surplus_energy = 15
    
    # Risk assessment
    threat_level = opportunities[:threats].size
    is_safe = threat_level == 0
    is_dangerous = threat_level >= 2
    
    # Economic decision making
    action = if my_energy <= critical_energy
               # Emergency mode - must rest
               { action: 'rest' }
             elsif !opportunities[:corpses].empty? && my_energy < comfortable_energy
               # Free energy! Always worth it when low
               { action: 'move', target: opportunities[:corpses].first[:direction] }
             elsif !opportunities[:attacks].empty? && attack_success_rate >= 0.6 && my_energy >= low_energy
               # Profitable attack with good success rate
               best_target = opportunities[:attacks].max_by { |a| a[:profit] - (my_energy * 0.1) }
               { action: 'attack', target: best_target[:direction] }
             elsif is_dangerous && !opportunities[:empty].empty?
               # Too risky - retreat
               safest = opportunities[:empty].max_by do |dir|
                 dx, dy = direction_offsets[dir]
                 opportunities[:threats].sum { |t| 
                   tdx, tdy = direction_offsets[t[:direction]]
                   (tdx - dx).abs + (tdy - dy).abs
                 }
               end
               { action: 'move', target: safest }
             elsif my_energy >= surplus_energy && is_safe && avg_energy >= comfortable_energy
               # Good economic position - invest in replication
               { action: 'replicate' }
             elsif my_energy < comfortable_energy && energy_delta >= 1 # MUTATION: was: elsif my_energy < comfortable_energy && energy_delta >= 0
               # Building reserves successfully - continue
               { action: 'rest' }
             elsif !opportunities[:empty].empty? && energy_delta < -1 && rand < 0.3 # MUTATION: was: elsif !opportunities[:empty].empty? && energy_delta < -1 && rand < 0.4
               # Losing energy in current position - relocate
               { action: 'move', target: opportunities[:empty].sample }
             elsif my_energy >= comfortable_energy && !opportunities[:corpses].empty?
               # Comfortable position - collect free resources
               { action: 'move', target: opportunities[:corpses].first[:direction] }
             else
               # Default: rest and accumulate
               { action: 'rest' }
             end
    
    # Track attack outcomes
    new_successful = successful_attacks
    new_failed = failed_attacks
    
    if last_action == 'attack'
      if energy_delta > 0
        new_successful += 1
      else
        new_failed += 1
      end
    end
    
    # Update memory
    new_memory = {
      'energy_history' => energy_history,
      'last_action' => action[:action],
      'last_energy' => my_energy,
      'successful_attacks' => new_successful,
      'failed_attacks' => new_failed
    }
    
    response = action.merge(memory: new_memory)
    puts JSON.generate(response)
    $stdout.flush
  end
rescue StandardError => e
  error_response = { 
    action: 'rest', 
    message: "Error: #{e.message}",
    memory: {}
  }
  puts JSON.generate(error_response)
  $stdout.flush
end