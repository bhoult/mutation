# 🧬 Mutation Simulator

A Ruby-based evolutionary simulation where agents with self-modifying code compete, evolve, and adapt through natural selection.

## Overview

This project implements a digital ecosystem where simple agents defined by executable Ruby code interact, mutate, and evolve over time. The simulation is inspired by principles of evolutionary biology and artificial life.

### Key Features

- **Self-Modifying Code**: Agents are defined by Ruby code that can mutate and evolve
- **Natural Selection**: Agents compete for survival based on energy and fitness
- **Generational Evolution**: Successful traits propagate through generations
- **Process-Based Agents**: Each agent runs as a separate OS process for true isolation
- **Configurable Environment**: Highly customizable simulation parameters
- **Safe Execution**: Built-in safety measures for code execution
- **Rich Logging**: Detailed logging with colorized output
- **CLI Interface**: Command-line tools for running simulations
- **Interactive Mode**: Step-by-step simulation control
- **Visual Mode**: Curses-based real-time visualization
- **Parallel Processing**: Multi-processor agent processing for better performance

## Quick Start

### Installation

```bash
# Clone the repository
git clone <repository-url>
cd mutation

# Install dependencies
bundle install

# Make the executable file runnable
chmod +x bin/mutation
```

### Running a Simulation

```bash
# Basic simulation
./bin/mutation start

# Interactive mode
./bin/mutation interactive

# Custom parameters
./bin/mutation start --size 30 --energy 15 --delay 0.1

# Run for specific number of ticks
./bin/mutation start --ticks 1000

# Enable parallel processing with custom processor count
./bin/mutation start --parallel --processors 8

# Visual mode (curses-based display)
./bin/mutation visual

# Visual mode with custom size
./bin/mutation visual --width 20 --height 10 --delay 0.05

# Process-based agents (each agent runs in separate OS process)
./bin/mutation process --width 20 --height 20

# Show configuration
./bin/mutation config
```

### Using Rake Tasks

```bash
# Run tests
rake test

# Run simulation
rake simulate

# Run benchmark
rake benchmark

# Start console
rake console
```

## Project Structure

```
mutation/
├── lib/
│   ├── mutation.rb              # Main module
│   └── mutation/
│       ├── agent.rb             # In-memory agent class
│       ├── agent_process.rb     # Process-based agent class
│       ├── agent_manager.rb     # Process agent orchestrator
│       ├── cli.rb               # Command-line interface
│       ├── configuration.rb     # Configuration management
│       ├── genetic_pool.rb      # Persistent agent script storage
│       ├── logger.rb            # Logging system
│       ├── mutation_engine.rb   # In-memory mutation logic
│       ├── process_mutation_engine.rb # Process-based mutations
│       ├── process_world.rb     # Process-based world
│       ├── simulator.rb         # Simulation orchestrator
│       ├── version.rb           # Version information
│       └── world.rb             # In-memory world/environment
├── spec/                        # Test files
├── config/                      # Configuration files
├── bin/                         # Executable files
├── examples/
│   └── agents/                  # Example agent scripts
├── Gemfile                      # Dependencies
├── Rakefile                     # Rake tasks
└── README.md                    # This file
```

## How It Works

### Agent Systems

The simulator supports two agent execution models:

#### In-Memory Agents (Traditional)
- Agents run within the main Ruby process
- Code compiled and executed in sandboxed context
- Fast execution with lower overhead
- Limited by Ruby's GIL for parallelism

#### Process-Based Agents (Advanced)
- Each agent runs as a separate OS process
- True parallelism bypassing Ruby's GIL
- Enhanced isolation and security
- Communication via JSON over stdin/stdout pipes
- Persistent memory storage in `/tmp/agents/`
- Higher overhead but better for complex behaviors

### Agent Behavior

Each agent contains:
- **Energy**: Life force that decreases over time
- **Code**: Ruby code defining behavior (or executable path for process agents)
- **Behavior**: Compiled Proc (in-memory) or external process (process-based)
- **Generation**: Evolutionary lineage
- **Memory**: Persistent state between turns (process-based agents)

Agents can perform these actions:
- `:attack` - Attack neighbors for energy
- `:rest` - Gain energy by resting
- `:replicate` - Create mutated offspring
- `:die` - End existence

### Environment

The world is a 2D grid where:
- Agents observe all 8 neighboring positions (Moore neighborhood)
- Each position contains either an agent or empty space
- Actions affect energy levels and grid positions
- Empty spaces can be filled by replication
- Energy decays each tick (world-controlled)
- Grid supports both square and rectangular dimensions

### Mutation

When agents replicate, their code mutates through:
- **Numeric mutations**: Change threshold values
- **Probability mutations**: Modify randomness
- **Operator mutations**: Change comparison operators
- **Threshold mutations**: Alter decision boundaries

### Evolution

The simulation supports:
- **Extinction events**: When all agents die
- **Automatic reseeding**: New generations from survivors
- **Fitness tracking**: Energy × generation scoring
- **Lineage tracking**: Parent-child relationships

## Configuration

Configuration is managed through YAML files and command-line options:

```yaml
# config/mutation.yml
world_size: 20
initial_energy: 10
energy_decay: 1
attack_damage: 3
mutation_rate: 0.5
simulation_delay: 0.2
safe_mode: true
parallel_agents: false
processor_count: null
log_level: info
```

## API Usage

```ruby
require 'mutation'

# Configure the simulation
Mutation.configure do |config|
  config.world_size = 30
  config.initial_energy = 15
  config.mutation_rate = 0.3
  config.parallel_agents = true
  config.processor_count = 8  # Use 8 processors
end

# Create and run simulation
simulator = Mutation::Simulator.new
simulator.start

# Step-by-step control
simulator.step
simulator.pause
simulator.resume
simulator.stop

# Get statistics
puts simulator.detailed_report
```

## Examples

### Basic Simulation

```ruby
# Create a simple simulation
simulator = Mutation::Simulator.new(world_size: 10)
simulator.run_for_ticks(100)
```

### Custom Agent Code

```ruby
# Create agent with custom behavior
custom_code = <<~RUBY
  Proc.new do |env|
    if env[:neighbor_energy] > 8
      :attack
    elsif env[:tick] % 5 == 0
      :replicate
    else
      :rest
    end
  end
RUBY

agent = Mutation::Agent.new(code_str: custom_code)
```

### Interactive Session

```ruby
# Start interactive mode
simulator = Mutation::Simulator.new
simulator.start

# In another context, control the simulation
simulator.pause
puts simulator.current_status
simulator.resume
```

## Process-Based Agent Architecture

### How Process Agents Work

Each process-based agent runs as an independent Ruby process:

1. **Process Spawning**: AgentManager creates processes using `Open3.popen3`
2. **Communication Protocol**: JSON messages exchanged via stdin/stdout
3. **State Management**: Agents maintain memory in `/tmp/agents/{agent_id}/`
4. **Process Monitoring**: Health checks using `Process.getpgid`
5. **Graceful Shutdown**: TERM signal followed by KILL if needed

### Agent Communication Protocol

```json
// Input from World to Agent
{
  "tick": 42,
  "agent_id": "agent_1_1234567890", 
  "position": [5, 3],
  "energy": 10,
  "world_size": [20, 20],
  "neighbors": {
    "north": {"energy": 5, "agent_id": "agent_2_..."},
    "south": {"energy": 0, "agent_id": null},
    // ... other directions
  },
  "generation": 3,
  "timeout_ms": 1000,
  "memory": {}
}

// Output from Agent to World
{
  "action": "attack",
  "target": "north", 
  "memory": {"turns_played": 10, "last_action": "rest"}
}
```

### Genetic Pool System

Process-based agents evolve through a persistent genetic pool:

- **Storage**: Scripts saved in `/tmp/genetic_pool/`
- **Metadata**: Fingerprints track lineage and mutations
- **Selection**: Random selection weighted by recency
- **Persistence**: Survives simulation restarts

### Writing Custom Process Agents

Create executable Ruby scripts that follow the agent protocol:

```ruby
#!/usr/bin/env ruby
require 'json'

while input = $stdin.gets
  world_state = JSON.parse(input)
  
  # Agent logic here
  action = { action: 'rest' }
  
  puts JSON.generate(action)
  $stdout.flush
end
```

## Agent Protocol Reference

### Agent Actions

Agents can perform exactly four actions:

| Action | Description | Energy Cost | Requirements |
|--------|-------------|-------------|--------------|
| `attack` | Attack a neighbor for energy | 1.2 units | Valid target direction |
| `rest` | Gain energy by resting | 0.2 units | None |
| `replicate` | Create mutated offspring | 0.2 + replication_cost | Sufficient energy, empty adjacent space |
| `die` | Voluntarily end existence | 0 units | None |

### Input Format (World → Agent)

#### In-Memory Agents
Agents receive an environment hash:

```ruby
{
  neighbor_energy: 12,              # Maximum energy among neighbors
  neighbors: [0, 5, 3, 0, 0, 8, 2, 0],  # Array of 8 neighbor energies
  position: [5, 10],               # Current [x, y] position
  world_size: [20, 20],            # World [width, height]
  tick: 42                         # Current simulation tick
}
```

#### Process-Based Agents
Agents receive a JSON object via stdin:

```json
{
  "tick": 42,
  "agent_id": "agent_1_1234567890",
  "position": [5, 10],
  "energy": 15,
  "world_size": [20, 20],
  "neighbors": {
    "north_west": {"energy": 10, "agent_id": "agent_2_..."},
    "north": {"energy": 0, "agent_id": null},
    "north_east": {"energy": 5, "agent_id": "agent_3_..."},
    "west": {"energy": 3, "agent_id": "agent_4_..."},
    "east": {"energy": 0, "agent_id": null},
    "south_west": {"energy": 8, "agent_id": "agent_5_..."},
    "south": {"energy": 0, "agent_id": null},
    "south_east": {"energy": 12, "agent_id": "agent_6_..."}
  },
  "generation": 5,
  "timeout_ms": 1000,
  "memory": {
    "turns_played": 10,
    "last_action": "rest"
  }
}
```

### Output Format (Agent → World)

#### In-Memory Agents
Return a symbol:

```ruby
:attack    # Attack highest energy neighbor
:rest      # Rest to gain energy
:replicate # Create offspring
:die       # End existence
```

#### Process-Based Agents
Return JSON via stdout:

```json
// Attack action
{
  "action": "attack",
  "target": "north_east"  // Required for attack
}

// Rest action
{
  "action": "rest"
}

// Replicate action
{
  "action": "replicate"
}

// Die action
{
  "action": "die"
}

// With memory (optional)
{
  "action": "rest",
  "memory": {
    "turns_played": 11,
    "energy_history": [15, 14, 13, 12, 13]
  }
}
```

### Neighbor Directions

The 8 valid directions for attacks (Moore neighborhood):

```
north_west   north   north_east
     \        |        /
      \       |       /
west ---   agent   --- east
      /       |       \
     /        |        \
south_west   south   south_east
```

### Energy Dynamics

All actions have energy implications:

- **Base action cost**: 0.2 units (process agents only)
- **Attack**: Costs 1.0 extra, gains `attack_energy_gain`
- **Rest**: Gains `rest_energy_gain`
- **Replicate**: Costs `replication_cost`
- **Die**: No cost
- **Passive decay**: All agents lose `energy_decay` per tick

### Memory Persistence

Process agents can maintain state between turns:

```ruby
# Load memory
memory = world_state['memory'] || {}

# Update memory
memory['turns_played'] = (memory['turns_played'] || 0) + 1
memory['attack_count'] = (memory['attack_count'] || 0) + 1

# Return with action
action = {
  'action' => 'attack',
  'target' => 'north',
  'memory' => memory
}
```

### Error Handling

- Invalid actions default to `rest`
- Timeout triggers default action
- JSON parse errors trigger default action
- Process crashes are handled gracefully

### Example Agent Implementation

```ruby
#!/usr/bin/env ruby
require 'json'

while input = $stdin.gets
  world_state = JSON.parse(input)
  
  my_energy = world_state['energy']
  neighbors = world_state['neighbors']
  memory = world_state['memory'] || {}
  
  # Find best target
  best_target = neighbors.max_by { |dir, info| info['energy'] }
  target_dir, target_info = best_target
  
  # Decision logic
  action = if my_energy <= 2
    { 'action' => 'die' }
  elsif my_energy >= 8 && neighbors.values.any? { |n| n['energy'] == 0 }
    { 'action' => 'replicate' }
  elsif target_info['energy'] >= 5
    { 'action' => 'attack', 'target' => target_dir }
  else
    { 'action' => 'rest' }
  end
  
  # Update memory
  memory['decisions'] = (memory['decisions'] || 0) + 1
  action['memory'] = memory
  
  puts JSON.generate(action)
  $stdout.flush
end
```

## Parallel Processing

The simulator includes experimental parallel processing support for agent decisions:

- **Agent Parallelization**: Process agent decisions using multiple threads
- **Configurable**: Control processor count and enable/disable parallel processing  
- **Safe Execution**: Actions are applied sequentially to prevent race conditions

### Performance Notes

**Important**: Due to Ruby's Global Interpreter Lock (GIL), parallel processing may not provide performance benefits for CPU-bound agent computations. However, it may be useful for:

- **I/O-bound operations**: File logging, network operations
- **Process-based agents**: True parallelism when using separate OS processes
- **Future extensions**: External computation libraries
- **Experimentation**: Testing different parallelization strategies

### Usage

```ruby
# Enable parallel processing
Mutation.configure do |config|
  config.parallel_agents = true
  config.processor_count = 4  # Use 4 processors
end

# Or via CLI
./bin/mutation start --parallel --processors 4
```

## Safety Features

- **Safe Mode**: Restricts dangerous operations
- **Code Validation**: Prevents malicious code execution
- **Error Handling**: Graceful handling of invalid mutations
- **Timeout Protection**: Prevents infinite loops
- **Resource Limits**: Controls memory and CPU usage

## Testing

```bash
# Run all tests
rake test

# Run specific test files
rspec spec/agent_spec.rb

# Run with coverage
COVERAGE=true rspec
```

## Contributing

1. Fork the repository
2. Create a feature branch
3. Add tests for new functionality
4. Ensure all tests pass
5. Submit a pull request

## Extensions

Potential enhancements:
- **2D World**: Add spatial movement
- **Communication**: Agent-to-agent messaging
- **Memory**: Persistent agent state
- **Visualization**: Real-time graphics
- **Metrics**: Advanced analytics
- **Networking**: Distributed simulation

## License

This project is open source. See LICENSE file for details.

## Acknowledgments

Inspired by:
- Evolutionary computation research
- Artificial life studies
- Complex adaptive systems
- Digital evolution experiments 