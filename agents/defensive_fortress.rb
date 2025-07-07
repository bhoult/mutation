#!/usr/bin/env ruby
# frozen_string_literal: true

# Defensive Fortress - Focuses on survival through defensive positioning
# Strategy: Avoids threats, maintains high energy, and only attacks when cornered
# Seeks safe positions and builds energy reserves before replicating

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
    
    # Track threats over time
    threat_count = memory['threat_count'] || 0
    last_position = memory['last_position'] || []
    
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
    
    # Analyze threats (adjacent living agents)
    threats = []
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      if cell_info && cell_info['type'] == 'living_agent'
        threats << {
          direction: dir,
          energy: cell_info['energy'] || 10,
          position: [dx, dy]
        }
      end
    end
    
    # Find safe directions (no threats nearby)
    safe_directions = []
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      
      # Check if direction is empty
      if cell_info.nil? || cell_info['type'] == 'dead_agent'
        # Check if moving there would put us next to threats
        is_safe = true
        direction_offsets.each do |_, (ddx, ddy)|
          check_x = dx + ddx
          check_y = dy + ddy
          check_key = "#{check_x},#{check_y}"
          check_cell = vision[check_key]
          if check_cell && check_cell['type'] == 'living_agent'
            is_safe = false
            break
          end
        end
        safe_directions << dir if is_safe
      end
    end
    
    # Find any empty directions if no safe ones exist
    empty_directions = []
    direction_offsets.each do |dir, (dx, dy)|
      relative_key = "#{dx},#{dy}"
      cell_info = vision[relative_key]
      empty_directions << dir if cell_info.nil? || cell_info['type'] == 'dead_agent'
    end
    
    # Update threat memory
    new_threat_count = threats.size
    
    action = if my_energy <= 2
               # Critical energy - must rest
               { action: 'rest' }
             elsif threats.size >= 2 && !threats.empty?
               # Surrounded - attack the weakest threat
               weakest = threats.min_by { |t| t[:energy] }
               { action: 'attack', target: weakest[:direction] }
             elsif threats.size == 1 && my_energy >= 8
               # Single threat with good energy - fight back
               { action: 'attack', target: threats.first[:direction] }
             elsif !safe_directions.empty?
               # Move to safety
               { action: 'move', target: safe_directions.sample }
             elsif !empty_directions.empty? && !threats.empty?
               # Escape from threats
               # Choose direction away from threats
               best_escape = empty_directions.max_by do |dir|
                 dx, dy = direction_offsets[dir]
                 threats.sum { |t| (t[:position][0] - dx).abs + (t[:position][1] - dy).abs }
               end
               { action: 'move', target: best_escape }
             elsif my_energy >= 18 && safe_directions.size >= 3
               # Very high energy and safe position - replicate
               { action: 'replicate' }
             elsif my_energy < 8
               # Build energy reserves
               { action: 'rest' }
             elsif !empty_directions.empty? && rand < 0.3
               # Occasionally reposition when safe
               { action: 'move', target: empty_directions.sample }
             else
               # Default: rest and build energy
               { action: 'rest' }
             end
    
    # Update memory
    new_memory = {
      'threat_count' => new_threat_count,
      'last_position' => message['position'] || []
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