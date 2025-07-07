#!/usr/bin/env ruby
# frozen_string_literal: true

# Agent that actively explores and seeks food (optimized for 2-square vision)

require 'json'

begin
  while (input = $stdin.gets)
    message = JSON.parse(input.strip)
    
    # Handle death command from world
    exit(0) if message['command'] == 'die'
    
    # Get world state info
    vision = message['vision'] || {}
    my_energy = message['energy'] || 0
    
    # Helper method to get adjacent positions for each direction
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
    
    # Find empty directions for movement using vision data
    empty_directions = []
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      # Direction is empty if not in vision (empty space) or if it's a dead agent
      empty_directions << dir if cell_info.nil? || cell_info['type'] == 'dead_agent'
    end
    
    # Look for dead agents in vision for food
    dead_agent_positions = []
    vision.each do |relative_pos, cell_info|
      if cell_info['type'] == 'dead_agent'
        dx, dy = relative_pos.split(',').map(&:to_i)
        dead_agent_positions << [dx, dy]
      end
    end
    
    action = if my_energy <= 3
               # Very low energy - rest to recover
               { action: 'rest' }
             elsif !dead_agent_positions.empty?
               # Found dead agents - move towards closest one for food
               closest_dead = dead_agent_positions.min_by { |dx, dy| dx.abs + dy.abs }
               dx, dy = closest_dead
               
               # Determine direction to move towards the dead agent
               target_direction = case [dx <=> 0, dy <=> 0]
                                 when [1, 1] then 'south_east'
                                 when [1, -1] then 'north_east'
                                 when [1, 0] then 'east'
                                 when [-1, 1] then 'south_west'
                                 when [-1, -1] then 'north_west'
                                 when [-1, 0] then 'west'
                                 when [0, 1] then 'south'
                                 when [0, -1] then 'north'
                                 end
               
               # Check if the move towards food is valid using vision data
               dx_target, dy_target = direction_offsets[target_direction] || [0, 0]
               target_key = "#{dx_target},#{dy_target}"
               target_cell = vision[target_key]
               if target_direction && (target_cell.nil? || target_cell['type'] == 'dead_agent')
                 { action: 'move', target: target_direction }
               elsif !empty_directions.empty?
                 # Can't move towards food directly, try any empty direction
                 { action: 'move', target: empty_directions.sample }
               else
                 { action: 'rest' }
               end
             elsif !empty_directions.empty? && rand < 0.8
               # No food visible - explore by moving randomly 80% of the time
               { action: 'move', target: empty_directions.sample }
             elsif my_energy >= 12 && rand < 0.2
               # High energy - 20% chance to replicate
               { action: 'replicate' }
             else
               # Rest to conserve energy
               { action: 'rest' }
             end
    
    response = action.merge(memory: {})
    puts JSON.generate(response)
    $stdout.flush
  end
rescue StandardError => e
  # Fallback to rest if anything goes wrong
  error_response = { 
    action: 'rest', 
    message: "Error: #{e.message}",
    memory: {}
  }
  puts JSON.generate(error_response)
  $stdout.flush
end