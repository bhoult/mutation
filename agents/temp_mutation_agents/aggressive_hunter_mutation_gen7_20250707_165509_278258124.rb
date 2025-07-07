#!/usr/bin/env ruby
# frozen_string_literal: true

# Aggressive Hunter - Actively hunts other agents for energy
# Strategy: Prioritizes attacking living agents over all other actions
# Seeks out the weakest nearby agents and attacks them for energy gain

require 'json'

begin
  while (input = $stdin.gets)
    message = JSON.parse(input.strip)
    
    # Handle death command from world
    exit(0) if message['command'] == 'die'
    
    # Get world state info
    vision = message['vision'] || {}
    my_energy = message['energy'] || 0
    
    # Find all living agents in vision
    living_agents = []
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
    
    # Look for adjacent living agents (immediate neighbors only for attack)
    adjacent_agents = []
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      if cell_info && cell_info['type'] == 'living_agent'
        adjacent_agents << {
          direction: dir,
          energy: cell_info['energy'] || 10,
          position: [dx, dy]
        }
      end
    end
    
    # Find empty adjacent directions for movement
    empty_directions = []
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      empty_directions << dir if cell_info.nil? || cell_info['type'] == 'dead_agent'
    end
    
    # Scan wider area for living agents to hunt
    vision.each do |relative_pos, cell_info|
      if cell_info['type'] == 'living_agent'
        dx, dy = relative_pos.split(',').map(&:to_i)
        distance = dx.abs + dy.abs
        living_agents << {
          position: [dx, dy],
          energy: cell_info['energy'] || 10,
          distance: distance
        }
      end
    end
    
    action = if my_energy <= 1
               # Critical energy - must rest
               { action: 'rest' }
             elsif !adjacent_agents.empty? && my_energy >= 3
               # Attack the weakest adjacent agent
               weakest = adjacent_agents.min_by { |a| a[:energy] }
               { action: 'attack', target: weakest[:direction] }
             elsif !living_agents.empty? && !empty_directions.empty? && my_energy >= 5
               # Hunt: Move towards nearest living agent
               nearest = living_agents.min_by { |a| a[:distance] }
               dx, dy = nearest[:position]
               
               # Calculate best direction to approach target
               best_dir = empty_directions.min_by do |dir|
                 ddx, ddy = direction_offsets[dir]
                 new_dx = dx - ddx
                 new_dy = dy - ddy
                 new_dx.abs + new_dy.abs
               end
               
               { action: 'move', target: best_dir }
             elsif my_energy >= 12 && rand < 0.4
               # High energy - sometimes replicate to create hunting pack
               { action: 'replicate' }
             elsif !empty_directions.empty? && rand < 0.7 # MUTATION: was: elsif !empty_directions.empty? && rand < 0.6
               # Patrol: Move randomly looking for prey
               { action: 'move', target: empty_directions.sample }
             else
               # Rest to build energy for hunting
               { action: 'rest' }
             end
    
    response = action.merge(memory: {})
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