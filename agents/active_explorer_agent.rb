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
    neighbors = message['neighbors'] || {}
    vision = message['vision'] || {}
    my_energy = message['energy'] || 0
    
    # Find empty directions for movement
    directions = %w[north south east west north_east north_west south_east south_west]
    empty_directions = []
    directions.each do |dir|
      neighbor = neighbors[dir]
      empty_directions << dir if neighbor.nil? || neighbor['energy'] == 0 || neighbor['alive'] == false
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
               
               # Check if the move towards food is valid
               neighbor = neighbors[target_direction]
               if target_direction && (neighbor.nil? || neighbor['energy'] == 0 || neighbor['alive'] == false)
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