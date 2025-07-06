# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Ruby-based evolutionary simulation called "Mutation Simulator" where agents with self-modifying code compete, evolve, and adapt through natural selection. Agents are defined by executable Ruby code that can mutate over time in a 2D grid world environment.

## Core Architecture

### Module Structure
- **Mutation**: Main module that provides global configuration and logging
- **Agent**: Individual entities with executable Ruby code behaviors
- **World**: 2D grid environment where agents interact
- **Simulator**: Orchestrates the simulation lifecycle
- **MutationEngine**: Handles code mutations and evolution
- **Configuration**: YAML-based configuration management
- **Logger**: Specialized logging with colorized output

### Key Components
- **lib/mutation/agent_process.rb**: Manages individual agent OS processes with stdin/stdout IPC
- **lib/mutation/process_world.rb**: 2D grid environment where agents interact
- **lib/mutation/world.rb**: Thin wrapper around ProcessWorld for backward compatibility
- **lib/mutation/agent_manager.rb**: Orchestrates collection of agent processes
- **lib/mutation/process_mutation_engine.rb**: Mutates agent scripts and manages genetic pool
- **lib/mutation/genetic_pool.rb**: Persistent storage of evolved agent scripts
- **lib/mutation/simulator.rb**: Main simulation loop and lifecycle management
- **lib/mutation/configuration.rb**: Configuration loading and validation

## Common Development Commands

### Testing
```bash
# Run all tests
rake test
# or
rspec

# Run specific test file
rspec spec/agent_spec.rb

# Run tests with coverage
COVERAGE=true rspec
```

### Linting
```bash
# Run RuboCop linting
rake lint
# or
rubocop

# Run tests and linting together
rake check
```

### Running Simulations
```bash
# Basic simulation
./bin/mutation start

# Interactive mode
./bin/mutation interactive

# Visual mode (curses display)
./bin/mutation visual

# Visual mode with custom size
./bin/mutation visual --width 20 --height 10 --delay 0.05

# Custom parameters (square grid)
./bin/mutation start --size 30 --energy 15 --delay 0.1

# Rectangular 2D grid
./bin/mutation start --width 10 --height 8 --energy 15

# Parallel processing
./bin/mutation start --parallel --processors 4

# Run via Rake
rake simulate
rake benchmark
```

### Development Tools
```bash
# Start interactive console
rake console

# Show version
rake version
```

## Configuration

Configuration is managed through:
- **config/mutation.yml**: Main configuration file
- **Command-line arguments**: Override config values
- **Programmatic configuration**: Via `Mutation.configure` block

Key configuration areas:
- World settings (size for square grid, or width/height for rectangular grid, initial energy, coverage)
- Energy system (decay, attack damage, replication cost)
- Mutation parameters (rate, probability)
- Simulation settings (delay, max ticks, auto-reset)
- Safety and parallel processing options
- Visual display settings (survivors log file)

## Agent Behavior System

All agents run as separate OS processes for enhanced isolation and true parallelism. Agents contain Ruby code that returns one of five actions:
- `:attack` - Attack neighbors for energy
- `:rest` - Gain energy by resting
- `:replicate` - Create mutated offspring
- `:move` - Move to adjacent position (can eat dead agents for +10 energy)
- `:die` - End existence

### Agent Architecture
- **Process Spawning**: Each agent runs as an independent Ruby process using `Open3.popen3`
- **IPC Protocol**: JSON-based communication over stdin/stdout pipes
- **Process Management**: 
  - Tracks PIDs and monitors process health with `Process.getpgid`
  - Graceful shutdown (TERM signal) followed by force kill (KILL) if needed
  - Automatic cleanup of dead processes
- **Agent Scripts**: Standalone Ruby executables that implement the agent protocol
- **Memory Persistence**: Agents can maintain state across turns via `/tmp/agents/{agent_id}/` directories
- **Timeout Handling**: Each agent action has a configurable timeout (default 500ms)
- **Parallel Processing**: True parallelism using separate OS processes (bypasses Ruby's GIL)

## Mutation System

The ProcessMutationEngine handles script-based mutations:
- **Script Mutation**: Reads parent agent scripts and applies mutations to create offspring
- **Genetic Pool**: Maintains a persistent collection of evolved agent scripts in `/tmp/genetic_pool/`
- **Lineage Tracking**: Uses fingerprints to track parent-child relationships
- **Mutation Types**:
  - Numeric: Varies integer values by ±20% or ±1-2 for small numbers
  - Probability: Adjusts probability thresholds by ±0.1-0.3
  - Threshold: Modifies energy/condition thresholds by ±1-3
  - Operator: Randomly changes comparison operators (10% chance)
  - Personality: Mutates agent behavior ranges and traits

## Parallel Processing

The simulator supports true parallel processing for agent decisions:
- **True parallelism**: Each agent runs in a separate OS process, bypassing Ruby's GIL
- **Safe execution**: Actions applied sequentially to prevent race conditions
- **Configurable**: Control processor count and enable/disable parallel processing

## Testing Architecture

- **RSpec**: Primary testing framework
- **SimpleCov**: Code coverage reporting
- **FactoryBot**: Test data generation
- **Guard**: Automated test running

## Key Dependencies

- **thor**: CLI interface framework
- **colorize**: Colored terminal output
- **parallel**: Multi-threading support
- **yaml**: Configuration parsing
- **logger**: Logging framework

## Visual Display Mode

The simulator includes a curses-based visual display that shows the simulation like a video game:

### Features
- **Real-time visualization**: Agents displayed as colored characters based on energy levels
- **WASD panning**: Navigate around large worlds that exceed screen size  
- **Auto-sizing**: Automatically sizes world to terminal dimensions if no size specified
- **Interactive controls**: Pause/resume, quit, reset camera view
- **Status display**: Shows tick, generation, agent count, and camera position
- **Survivor logging**: Automatically logs unique survivor code to file when simulation ends
- **Sparse initialization**: Starts with only 10% world coverage for realistic population dynamics
- **Stability improvements**: Robust display handling with bounds checking and error recovery

### Visual Legend
- `*` - Living agents (color changes based on energy level)
  - Green: High energy (8+)
  - Yellow: Medium energy (4-7)
  - Red: Low energy (1-3)
- `x` - Dead agents (red)
- ` ` - Empty space (blank)

### Controls
- **WASD**: Move camera around large worlds
- **Space**: Pause/resume simulation
- **R**: Reset camera to origin (0,0)
- **Q/Esc**: Quit simulation

## Process Architecture Details

### Agent Process Lifecycle
1. **Spawning**: AgentManager creates new AgentProcess instances
   - Each agent gets a unique ID and executable path
   - Process spawned with `Open3.popen3` for bidirectional communication
   - Initial handshake verifies process is alive

2. **Communication Protocol**:
   ```json
   // Input (World → Agent)
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
     "memory": {...}
   }
   
   // Output (Agent → World)
   {
     "action": "attack",
     "target": "north",
     "memory": {...}
   }
   ```

3. **Process Monitoring**:
   - Regular health checks using `Process.getpgid(pid)`
   - Automatic cleanup of dead processes
   - Timeout handling for unresponsive agents

4. **Memory Management**:
   - Each agent has a workspace in `/tmp/agents/{agent_id}/`
   - Memory persisted as JSON for state between turns
   - Cleanup on agent death (Note: cleanup_agent_files method needs implementation)

### Genetic Pool System
- **Location**: `/tmp/genetic_pool/`
- **Structure**: Each agent script stored with metadata:
  - Fingerprint (SHA256 hash)
  - Parent fingerprint for lineage
  - Generation number
  - Creation timestamp
- **Selection**: Random selection weighted by recency
- **Persistence**: Survives simulation restarts for continuous evolution

### Performance Considerations
- Process-based agents have higher overhead than in-memory agents
- IPC adds latency but provides true parallelism
- Recommended for complex agent behaviors that benefit from isolation
- Agent process limit of 100 to prevent resource exhaustion

## Agent Command Reference

### Available Actions
All agents can perform exactly five actions:

1. **attack** - Attack a neighboring agent
   - Must specify target direction (north, south, east, west, etc.)
   - Energy dynamics: Attacker gains energy, target loses energy
   
2. **rest** - Restore energy
   - Default action for invalid commands
   - Gains energy based on `rest_energy_gain` config
   
3. **replicate** - Create offspring
   - Requires minimum energy threshold
   - Places mutated offspring in adjacent empty cell
   - Parent pays replication cost
   
4. **move** - Move to adjacent position
   - Must specify target direction (north, south, east, west, etc.)
   - Can move to empty spaces or eat dead agents
   - Eating dead agents provides +10 energy
   - Movement blocked by living agents
   
5. **die** - Voluntary termination
   - Immediately removes agent from world
   - No energy cost

### Direction Constants
Valid target directions for attacks (Moore neighborhood):
- `north`, `south`, `east`, `west`
- `north_east`, `north_west`, `south_east`, `south_west`

### Action Validation
- Invalid actions default to `rest`
- Attack actions require valid direction
- Replicate requires sufficient energy and empty adjacent space
- All actions validated before execution

## Development Notes

- The project uses Ruby ~> 3.0
- All agents run as separate OS processes for enhanced safety and isolation
- Simulation state is tracked through comprehensive statistics
- The world operates on a tick-based system with configurable delays
- Agents can observe all 8 neighboring positions (Moore neighborhood) in the 2D grid
- Evolution occurs through survival of the fittest and code mutation
- 2D grid supports both square (size parameter) and rectangular (width/height) configurations
- Agent environment provides neighbor energy arrays and 2D position coordinates
- Survivor codes are automatically logged to `survivors.log` to track evolutionary progress
- Visual mode requires a curses-compatible terminal
- Initial world coverage is configurable (default 10%) for realistic population dynamics
- Curses display includes stability improvements for long-running simulations
- Process-based agents provide true parallelism bypassing Ruby's GIL