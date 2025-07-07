# Agent System

Complete guide to understanding and creating agents for the Mutation Simulator.

## Overview

Agents are autonomous entities that compete for survival in the simulation world. Each agent:
- Runs as a separate OS process for true parallelism
- Receives world state information via JSON messages
- Makes decisions and returns actions via JSON responses
- Can observe the world in a 5-square radius (11x11 grid)
- Evolves through mutation and natural selection

## Agent Lifecycle

### 1. Process Creation
```ruby
# Each agent is spawned as a separate Ruby process
Open3.popen3("ruby", agent_script_path)
```

### 2. Communication Loop
```ruby
# World sends JSON input to agent's stdin
# Agent processes input and responds via stdout
while (input = $stdin.gets)
  message = JSON.parse(input.strip)
  # ... process message and decide action ...
  response = { action: 'move', target: 'north', memory: {} }
  puts JSON.generate(response)
  $stdout.flush
end
```

### 3. Termination
```ruby
# Agent receives death command
exit(0) if message['command'] == 'die'
```

## Communication Protocol

### Input Message Format

The world sends agents a JSON message each tick with complete state information:

```json
{
  "tick": 42,
  "agent_id": "agent_1_1234567890",
  "position": [5, 3],
  "energy": 10,
  "world_size": [20, 20],
  "vision": {
    "0,-1": {"type": "living_agent", "energy": 5},
    "1,0": {"type": "dead_agent"},
    "-1,-1": {"type": "boundary"},
    "3,2": {"type": "living_agent", "energy": 8}
  },
  "generation": 3,
  "timeout_ms": 1000,
  "memory": {"previous_action": "move", "target_found": true}
}
```

#### Input Fields

| Field | Type | Description |
|-------|------|-------------|
| `tick` | Integer | Current simulation tick |
| `agent_id` | String | Unique agent identifier |
| `position` | Array[x, y] | Agent's current grid position |
| `energy` | Integer | Agent's current energy level |
| `world_size` | Array[width, height] | World dimensions |
| `vision` | Object | Observable cells within 5-square radius |
| `generation` | Integer | Agent's generation number |
| `timeout_ms` | Integer | Response timeout in milliseconds |
| `memory` | Object | Agent's persistent memory from previous tick |

#### Vision System

The `vision` object contains relative coordinates as keys and cell information as values:

- **Coordinate format**: `"dx,dy"` where dx and dy range from -5 to 5
- **Agent's position**: (0,0) is not included in vision data
- **Cell types**:
  - `"living_agent"`: Contains `energy` field
  - `"dead_agent"`: Can be consumed for +10 energy
  - `"boundary"`: Position is outside world boundaries
  - **Empty cells**: Not included to reduce message size

**Vision Examples:**
```json
{
  "0,-1": {"type": "living_agent", "energy": 5},  // North: living agent with 5 energy
  "1,1": {"type": "dead_agent"},                  // Southeast: dead agent (food)
  "-2,0": {"type": "boundary"},                   // West edge: world boundary
  "3,-2": {"type": "living_agent", "energy": 12}  // Distant agent in vision range
}
```

### Output Message Format

Agents must respond with a JSON message containing their chosen action:

```json
{
  "action": "move",
  "target": "north",
  "memory": {"last_move": "north", "food_seen": false}
}
```

#### Output Fields

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `action` | String | Yes | Action to perform |
| `target` | String | Sometimes | Direction for move/attack actions |
| `memory` | Object | Yes | Persistent data for next tick |

## Available Actions

### 1. Attack
Damage a neighboring agent and gain energy.

```json
{
  "action": "attack",
  "target": "north",
  "memory": {}
}
```

- **Target**: Required direction (north, south, east, west, north_east, north_west, south_east, south_west)
- **Energy cost**: 1.0 (base_cost 0.2 + attack_cost 1.0)
- **Damage dealt**: 3 energy
- **Energy gained**: 1 energy (from successful attack)
- **Range**: Adjacent cells only

### 2. Rest
Recover energy by resting.

```json
{
  "action": "rest",
  "memory": {}
}
```

- **Energy cost**: 0.2 (base_cost only)
- **Energy gained**: 1 energy
- **Use case**: When energy is low or no other actions are beneficial

### 3. Replicate
Create a mutated offspring agent.

```json
{
  "action": "replicate",
  "memory": {}
}
```

- **Energy cost**: 5 energy
- **Requirements**: Sufficient energy and empty adjacent cell
- **Result**: Creates mutated copy in random adjacent empty space
- **Mutation**: Offspring code is automatically mutated

### 4. Move
Move to an adjacent cell, potentially consuming dead agents.

```json
{
  "action": "move",
  "target": "south_east",
  "memory": {}
}
```

- **Target**: Required direction
- **Energy cost**: 0.2 (base_cost only)
- **Special**: Moving onto dead agent grants +10 energy
- **Blocked**: Cannot move onto living agents

### 5. Die
Voluntarily terminate the agent.

```json
{
  "action": "die",
  "memory": {}
}
```

- **Energy cost**: None
- **Result**: Immediate agent termination
- **Use case**: Altruistic behavior or no hope of survival

## Memory System

Agents can maintain persistent state between ticks using the memory system:

```ruby
# Load memory from previous tick
memory = message['memory'] || {}

# Update memory based on current situation
memory['last_action'] = 'move'
memory['enemies_seen'] = vision.count { |_, cell| cell['type'] == 'living_agent' }

# Return memory in response
{ action: 'rest', memory: memory }
```

**Memory features:**
- Persisted as JSON between ticks
- Arbitrary key-value structure
- Useful for tracking history, strategies, and goals
- Automatically handled by the simulator

## Example Agents

### 1. Minimal Agent

The simplest possible agent:

```ruby
#!/usr/bin/env ruby
require 'json'

while (input = $stdin.gets)
  message = JSON.parse(input.strip)
  exit(0) if message['command'] == 'die'
  
  # Simple energy-based behavior
  my_energy = message['energy'] || 0
  
  action = if my_energy < 3
    { action: 'rest' }
  elsif my_energy > 15
    { action: 'replicate' }
  else
    { action: 'move', target: ['north', 'south', 'east', 'west'].sample }
  end
  
  puts JSON.generate(action.merge(memory: {}))
  $stdout.flush
end
```

### 2. Food-Seeking Agent

An agent that actively hunts for dead agents:

```ruby
#!/usr/bin/env ruby
require 'json'

while (input = $stdin.gets)
  message = JSON.parse(input.strip)
  exit(0) if message['command'] == 'die'
  
  vision = message['vision'] || {}
  my_energy = message['energy'] || 0
  memory = message['memory'] || {}
  
  # Find dead agents (food) in vision
  food_positions = []
  vision.each do |pos, cell|
    if cell['type'] == 'dead_agent'
      dx, dy = pos.split(',').map(&:to_i)
      food_positions << [dx, dy, dx.abs + dy.abs] # Include distance
    end
  end
  
  action = if my_energy < 3
    { action: 'rest' }
  elsif !food_positions.empty?
    # Move toward closest food
    closest_food = food_positions.min_by { |_, _, distance| distance }
    dx, dy = closest_food[0], closest_food[1]
    
    # Determine direction to move
    direction = if dx > 0 && dy > 0
      'south_east'
    elsif dx > 0 && dy < 0
      'north_east'
    elsif dx > 0
      'east'
    elsif dx < 0 && dy > 0
      'south_west'
    elsif dx < 0 && dy < 0
      'north_west'
    elsif dx < 0
      'west'
    elsif dy > 0
      'south'
    else
      'north'
    end
    
    { action: 'move', target: direction }
  elsif my_energy > 12
    { action: 'replicate' }
  else
    # Random exploration
    { action: 'move', target: ['north', 'south', 'east', 'west'].sample }
  end
  
  # Update memory
  memory['food_count'] = food_positions.size
  memory['last_energy'] = my_energy
  
  puts JSON.generate(action.merge(memory: memory))
  $stdout.flush
end
```

### 3. Aggressive Agent

An agent that prioritizes attacking other agents:

```ruby
#!/usr/bin/env ruby
require 'json'

while (input = $stdin.gets)
  message = JSON.parse(input.strip)
  exit(0) if message['command'] == 'die'
  
  vision = message['vision'] || {}
  my_energy = message['energy'] || 0
  memory = message['memory'] || {}
  
  # Find adjacent living agents to attack
  directions = {
    'north' => [0, -1],
    'south' => [0, 1],
    'east' => [1, 0],
    'west' => [-1, 0],
    'north_east' => [1, -1],
    'north_west' => [-1, -1],
    'south_east' => [1, 1],
    'south_west' => [-1, 1]
  }
  
  # Find attackable targets
  targets = []
  directions.each do |dir, (dx, dy)|
    key = "#{dx},#{dy}"
    if vision[key] && vision[key]['type'] == 'living_agent'
      target_energy = vision[key]['energy'] || 0
      targets << [dir, target_energy]
    end
  end
  
  action = if my_energy < 4
    { action: 'rest' }
  elsif !targets.empty?
    # Attack weakest adjacent target
    target_dir = targets.min_by { |_, energy| energy }[0]
    { action: 'attack', target: target_dir }
  elsif my_energy > 15
    { action: 'replicate' }
  else
    # Move toward enemies
    enemies = vision.select { |_, cell| cell['type'] == 'living_agent' }
    if enemies.any?
      # Move toward closest enemy
      pos, _ = enemies.min_by do |pos, _|
        dx, dy = pos.split(',').map(&:to_i)
        dx.abs + dy.abs
      end
      dx, dy = pos.split(',').map(&:to_i)
      
      direction = case [dx <=> 0, dy <=> 0]
                  when [1, 1] then 'south_east'
                  when [1, -1] then 'north_east'
                  when [1, 0] then 'east'
                  when [-1, 1] then 'south_west'
                  when [-1, -1] then 'north_west'
                  when [-1, 0] then 'west'
                  when [0, 1] then 'south'
                  when [0, -1] then 'north'
                  end
      
      { action: 'move', target: direction }
    else
      # Random exploration
      { action: 'move', target: directions.keys.sample }
    end
  end
  
  # Track aggression in memory
  memory['attacks_made'] = (memory['attacks_made'] || 0) + (action[:action] == 'attack' ? 1 : 0)
  memory['enemies_seen'] = vision.count { |_, cell| cell['type'] == 'living_agent' }
  
  puts JSON.generate(action.merge(memory: memory))
  $stdout.flush
end
```

## Best Practices

### 1. Error Handling

Always include error handling for robust agents:

```ruby
begin
  message = JSON.parse(input.strip)
  # ... agent logic ...
rescue StandardError => e
  # Fallback to rest on any error
  action = { action: 'rest', memory: {} }
  puts JSON.generate(action)
  $stdout.flush
end
```

### 2. Input Validation

Validate input data before use:

```ruby
my_energy = message['energy'] || 0
vision = message['vision'] || {}
memory = message['memory'] || {}

# Ensure energy is positive
my_energy = [my_energy, 0].max
```

### 3. Memory Management

Keep memory size reasonable to avoid performance issues:

```ruby
# Limit memory history
memory['history'] = (memory['history'] || []).last(10)

# Clean up old data
memory.delete('temporary_data') if memory['temporary_data']
```

### 4. Direction Validation

Ensure movement directions are valid:

```ruby
VALID_DIRECTIONS = %w[north south east west north_east north_west south_east south_west]

def safe_move_direction(preferred)
  return preferred if VALID_DIRECTIONS.include?(preferred)
  VALID_DIRECTIONS.sample
end
```

### 5. Vision Processing

Efficiently process vision data:

```ruby
# Group by type for easier processing
agents = vision.select { |_, cell| cell['type'] == 'living_agent' }
food = vision.select { |_, cell| cell['type'] == 'dead_agent' }
boundaries = vision.select { |_, cell| cell['type'] == 'boundary' }

# Find closest targets
def closest_target(targets)
  targets.min_by do |pos, _|
    dx, dy = pos.split(',').map(&:to_i)
    dx.abs + dy.abs  # Manhattan distance
  end
end
```

## Testing Your Agent

### 1. Basic Testing

```bash
# Test with small world for quick iteration
./bin/mutation start --agents your_agent.rb --size 15 --ticks 200

# Test with multiple agents for competition
./bin/mutation start --agents your_agent.rb default_agent.rb --size 20
```

### 2. Performance Testing

```bash
# Large world performance test
./bin/mutation start --agents your_agent.rb --size 50 --ticks 1000

# Multiple simulations for reliability
./bin/mutation start --agents your_agent.rb --simulations 5
```

### 3. Interactive Debugging

```bash
# Step-by-step debugging
./bin/mutation interactive --agents your_agent.rb --size 10

# Use status and grid commands to observe behavior
```

## Agent Evolution

Agents automatically evolve through the mutation system:

1. **Parent Selection**: Agents that survive and replicate pass on their code
2. **Mutation**: Offspring code is automatically mutated by the mutation engine
3. **Natural Selection**: Better-adapted agents survive longer and replicate more
4. **Genetic Pool**: Successful agent codes are stored for future simulations

The mutation engine can modify:
- Numeric values (energy thresholds, probabilities)
- Comparison operators (>, <, >=, <=)
- Boolean logic (and, or, not)
- Strategy parameters

---

**[← Back to Documentation](../README.md#documentation)**