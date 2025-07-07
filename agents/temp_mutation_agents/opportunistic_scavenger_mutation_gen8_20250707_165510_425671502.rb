#!/usr/bin/env ruby
# frozen_string_literal: true

# Opportunistic Scavenger - Specializes in finding and consuming dead agents
# Strategy: Actively searches for corpses, avoids combat, efficient movement
# Uses memory to track explored areas and known corpse locations

require 'json'

begin
  while (input = $stdin.gets)
    message = JSON.parse(input.strip)
    
    # Handle death command from world
    exit(0) if message['command'] == 'die'
    
    # Get world state info
    vision = message['vision'] || {}
    my_energy = message['energy'] || 0
    memory = message['memory'] || {}
    tick = message['tick'] || 0
    
    # Memory tracking
    known_corpses = memory['known_corpses'] || []
    last_meal_tick = memory['last_meal_tick'] || 0
    explored_recently = memory['explored_recently'] || []
    
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
    
    # Scan for dead agents in entire vision
    dead_agents = []
    vision.each do |relative_pos, cell_info|
      if cell_info['type'] == 'dead_agent'
        dx, dy = relative_pos.split(',').map(&:to_i)
        distance = dx.abs + dy.abs
        dead_agents << {
          position: [dx, dy],
          distance: distance,
          adjacent: distance == 1
        }
      end
    end
    
    # Check for threats (living agents)
    threats = []
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      if cell_info && cell_info['type'] == 'living_agent'
        threats << {
          direction: dir,
          energy: cell_info['energy'] || 10
        }
      end
    end
    
    # Find empty adjacent directions
    empty_directions = []
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      empty_directions << dir if cell_info.nil? || cell_info['type'] == 'dead_agent'
    end
    
    # Calculate unexplored directions (avoid recently visited)
    unexplored_directions = empty_directions.reject do |dir|
      explored_recently.include?(dir)
    end
    
    action = if my_energy <= 1
               # Critical energy - must rest
               { action: 'rest' }
             elsif dead_agents.any? { |d| d[:adjacent] }
               # Adjacent corpse - eat it!
               corpse = dead_agents.find { |d| d[:adjacent] }
               dx, dy = corpse[:position]
               target_dir = direction_offsets.find { |_, (ddx, ddy)| ddx == dx && ddy == dy }&.first
               { action: 'move', target: target_dir }
             elsif !threats.empty? && !empty_directions.empty?
               # Avoid threats - scavengers don't fight
               escape_dir = empty_directions.max_by do |dir|
                 dx, dy = direction_offsets[dir]
                 threats.sum { |t| 
                   tdx, tdy = direction_offsets[t[:direction]]
                   (tdx - dx).abs + (tdy - dy).abs
                 }
               end
               { action: 'move', target: escape_dir }
             elsif !dead_agents.empty? && !empty_directions.empty?
               # Move towards nearest corpse
               nearest_corpse = dead_agents.min_by { |d| d[:distance] }
               dx, dy = nearest_corpse[:position]
               
               # Calculate best direction
               best_dir = empty_directions.min_by do |dir|
                 ddx, ddy = direction_offsets[dir]
                 new_dx = dx - ddx
                 new_dy = dy - ddy
                 new_dx.abs + new_dy.abs
               end
               
               { action: 'move', target: best_dir }
             elsif my_energy >= 14 && (tick - last_meal_tick) < 10
               # Recently fed and high energy - replicate
               { action: 'replicate' }
             elsif !unexplored_directions.empty? && rand < 0.8
               # Explore new areas
               { action: 'move', target: unexplored_directions.sample }
             elsif !empty_directions.empty? && rand < 0.7
               # Keep searching
               { action: 'move', target: empty_directions.sample }
             else
               # Rest and wait
               { action: 'rest' }
             end
    
    # Update memory
    new_explored = explored_recently.last(2) # Keep last 2 moves
    new_explored << action[:target] if action[:action] == 'move'
    
    ate_corpse = action[:action] == 'move' && dead_agents.any? { |d| d[:adjacent] }
    
    new_memory = {
      'known_corpses' => dead_agents.map { |d| d[:position] },
      'last_meal_tick' => ate_corpse ? tick : last_meal_tick,
      'explored_recently' => new_explored
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