# 🧬 Mutation Simulator

A Ruby-based evolutionary simulation where agents with self-modifying code compete, evolve, and adapt through natural selection.

## Overview

This project implements a digital ecosystem where simple agents defined by executable Ruby code interact, mutate, and evolve over time. The simulation is inspired by principles of evolutionary biology and artificial life.

### Key Features

- **Self-Modifying Code**: Agents are defined by Ruby code that can mutate and evolve
- **Natural Selection**: Agents compete for survival based on energy and fitness
- **Generational Evolution**: Successful traits propagate through generations
- **Configurable Environment**: Highly customizable simulation parameters
- **Safe Execution**: Built-in safety measures for code execution
- **Rich Logging**: Detailed logging with colorized output
- **CLI Interface**: Command-line tools for running simulations
- **Interactive Mode**: Step-by-step simulation control
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
│       ├── agent.rb             # Agent class
│       ├── cli.rb               # Command-line interface
│       ├── configuration.rb     # Configuration management
│       ├── logger.rb            # Logging system
│       ├── mutation_engine.rb   # Mutation logic
│       ├── simulator.rb         # Simulation orchestrator
│       ├── version.rb           # Version information
│       └── world.rb             # World/environment
├── spec/                        # Test files
├── config/                      # Configuration files
├── bin/                         # Executable files
├── Gemfile                      # Dependencies
├── Rakefile                     # Rake tasks
└── README.md                    # This file
```

## How It Works

### Agent Behavior

Each agent contains:
- **Energy**: Life force that decreases over time
- **Code**: Ruby code defining behavior
- **Behavior**: Compiled Proc from the code
- **Generation**: Evolutionary lineage

Agents can perform these actions:
- `:attack` - Attack neighbors for energy
- `:rest` - Gain energy by resting
- `:replicate` - Create mutated offspring
- `:die` - End existence

### Environment

The world is a 1D grid where:
- Agents observe neighboring energy levels
- Actions affect energy levels
- Empty spaces can be filled by replication
- Energy decays each tick

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

## Parallel Processing

The simulator includes experimental parallel processing support for agent decisions:

- **Agent Parallelization**: Process agent decisions using multiple threads
- **Configurable**: Control processor count and enable/disable parallel processing  
- **Safe Execution**: Actions are applied sequentially to prevent race conditions

### Performance Notes

**Important**: Due to Ruby's Global Interpreter Lock (GIL), parallel processing may not provide performance benefits for CPU-bound agent computations. However, it may be useful for:

- **I/O-bound operations**: File logging, network operations
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