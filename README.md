# Mutation Simulator

A Ruby-based evolutionary simulation where agents with self-modifying code compete, evolve, and adapt through natural selection in a 2D grid world environment.

![Mutation Simulator Demo](docs/images/demo.gif)

## 🚀 Quick Start

```bash
# Install dependencies
bundle install

# Run a visual simulation with auto-sized grid
./bin/mutation start

# Run with custom world size
./bin/mutation start --size 30
./bin/mutation start --width 20 --height 15

# Run non-visual simulation
./bin/mutation start --visual false

# Interactive mode for step-by-step control
./bin/mutation interactive
```

## 📖 Documentation

### Core Concepts
- **[Architecture Overview](docs/architecture.md)** - System design and core components
- **[Agent System](docs/agents.md)** - How agents work, communication protocol, and examples
- **[World Mechanics](docs/world.md)** - Grid environment, energy system, and evolution
- **[Mutation Engine](docs/mutation.md)** - Genetic evolution and code mutation

### Usage Guides
- **[Command Line Usage](docs/cli.md)** - All command line options and examples
- **[Configuration Guide](docs/configuration.md)** - Complete configuration reference
- **[Visual Mode](docs/visual-mode.md)** - Using the curses-based visual interface

### Development
- **[Agent Development](docs/agent-development.md)** - Creating custom agents
- **[Testing](docs/testing.md)** - Running tests and benchmarks
- **[Contributing](docs/contributing.md)** - Development setup and guidelines

## 🎮 Visual Mode

The simulator features a real-time curses-based visual display:

- **Real-time visualization**: Watch agents as colored characters based on energy levels
- **Interactive controls**: WASD panning, space to pause, R to reset view
- **Status information**: Live display of ticks, generation, agent count, and statistics
- **Auto-sizing**: Automatically fits world to your terminal size

### Visual Legend
- `*` - Living agents (color changes based on energy level)
  - 🟢 Green: High energy (8+)
  - 🟡 Yellow: Medium energy (4-7)  
  - 🔴 Red: Low energy (1-3)
- `x` - Dead agents (red)
- ` ` - Empty space

### Controls
- **WASD**: Pan camera around large worlds
- **Space**: Pause/resume simulation
- **R**: Reset camera to origin (0,0)
- **Q/Esc**: Quit simulation

## 🧬 Agent System

Agents are autonomous entities that:
- Run as separate OS processes for true parallelism
- Receive world state via JSON messages
- Return actions (attack, rest, replicate, move, die)
- Can see in a 5-square radius (11x11 grid)
- Evolve through mutation and natural selection

### Basic Agent Actions
- **Attack**: Deal damage to neighboring agents for energy
- **Rest**: Recover energy 
- **Replicate**: Create mutated offspring (costs 5 energy)
- **Move**: Move to adjacent cells, eat dead agents (+10 energy)
- **Die**: Voluntary termination

## 🏗️ Architecture

The simulator uses a modular, process-based architecture:

- **Agents**: Individual Ruby processes with bidirectional JSON communication
- **World**: 2D grid environment managing agent interactions
- **Simulator**: Orchestrates simulation lifecycle and timing
- **Mutation Engine**: Handles genetic evolution and code mutations
- **Visual Display**: Real-time curses-based interface

## ⚙️ Configuration

Comprehensive YAML-based configuration system:

```yaml
# Basic world setup
world:
  size: 20                    # Square grid size
  width: 30                   # Or rectangular...
  height: 20                  # ...grid dimensions
  initial_coverage: 0.1       # 10% initial population

# Energy and action costs
action_costs:
  replicate:
    cost: 5                   # Energy cost to replicate
  move:
    dead_agent_energy_gain: 10 # Energy from eating dead agents

# Visual display
display:
  visual_mode: true           # Default to visual mode
```

See [Configuration Guide](docs/configuration.md) for complete reference.

## 🧪 Examples

### Minimal Agent
```ruby
#!/usr/bin/env ruby
require 'json'

while (input = $stdin.gets)
  message = JSON.parse(input.strip)
  exit(0) if message['command'] == 'die'
  
  my_energy = message['energy'] || 0
  
  action = if my_energy < 3
    { action: 'rest' }           # Low energy - rest
  elsif my_energy > 15
    { action: 'replicate' }      # High energy - reproduce
  else
    { action: 'move', target: ['north', 'south', 'east', 'west'].sample }
  end
  
  puts JSON.generate(action.merge(memory: {}))
  $stdout.flush
end
```

### Running Custom Simulations
```bash
# Custom world size and energy
./bin/mutation start --size 50 --energy 20

# Multiple simulations for statistics
./bin/mutation start --simulations 5

# Custom agent with time limit
./bin/mutation start --agents my_agent.rb --ticks 1000

# Parallel processing for performance
./bin/mutation start --parallel --processors 4
```

## 📊 Performance

- **True parallelism**: Each agent runs in separate OS process
- **Configurable timing**: Adjustable simulation speed and timeouts
- **Memory efficient**: Agent log rotation and cleanup
- **Scalable**: Supports large worlds with hundreds of agents

## 🔧 Requirements

- Ruby 3.0+
- Curses library (for visual mode)
- YAML support
- Unix-like environment (Linux/macOS)

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please see our [Contributing Guide](docs/contributing.md) for details.

---

**[📚 Full Documentation](docs/)** | **[🐛 Report Issues](https://github.com/user/mutation/issues)** | **[💬 Discussions](https://github.com/user/mutation/discussions)**