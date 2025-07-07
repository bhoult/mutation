#!/usr/bin/env ruby
# frozen_string_literal: true

# Reproductive Colonizer - Focuses on rapid population growth
# Strategy: Replicates aggressively, spreads offspring across the map
# Creates colonies of related agents, minimal combat

require 'json'

begin
  while (input = $stdin.gets)
    message = JSON.parse(input.strip)
    
    # Handle death command from world
    exit(0) if message['command'] == 'die'
    
    # Get world state info
    vision = message['vision'] || {}
    my_energy = message['energy'] || 0
    generation = message['generation'] || 1
    memory = message['memory'] || {}
    
    # Track replication history
    replications = memory['replications'] || 0
    last_replication_energy = memory['last_replication_energy'] || 0
    colony_direction = memory['colony_direction'] || nil
    
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
    
    # Count adjacent spaces
    adjacent_info = {
      empty: [],
      agents: [],
      dead: []
    }
    
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      
      if cell_info.nil?
        adjacent_info[:empty] << dir
      elsif cell_info['type'] == 'living_agent'
        adjacent_info[:agents] << { direction: dir, energy: cell_info['energy'] || 10 }
      elsif cell_info['type'] == 'dead_agent'
        adjacent_info[:dead] << dir
      end
    end
    
    # Calculate colony density (agents within 3 squares)
    nearby_agents = 0
    vision.each do |relative_pos, cell_info|
      if cell_info['type'] == 'living_agent'
        dx, dy = relative_pos.split(',').map(&:to_i)
        distance = dx.abs + dy.abs
        nearby_agents += 1 if distance <= 3
      end
    end
    
    # Determine if we should spread out
    crowded = nearby_agents >= 4
    
    # Energy thresholds based on generation
    replication_threshold = case generation
                          when 1..3 then 8   # Early gens replicate sooner
                          when 4..10 then 10 # Mid gens more careful
                          else 12            # Late gens most careful
                          end
    
    action = if my_energy <= 2
               # Critical energy - must rest
               { action: 'rest' }
             elsif my_energy >= replication_threshold && !adjacent_info[:empty].empty?
               # Ready to replicate!
               if crowded && colony_direction
                 # Try to place offspring in colony direction
                 if adjacent_info[:empty].include?(colony_direction)
                   { action: 'replicate' }
                 else
                   # Move towards colony direction
                   { action: 'move', target: adjacent_info[:empty].sample }
                 end
               else
                 # Just replicate anywhere
                 { action: 'replicate' }
               end
             elsif crowded && !adjacent_info[:empty].empty? && my_energy >= 7 # MUTATION: was: elsif crowded && !adjacent_info[:empty].empty? && my_energy >= 6
               # Too crowded - spread out to new territory
               # Pick a consistent direction for the colony
               new_colony_dir = colony_direction || adjacent_info[:empty].sample
               { action: 'move', target: adjacent_info[:empty].include?(new_colony_dir) ? new_colony_dir : adjacent_info[:empty].sample }
             elsif !adjacent_info[:dead].empty? && my_energy < replication_threshold - 2
               # Eat corpses when needed for replication energy
               { action: 'move', target: adjacent_info[:dead].first }
             elsif adjacent_info[:agents].size == 1 && adjacent_info[:agents].first[:energy] <= 2 && my_energy >= 8 # MUTATION: was: elsif adjacent_info[:agents].size == 1 && adjacent_info[:agents].first[:energy] <= 3 && my_energy >= 6
               # Opportunistic attack on very weak agents
               { action: 'attack', target: adjacent_info[:agents].first[:direction] }
             elsif my_energy < replication_threshold && rand < 0.9 # MUTATION: was: elsif my_energy < replication_threshold && rand < 0.8
               # Build energy for next replication
               { action: 'rest' }
             elsif !adjacent_info[:empty].empty? && rand < 0.3
               # Occasionally reposition
               { action: 'move', target: adjacent_info[:empty].sample }
             else
               # Default: rest to build energy
               { action: 'rest' }
             end
    
    # Update memory
    new_replications = action[:action] == 'replicate' ? replications + 1 : replications
    new_colony_direction = if crowded && !colony_direction && !adjacent_info[:empty].empty?
                            adjacent_info[:empty].sample
                          else
                            colony_direction
                          end
    
    new_memory = {
      'replications' => new_replications,
      'last_replication_energy' => action[:action] == 'replicate' ? my_energy : last_replication_energy,
      'colony_direction' => new_colony_direction
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