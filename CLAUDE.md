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
- **lib/mutation/agent.rb**: Agent behavior, code compilation, and safety validation
- **lib/mutation/simulator.rb**: Main simulation loop and lifecycle management
- **lib/mutation/world.rb**: 2D grid environment and agent interactions
- **lib/mutation/mutation_engine.rb**: Code mutation algorithms
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

Agents contain Ruby code that returns one of four actions:
- `:attack` - Attack neighbors for energy
- `:rest` - Gain energy by resting
- `:replicate` - Create mutated offspring
- `:die` - End existence

### Code Safety
- **Safe mode**: Restricts dangerous operations (system calls, file access)
- **Code validation**: Prevents malicious patterns
- **Fallback behavior**: Agents get default behavior if compilation fails
- **Error handling**: Graceful degradation for invalid mutations

## Mutation System

The MutationEngine modifies agent code through:
- Numeric mutations (threshold values)
- Probability mutations (randomness factors)
- Operator mutations (comparison operators)
- Threshold mutations (decision boundaries)

## Parallel Processing

The simulator supports experimental parallel processing for agent decisions:
- **Important**: Due to Ruby's GIL, CPU-bound operations may not benefit
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
- `@` - Very high energy (15+)
- `#` - High energy (10-14) 
- `o` - Medium energy (5-9)
- `·` - Low energy (1-4)
- `.` - Empty space

### Controls
- **WASD**: Move camera around large worlds
- **Space**: Pause/resume simulation
- **R**: Reset camera to origin (0,0)
- **Q/Esc**: Quit simulation

## Development Notes

- The project uses Ruby ~> 3.0
- All agent code execution is sandboxed for safety
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