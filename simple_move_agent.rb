#!/usr/bin/env ruby
# Simple agent that always tries to move north

require 'json'

begin
  while input = $stdin.gets
    message = JSON.parse(input.strip)
    
    # Handle death command from world
    if message['command'] == 'die'
      exit(0)
    end
    
    # Always try to move north
    action = { action: 'move', target: 'north' }
    
    response = action.merge(memory: {})
    puts JSON.generate(response)
    $stdout.flush
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