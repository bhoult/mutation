# Architecture Overview

System design and core components of the Mutation Simulator.

## High-Level Design

The Mutation Simulator follows a modular, process-based architecture designed for scalability, safety, and true parallelism:

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   CLI Interface │    │  Configuration  │    │   Log Manager   │
│                 │    │     System      │    │                 │
└─────────┬───────┘    └─────────┬───────┘    └─────────┬───────┘
          │                      │                      │
          └──────────────────────┼──────────────────────┘
                                 │
                   ┌─────────────▼───────────────┐
                   │        Simulator            │
                   │   (Orchestration Layer)     │
                   └─────────────┬───────────────┘
                                 │
        ┌────────────────────────┼────────────────────────┐
        │                       │                        │
┌───────▼───────┐    ┌──────────▼──────────┐    ┌────────▼────────┐
│  World System │    │   Agent Manager     │    │ Mutation Engine │
│               │    │                     │    │                 │
│ - 2D Grid     │    │ - Process Spawning  │    │ - Code Mutation │
│ - Energy      │    │ - IPC Management    │    │ - Genetic Pool  │
│ - Physics     │    │ - Health Monitoring │    │ - Evolution     │
└───────────────┘    └─────────────────────┘    └─────────────────┘
                                 │
                    ┌────────────▼────────────┐
                    │    Agent Processes      │
                    │                         │
                    │  ┌─────┐ ┌─────┐ ┌─────┐│
                    │  │Ag 1 │ │Ag 2 │ │...  ││
                    │  └─────┘ └─────┘ └─────┘│
                    └─────────────────────────┘
```

## Core Components

### 1. Simulator (lib/mutation/simulator.rb)

The central orchestrator that manages the simulation lifecycle:

- **Tick Management**: Controls simulation timing and progression
- **Lifecycle Coordination**: Manages start, pause, reset, and termination
- **Display Integration**: Coordinates with visual/curses display
- **Statistics Tracking**: Monitors simulation metrics and performance
- **Auto-reset Logic**: Handles extinction events and simulation restarts

**Key Responsibilities:**
- Main simulation loop execution
- Agent lifecycle coordination
- World state synchronization
- Performance monitoring

### 2. World System

#### WorldImpl (lib/mutation/world_impl.rb)
The core world implementation providing:
- **2D Grid Management**: Spatial representation and agent positioning
- **Energy Physics**: Energy decay, transfer, and conservation
- **Vision System**: 5-square radius observation for agents
- **Action Processing**: Coordinated execution of agent actions
- **Collision Detection**: Movement validation and boundary checking

#### World (lib/mutation/world.rb)
Thin wrapper around WorldImpl for backward compatibility.

### 3. Agent Management

#### AgentProcess (lib/mutation/agent_process.rb)
Individual agent process management:
- **Process Spawning**: Creates isolated Ruby processes using `Open3.popen3`
- **IPC Protocol**: JSON-based bidirectional communication
- **Health Monitoring**: Process status tracking and cleanup
- **Timeout Handling**: Response timeout management
- **Memory Persistence**: Agent state storage between ticks

#### AgentManager (lib/mutation/agent_manager.rb)
Collection orchestration:
- **Process Pool Management**: Coordinates multiple agent processes
- **Parallel Execution**: True parallelism using separate OS processes
- **Resource Allocation**: Memory and CPU resource management
- **Cleanup Operations**: Orphaned process detection and removal

### 4. Mutation Engine

#### ProcessMutationEngine (lib/mutation/process_mutation_engine.rb)
Genetic evolution system:
- **Code Mutation**: Modifies agent scripts for evolution
- **Lineage Tracking**: Parent-child relationship management
- **Mutation Types**: Numeric, threshold, operator, and personality mutations
- **Script Generation**: Creates mutated offspring code

#### GeneticPool (lib/mutation/genetic_pool.rb)
Persistent evolution storage:
- **Script Storage**: Maintains successful agent code variants
- **Fingerprinting**: SHA256-based genetic identification
- **Selection Algorithms**: Weighted random selection for reproduction
- **Cleanup Management**: Removes unsuccessful lineages

### 5. Configuration System

#### Configuration (lib/mutation/configuration.rb)
Centralized configuration management:
- **YAML Loading**: Hierarchical configuration from files
- **CLI Override**: Command-line parameter integration
- **Default Values**: Sensible defaults for all parameters
- **Validation**: Configuration parameter validation
- **Nested Structure**: Support for structured configuration sections

### 6. Logging and Monitoring

#### SimulationLogManager (lib/mutation/simulation_log_manager.rb)
Simulation-specific logging:
- **Log Organization**: Separate folders per simulation
- **Rotation Management**: Automatic cleanup of old logs
- **Agent Log Limits**: Per-simulation agent log rotation
- **Path Management**: Dynamic log file path resolution

#### Logger (lib/mutation/logger.rb)
Specialized logging system:
- **Colorized Output**: Color-coded log levels
- **Performance Logging**: Detailed timing and metrics
- **Debug Support**: Verbose debugging capabilities

### 7. Display System

#### CursesDisplay (lib/mutation/curses_display.rb)
Real-time visual interface:
- **Grid Visualization**: Live agent and world state display
- **Interactive Controls**: WASD navigation, pause/resume
- **Status Information**: Real-time simulation metrics
- **Viewport Management**: Efficient rendering for large worlds
- **Color Coding**: Energy-based agent visualization

## Process Architecture

### Agent Process Isolation

Each agent runs as a completely separate OS process:

```
┌─────────────────┐    stdin/stdout    ┌─────────────────┐
│   World/Manager │◄──────JSON──────►│  Agent Process  │
│                 │     messages      │                 │
│  - Coordinates  │                   │  - Autonomous   │
│  - Validates    │                   │  - Isolated     │
│  - Applies      │                   │  - Ruby Script  │
└─────────────────┘                   └─────────────────┘
```

**Benefits:**
- **True Parallelism**: Bypasses Ruby's Global Interpreter Lock (GIL)
- **Fault Isolation**: Agent crashes don't affect simulation
- **Security**: Process-level sandboxing
- **Resource Control**: Individual process resource limits

### Communication Protocol

JSON-based message exchange:

**World → Agent (Input):**
```json
{
  "tick": 42,
  "agent_id": "agent_1_1234567890",
  "position": [5, 3],
  "energy": 10,
  "vision": {"0,-1": {"type": "living_agent", "energy": 5}},
  "memory": {"previous_action": "move"}
}
```

**Agent → World (Output):**
```json
{
  "action": "move",
  "target": "north",
  "memory": {"last_move": "north", "food_seen": false}
}
```

## Data Flow

### 1. Simulation Tick Cycle

```
┌─────────────────┐
│  Start Tick     │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Gather Agent    │
│ World State     │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Send State to   │
│ All Agents      │
│ (Parallel)      │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Collect Agent   │
│ Responses       │
│ (Timeout)       │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Validate and    │
│ Apply Actions   │
│ (Sequential)    │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Update World    │
│ Physics         │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Check End       │
│ Conditions      │
└─────────────────┘
```

### 2. Agent Lifecycle

```
┌─────────────────┐
│ Spawn Process   │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Initial         │
│ Handshake       │
└─────────┬───────┘
          │
┌─────────▼───────┐
│ Game Loop       │
│ (Message Wait)  │
└─────────┬───────┘
          │
      ┌───▼────┐
      │ Action │
      │ Decision│
      └───┬────┘
          │
┌─────────▼───────┐
│ Send Response   │
└─────────┬───────┘
          │
    ┌─────▼─────┐
    │ Continue? │
    └─────┬─────┘
          │
     ┌────▼────┐
     │ Death/  │
     │ Cleanup │
     └─────────┘
```

## Scalability Features

### Parallel Processing
- **Agent Decisions**: Parallel evaluation of agent actions
- **Process Pool**: Configurable number of concurrent agent processes
- **Load Balancing**: Automatic distribution of computational load
- **Resource Limits**: Per-agent memory and CPU constraints

### Memory Management
- **Log Rotation**: Automatic cleanup of old simulation logs
- **Agent Memory**: Persistent but bounded agent memory storage
- **Genetic Pool**: Efficient storage of successful genetic variants
- **Process Cleanup**: Automatic detection and removal of orphaned processes

### Performance Optimization
- **Sparse Initialization**: Only populate needed grid cells
- **Efficient Vision**: Optimized neighbor calculation algorithms
- **Batch Operations**: Group similar operations for efficiency
- **Lazy Loading**: Load resources only when needed

## Security Considerations

### Process Isolation
- Each agent runs in separate OS process
- No shared memory between agents
- Process-level resource limits
- Automatic cleanup of dead processes

### Input Validation
- JSON message validation
- Action parameter sanitization
- Energy conservation checks
- Position boundary validation

### Safe Code Execution
- Configurable safe mode for agent code
- Timeout handling for unresponsive agents
- Resource usage monitoring
- Process termination controls

---

**[← Back to Documentation](../README.md#documentation)**