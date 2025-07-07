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
- **lib/mutation/agent.rb**: Individual agent process management with stdin/stdout IPC
- **lib/mutation/world_impl.rb**: Core 2D grid environment where agents interact
- **lib/mutation/world.rb**: Thin wrapper around WorldImpl for backward compatibility
- **lib/mutation/agent_manager.rb**: Orchestrates collection of agent processes
- **lib/mutation/mutated_agent_manager.rb**: Manages agent mutations and genetic diversity
- **lib/mutation/genetic_pool.rb**: Persistent storage of evolved agent scripts
- **lib/mutation/simulator.rb**: Main simulation loop and lifecycle management
- **lib/mutation/configuration.rb**: Configuration loading and validation
- **lib/mutation/agent_performance_tracker.rb**: Tracks agent win/loss statistics across simulations
- **lib/mutation/curses_display.rb**: Real-time visual display system
- **lib/mutation/simulation_log_manager.rb**: Manages simulation-specific logging
- **lib/mutation/survivor_logger.rb**: Logs and tracks evolutionary survivors
- **lib/mutation/cli.rb**: Command-line interface and argument parsing
- **lib/mutation/logger.rb**: Specialized logging with colorized output

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
- **World settings**: Size for square grid, or width/height for rectangular grid, initial energy, coverage
- **Energy system**: Decay, initial energy ranges (20-60), attack damage, replication cost  
- **Agent management**: Maximum agent count, lifespan limits (1000 cycles), process timeouts
- **Mutation parameters**: Rate, probability, variation ranges for different mutation types
- **Simulation settings**: Delay, max ticks, auto-reset, status logging frequency
- **Parallel processing**: Enable/disable, processor count, threading thresholds
- **Visual display**: Layout settings, color thresholds, FPS, panel sizing
- **Agent behavior**: Personality ranges, energy thresholds, replication parameters
- **Logging**: Log levels, file rotation, survivor tracking
- **Genetic pool**: Fingerprint length, survival thresholds, sample sizes
- **File paths**: Agent directories, memory storage paths, default executables

## Agent Behavior System

All agents run as separate OS processes for enhanced isolation and true parallelism. Agents contain Ruby code that returns one of five actions:
- `:attack` - Attack neighbors for energy
- `:rest` - Gain energy by resting
- `:replicate` - Create mutated offspring
- `:move` - Move to adjacent position (can eat dead agents for +10 energy)
- `:die` - End existence

### Agent Lifespan System
- **Maximum Lifespan**: Agents automatically die after 1000 cycles to prevent immortal agents
- **Age Tracking**: Each agent tracks its age in cycles from birth
- **Death Types**: Agents can die from energy depletion, old age, or voluntary termination
- **Automatic Victory**: If an agent is the last survivor, it automatically wins the simulation

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
     "vision": {
       "0,-1": {"type": "living_agent", "energy": 5},
       "1,0": {"type": "dead_agent"},
       "-1,-1": {"type": "boundary"},
       "3,2": {"type": "living_agent", "energy": 8},
       // ... positions within 5-square radius
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

### Vision System
Agents receive vision data showing a 5-square radius around their position (11x11 grid):
- Vision data uses relative coordinates as keys: `"dx,dy"` where dx and dy range from -5 to 5
- The agent's own position (0,0) is not included in the vision data
- Vision cell types:
  - `"living_agent"`: Contains `energy` field showing the agent's current energy
  - `"dead_agent"`: A dead agent that can be consumed by moving onto it
  - `"boundary"`: Position is outside the world boundaries
  - Empty cells are not included in the vision data to reduce message size
- Example: `"3,-2"` represents a position 3 cells east and 2 cells north of the agent

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

## Agent Ecosystem

### Current Agent Types
The system includes several pre-built agent types with different strategies:

- **active_explorer_agent**: Balanced exploration and survival strategy, currently leading with ~74% win rate
- **aggressive_hunter**: Focuses on attacking other agents for energy
- **cautious_economist**: Conservative energy management with defensive tactics
- **defensive_fortress**: Prioritizes survival and defensive positioning
- **opportunistic_scavenger**: Seeks dead agents for food and avoids confrontation
- **reproductive_colonizer**: Emphasizes rapid replication and territory expansion

### Agent Evolution System
- **Mutation Storage**: Successful mutations stored in `agents/{type}_mutations/` directories
- **Genetic Pool**: Temporary mutations managed in `agents/temp_mutation_agents/`
- **Lineage Tracking**: Fingerprint-based system tracks successful evolutionary lines
- **Performance Tracking**: Win rates tracked across all simulations in `logs/agent_performance_stats.log`

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

## Logging and Performance Tracking

### Logs Directory Structure
The `logs/` directory contains comprehensive simulation data:

- **agent_performance_stats.log**: Cross-simulation performance statistics tracking agent win rates
- **simulation_YYYYMMDD_HHMMSS_xxx/**: Individual simulation folders containing:
  - **world_events.log**: Detailed world events (moves, attacks, replications, deaths)
  - **agent_agent_ID_TIMESTAMP.log**: Individual agent interaction logs (input/output/timing)
  - **survivors.log**: Successful survivor code snippets (when generated)
  - **curses_debug.log**: Debug output from visual display mode (when used)

### Agent Performance Tracking
- **Cross-Simulation Statistics**: Tracks participation, wins, and win percentages for each agent type
- **Base Name Normalization**: Consolidates statistics by agent base names (ignoring mutation suffixes)
- **Automatic Updates**: Performance stats updated at end of each simulation
- **Sorted Ranking**: Agents ranked by win percentage for competitive analysis

### Visual Display Enhancements
- **Top Agent Display**: Shows the 3 most populous agent types with counts in status panel
- **Population Tracking**: Real-time agent population counts by type
- **Enhanced Status Panel**: Expanded status display with agent statistics and simulation progress

## Development Notes

- The project uses Ruby ~> 3.0
- All agents run as separate OS processes for enhanced safety and isolation
- Simulation state is tracked through comprehensive statistics
- The world operates on a tick-based system with configurable delays
- Agents can observe all 8 neighboring positions (Moore neighborhood) in the 2D grid
- Evolution occurs through survival of the fittest and code mutation
- 2D grid supports both square (size parameter) and rectangular (width/height) configurations
- Agent environment provides vision data in a 5-square radius (11x11 grid centered on agent)
- Survivor codes are automatically logged to track evolutionary progress
- Visual mode requires a curses-compatible terminal
- Initial world coverage is configurable (default 10%) for realistic population dynamics
- Curses display includes stability improvements for long-running simulations
- Process-based agents provide true parallelism bypassing Ruby's GIL
- Agent lifespan limited to 1000 cycles to ensure simulation completion
- Comprehensive logging system tracks all agent interactions and world events