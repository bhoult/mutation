#!/usr/bin/env ruby
# frozen_string_literal: true

# Agent that actively explores and seeks food (uses 5-square vision radius)

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
    
    # Find empty adjacent directions for movement
    empty_directions = []
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      # Direction is empty if not in vision (empty space) or if it's a dead agent
      empty_directions << dir if cell_info.nil? || cell_info['type'] == 'dead_agent'
    end
    
    # Look for dead agents in entire 5-square vision for food
    dead_agent_positions = []
    vision.each do |relative_pos, cell_info|
      if cell_info['type'] == 'dead_agent'
        dx, dy = relative_pos.split(',').map(&:to_i)
        # Include all dead agents within 5-square radius
        dead_agent_positions << [dx, dy]
      end
    end
    
    # Calculate energy percentage
    max_energy = 10
    energy_percent = (my_energy.to_f / max_energy) * 100
    
    action = if my_energy <= 2
               # Critical energy - must rest
               { action: 'rest' }
             elsif energy_percent < 50 && !dead_agent_positions.empty?
               # Under 50% energy - prioritize finding food
               # Find closest dead agent using Manhattan distance
               closest_dead = dead_agent_positions.min_by { |dx, dy| dx.abs + dy.abs }
               dx, dy = closest_dead
               
               # Determine best direction to move towards the dead agent
               target_direction = nil
               if dx.abs > dy.abs
                 # Move horizontally first
                 target_direction = dx > 0 ? 'east' : 'west'
               elsif dy != 0
                 # Move vertically
                 target_direction = dy > 0 ? 'south' : 'north'
               end
               
               # If primary direction blocked, try diagonal
               if target_direction
                 dx_target, dy_target = direction_offsets[target_direction] || [0, 0]
                 target_key = "#{dx_target},#{dy_target}"
                 target_cell = vision[target_key]
                 
                 if target_cell && target_cell['type'] == 'living_agent'
                   # Primary direction blocked, try diagonal movement
                   diagonal_options = []
                   if dx > 0 && dy > 0
                     diagonal_options << 'south_east'
                   elsif dx > 0 && dy < 0
                     diagonal_options << 'north_east'
                   elsif dx < 0 && dy > 0
                     diagonal_options << 'south_west'
                   elsif dx < 0 && dy < 0
                     diagonal_options << 'north_west'
                   end
                   
                   # Try diagonal options
                   valid_diagonal = diagonal_options.find do |dir|
                     ddx, ddy = direction_offsets[dir]
                     dkey = "#{ddx},#{ddy}"
                     dcell = vision[dkey]
                     dcell.nil? || dcell['type'] == 'dead_agent'
                   end
                   
                   target_direction = valid_diagonal if valid_diagonal
                 end
               end
               
               # Execute movement towards food
               if target_direction && empty_directions.include?(target_direction)
                 { action: 'move', target: target_direction }
               elsif !empty_directions.empty?
                 # Can't move directly towards food, pick best available direction
                 best_dir = empty_directions.min_by do |dir|
                   ddx, ddy = direction_offsets[dir]
                   # Calculate new distance to food after this move
                   new_dx = dx - ddx
                   new_dy = dy - ddy
                   new_dx.abs + new_dy.abs
                 end
                 { action: 'move', target: best_dir }
               else
                 { action: 'rest' }
               end
             elsif !dead_agent_positions.empty?
               # Over 50% energy but food is visible - still go for it
               closest_dead = dead_agent_positions.min_by { |dx, dy| dx.abs + dy.abs }
               dx, dy = closest_dead
               
               # Simple direction calculation
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
               
               if target_direction && empty_directions.include?(target_direction)
                 { action: 'move', target: target_direction }
               elsif !empty_directions.empty?
                 { action: 'move', target: empty_directions.sample }
               else
                 { action: 'rest' }
               end
             elsif !empty_directions.empty? && rand < 0.7
               # No food visible - explore by moving randomly 70% of the time
               { action: 'move', target: empty_directions.sample }
             elsif my_energy >= 15 && rand < 0.3
               # High energy - 30% chance to replicate
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