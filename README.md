# Mutation Simulator

A Ruby-based evolutionary simulation where agents with self-modifying code compete, evolve, and adapt through natural selection in a 2D grid world environment.

**[📺 View Visual Mode Demo (100×100 Grid)](docs/images/visual-demo.md)**

## 🚀 Quick Start

### 1. Install and Run Your First Simulation

```bash
# Install dependencies
bundle install

# Run a visual simulation with default parameters
./bin/mutation visual
```

This starts a visual simulation with:
- Auto-sized world to fit your terminal
- 10% initial population coverage
- 6 different agent types competing
- Real-time visualization

### 2. Understanding the Visual Interface

The curses display shows a live view of the simulation:

```
     0         10        20        30   (X-axis labels)
  0  * *   O     *                      
  1    *     x          *   O           
  2  *   *       *                      
  3      x    *     *                    
  4  O       *   *     x                
     (World Grid)                       
------------------------------------------
| LOG: Agent spawned at (2,3)     | T:42/256 G:1           |
| LOG: Attack at (5,1)            | Agents:23 M:4          |
| LOG: Agent died at (4,2)        | AvgE:7.2 FPS:30        |
| LOG: Replication at (1,4)       | ---Top Agents---       |
|                                 | 1. active_explore..: 8 |
|                                 | 2. cautious_econ..: 6  |
|                                 | 3. reproductive_c..: 5 |
|                                 | View:(0,0)/170,25      |
------------------------------------------
WASD:Scroll | SPACE:Pause | R:Reset View | Q:Quit
```

**Grid Symbols:**
- `*` = Original agent (color indicates energy level)
- `O` = Mutated agent (color indicates energy level)
  - 🟢 Green = High energy (8+ energy)
  - 🟡 Yellow = Medium energy (4-7 energy)
  - 🔴 Red = Low energy (1-3 energy)
- `x` = Dead agent corpse (can be eaten for +10 energy)
- ` ` = Empty space

**Status Panel Shows:**
- `T:` Current tick / Total ticks across all simulations
- `G:` Generation count
- `Agents:` Living agent count (M: mutations)
- `AvgE:` Average energy of all agents
- `FPS:` Display refresh rate
- `Top Agents:` Most populous agent types (truncated names)
- `View:` Camera position / Max camera position (for large worlds)

### 3. Monitor Agent Performance

While the simulation runs, track agent success rates:

```bash
# In another terminal, watch performance stats
tail -f logs/agent_performance_stats.log
```

This shows win rates across all simulations:
```
1. active_explorer_agent:
   Participated: 35 | Won: 26 | Win Rate: 74.29%

2. reproductive_colonizer:
   Participated: 35 | Won: 5 | Win Rate: 14.29%
```

### 4. Find Successful Mutations

Check for evolved agents that survived:

```bash
# List successful mutations
ls -la agents/*/

# Example output:
agents/active_explorer_agent_mutations/
├── active_explorer_agent_18e6ed0b_survival_150_gen_4_20250707_124051.rb
└── active_explorer_agent_982e99f3_survival_244_gen_2_20250707_121904.rb
```

These files contain mutated code that survived longest in simulations.

### 5. Customize Your Simulation

```bash
# Larger world with more initial energy
./bin/mutation visual --size 50 --energy 20

# Specific dimensions
./bin/mutation visual --width 100 --height 30

# Faster simulation
./bin/mutation visual --delay 0.01

# Run specific agents only
./bin/mutation visual --agents aggressive_hunter.rb,cautious_economist.rb
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

This project is licensed under the GNU General Public License v3.0.

## 🤝 Contributing

Contributions are welcome! Please contact bhoult@gmail.com for details.

---

**[📚 Full Documentation](docs/)** | **[🐛 Report Issues](https://github.com/bhoult/mutation/issues)** | **[💬 Contact](mailto:bhoult@gmail.com)**