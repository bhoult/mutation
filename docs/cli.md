# Command Line Usage

Complete reference for all command line options and examples.

## Commands Overview

The Mutation Simulator provides several commands for different use cases:

- `start` - Run a standard simulation
- `interactive` - Step-by-step interactive mode
- `visual` - Visual simulation mode (alias for `start` with visual enabled)
- `benchmark` - Performance testing

## Start Command

The primary command for running simulations.

### Basic Usage

```bash
# Run with default settings (visual mode, auto-sized world)
./bin/mutation start

# Run non-visual simulation
./bin/mutation start --visual false
```

### World Size Options

```bash
# Square grid (20x20)
./bin/mutation start --size 20

# Rectangular grid (30x15)
./bin/mutation start --width 30 --height 15

# Large world for performance testing
./bin/mutation start --size 100
```

### Energy and Timing

```bash
# Custom initial energy
./bin/mutation start --energy 25

# Custom simulation speed (delay between ticks)
./bin/mutation start --delay 0.1

# Time-limited simulation
./bin/mutation start --ticks 5000
```

### Multiple Simulations

```bash
# Run 10 simulations in sequence
./bin/mutation start --simulations 10

# Combine with other options
./bin/mutation start --simulations 5 --size 30 --ticks 1000
```

### Custom Agents

```bash
# Use custom agent
./bin/mutation start --agents my_agent.rb

# Use multiple agent types
./bin/mutation start --agents agent1.rb agent2.rb agent3.rb

# Custom agents with specific world
./bin/mutation start --agents smart_agent.rb --size 50
```

### Performance Options

```bash
# Enable parallel processing
./bin/mutation start --parallel

# Specify processor count
./bin/mutation start --parallel --processors 4

# Safe mode (disable for performance)
./bin/mutation start --safe false
```

### Configuration

```bash
# Use custom configuration file
./bin/mutation start --config my_config.yml

# Verbose output for debugging
./bin/mutation start --verbose
```

## Complete Options Reference

### Start Command Options

| Option | Alias | Type | Description | Example |
|--------|-------|------|-------------|---------|
| `--size` | `-s` | Number | World size for square grid | `--size 30` |
| `--width` | `-w` | Number | World width for rectangular grid | `--width 40` |
| `--height` | `-h` | Number | World height for rectangular grid | `--height 20` |
| `--energy` | `-e` | Number | Initial energy for agents | `--energy 15` |
| `--delay` | `-d` | Number | Delay between ticks (seconds) | `--delay 0.05` |
| `--ticks` | `-t` | Number | Maximum ticks to run | `--ticks 1000` |
| `--simulations` | `-n` | Number | Number of simulations to run | `--simulations 5` |
| `--visual` | `-V` | Boolean | Enable/disable visual mode | `--visual false` |
| `--config` | `-c` | String | Configuration file path | `--config custom.yml` |
| `--verbose` | `-v` | Boolean | Verbose output | `--verbose` |
| `--safe` | | Boolean | Enable safe mode | `--safe false` |
| `--parallel` | `-p` | Boolean | Enable parallel processing | `--parallel` |
| `--processors` | | Number | Number of processors to use | `--processors 8` |
| `--agents` | | Array | Custom agent executable paths | `--agents agent1.rb agent2.rb` |

## Interactive Command

Step-by-step control over the simulation.

```bash
# Start interactive mode
./bin/mutation interactive

# Interactive with custom world
./bin/mutation interactive --size 25

# Interactive with custom agents
./bin/mutation interactive --agents my_agent.rb
```

### Interactive Commands

Once in interactive mode, use these commands:

| Command | Description | Example |
|---------|-------------|---------|
| `step` or `step N` | Run N steps (default: 1) | `step 10` |
| `status` | Show current simulation status | `status` |
| `report` | Show detailed report | `report` |
| `grid` | Show 2D grid visualization | `grid` |
| `pause` | Pause the simulation | `pause` |
| `resume` | Resume the simulation | `resume` |
| `reset` | Reset the simulation | `reset` |
| `help` | Show help | `help` |
| `quit` or `exit` | Exit interactive mode | `quit` |

## Benchmark Command

Performance testing and statistics.

```bash
# Basic benchmark
./bin/mutation benchmark

# Custom benchmark parameters
./bin/mutation benchmark --size 30 --generations 20 --runs 5
```

### Benchmark Options

| Option | Type | Description | Default |
|--------|------|-------------|---------|
| `--size` | Number | World size for benchmarks | 20 |
| `--generations` | Number | Generations to run | 10 |
| `--runs` | Number | Number of benchmark runs | 3 |

## Example Workflows

### Development and Testing

```bash
# Quick test with small world
./bin/mutation start --size 10 --ticks 100

# Debug with verbose output
./bin/mutation start --verbose --size 15

# Test custom agent
./bin/mutation start --agents my_agent.rb --size 20 --ticks 500
```

### Performance Analysis

```bash
# Large world performance test
./bin/mutation start --size 100 --parallel --processors 4

# Multiple simulations for statistics
./bin/mutation start --simulations 10 --size 30

# Benchmark different configurations
./bin/mutation benchmark --size 50 --generations 15 --runs 3
```

### Research and Experimentation

```bash
# Long-running evolution study
./bin/mutation start --size 50 --ticks 10000

# Compare different agent strategies
./bin/mutation start --agents strategy1.rb strategy2.rb --simulations 5

# Custom energy dynamics
./bin/mutation start --energy 30 --size 40 --ticks 2000
```

### Visual Exploration

```bash
# Large visual world
./bin/mutation start --size 60

# Slow motion for observation
./bin/mutation start --delay 0.2

# Interactive exploration
./bin/mutation interactive --size 30
```

## Tips and Best Practices

### Performance Optimization

1. **Use parallel processing** for worlds with many agents:
   ```bash
   ./bin/mutation start --parallel --processors 4
   ```

2. **Disable safe mode** for maximum performance:
   ```bash
   ./bin/mutation start --safe false
   ```

3. **Adjust world size** based on your system:
   - Small systems: `--size 20-30`
   - Medium systems: `--size 30-50`
   - Large systems: `--size 50-100+`

### Visual Mode Tips

1. **Auto-sizing**: Let the simulator fit your terminal:
   ```bash
   ./bin/mutation start  # No size specified
   ```

2. **Large worlds**: Use WASD to navigate:
   ```bash
   ./bin/mutation start --size 100
   ```

3. **Observation**: Use pause/resume for detailed analysis:
   - Press `Space` to pause
   - Use interactive mode for step-by-step control

### Development Workflow

1. **Start with small worlds** for quick iteration:
   ```bash
   ./bin/mutation start --size 15 --ticks 200
   ```

2. **Use interactive mode** for debugging:
   ```bash
   ./bin/mutation interactive --agents my_agent.rb
   ```

3. **Test with multiple simulations** for reliability:
   ```bash
   ./bin/mutation start --simulations 5 --agents my_agent.rb
   ```

## Error Handling

### Common Issues and Solutions

**Agent not found:**
```bash
# Ensure agent file exists and is executable
chmod +x my_agent.rb
./bin/mutation start --agents ./my_agent.rb
```

**Configuration errors:**
```bash
# Test configuration file
./bin/mutation start --config my_config.yml --verbose
```

**Performance issues:**
```bash
# Reduce world size or enable parallel processing
./bin/mutation start --size 20 --parallel
```

**Visual mode issues:**
```bash
# Ensure curses library is available
# Use non-visual mode as fallback
./bin/mutation start --visual false
```

---

**[← Back to Documentation](../README.md#documentation)**