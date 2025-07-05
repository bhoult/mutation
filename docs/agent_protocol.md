# Agent Communication Protocol

## Overview
Agents run as isolated processes and communicate with the simulation through JSON messages via stdin/stdout.

## Input Protocol (World State)
Each turn, agents receive world state information via stdin as a JSON object:

```json
{
  "tick": 42,
  "agent_id": "abc123",
  "position": [5, 3],
  "energy": 8,
  "world_size": [20, 15],
  "neighbors": {
    "north_west": {"energy": 0, "agent_id": null},
    "north": {"energy": 5, "agent_id": "def456"},
    "north_east": {"energy": 0, "agent_id": null},
    "west": {"energy": 0, "agent_id": null},
    "east": {"energy": 12, "agent_id": "ghi789"},
    "south_west": {"energy": 0, "agent_id": null},
    "south": {"energy": 0, "agent_id": null},
    "south_east": {"energy": 3, "agent_id": "jkl012"}
  },
  "generation": 15,
  "timeout_ms": 1000
}
```

### Field Descriptions
- `tick`: Current simulation tick number
- `agent_id`: Unique identifier for this agent
- `position`: Agent's [x, y] coordinates in the world
- `energy`: Agent's current energy level
- `world_size`: World dimensions as [width, height]
- `neighbors`: Energy and IDs of 8 surrounding positions (0 energy = empty)
- `generation`: Current generation number
- `timeout_ms`: Maximum time agent has to respond

## Output Protocol (Agent Action)
Agents must respond with their desired action via stdout as a JSON object:

```json
{
  "action": "attack",
  "target": "north",
  "message": "Taking energy from weak neighbor"
}
```

### Valid Actions
- `"attack"`: Attack a neighboring agent
  - Requires `target` field specifying direction: `"north"`, `"south"`, `"east"`, `"west"`, `"north_east"`, `"north_west"`, `"south_east"`, `"south_west"`
- `"rest"`: Rest to gain energy
- `"replicate"`: Create offspring agent  
- `"die"`: Voluntarily die

### Optional Fields
- `target`: Direction for attack action
- `message`: Debug message (logged but not used in simulation)

## Error Handling
- Invalid JSON: Agent gets default "rest" action
- Missing action field: Agent gets default "rest" action  
- Invalid action: Agent gets default "rest" action
- Timeout: Agent gets default "rest" action and warning
- Process crash: Agent is removed from simulation

## Example Agent (Ruby)
```ruby
#!/usr/bin/env ruby
require 'json'

while input = $stdin.gets
  data = JSON.parse(input)
  
  # Simple strategy: attack if neighbors have high energy, otherwise rest
  best_target = data['neighbors'].max_by { |dir, info| info['energy'] }
  
  if best_target[1]['energy'] > 5
    response = { action: 'attack', target: best_target[0] }
  else
    response = { action: 'rest' }
  end
  
  puts JSON.generate(response)
  $stdout.flush
end
```

## Agent Files
Each agent can write to a single JSON file: `/tmp/agents/{agent_id}.json`
This file persists between turns and can store agent memory/state.

```json
{
  "memory": {
    "enemy_positions": [[5,3], [10,7]],
    "strategy": "aggressive",
    "turn_count": 42
  }
}
```