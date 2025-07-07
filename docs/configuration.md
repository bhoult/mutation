# Configuration Guide

Complete reference for configuring the Mutation Simulator.

## Configuration System

The simulator uses a hierarchical YAML-based configuration system that supports:

- **Default Configuration**: Built-in sensible defaults for all parameters
- **File-Based Config**: YAML configuration files for persistent settings
- **CLI Overrides**: Command-line parameters that override file settings
- **Nested Structure**: Organized into logical sections for clarity

## Configuration Sources

### 1. Default Configuration (Hardcoded)
Built into the application with sensible defaults.

### 2. File Configuration
```bash
# Default config file
config/mutation.yml

# Custom config file
./bin/mutation start --config my_config.yml
```

### 3. Command Line Overrides
```bash
# Override specific settings
./bin/mutation start --size 30 --energy 20 --delay 0.1
```

**Priority Order**: CLI Options → Config File → Defaults

## Complete Configuration Reference

### World Settings

Control the simulation environment:

```yaml
world:
  size: 20                      # Square grid size (20×20)
  width: null                   # Rectangular width (use with height)
  height: null                  # Rectangular height (use with width)
  initial_coverage: 0.1         # Initial population percentage (10%)
```

**Grid Configuration Options:**
- **Square Grid**: Use `size` parameter only
- **Rectangular Grid**: Use both `width` and `height`
- **Auto-sizing**: Omit size parameters to auto-fit terminal

### Energy System

Configure energy dynamics:

```yaml
energy:
  decay: 1                      # Energy lost per tick
  initial_min: 28               # Minimum starting energy
  initial_max: 42               # Maximum starting energy
```

**Energy Flow:**
- All agents lose `decay` energy each tick
- New agents get random energy between `initial_min` and `initial_max`
- Zero energy = death

### Action Costs

Define energy costs and gains for all actions:

```yaml
action_costs:
  base_cost: 0.2                # Energy cost for any action
  
  attack:
    cost: 1.0                   # Additional attack cost
    damage: 3                   # Damage dealt to target
    energy_gain: 1              # Energy gained from attacking
  
  rest:
    energy_gain: 1              # Energy recovered when resting
  
  replicate:
    cost: 5                     # Total replication cost
  
  move:
    dead_agent_energy_gain: 10  # Energy from eating dead agents
```

**Action Energy Calculations:**
- **Attack**: `base_cost + attack.cost` energy spent, `attack.energy_gain` gained
- **Rest**: `base_cost` energy spent, `rest.energy_gain` gained
- **Replicate**: `replicate.cost` total energy spent
- **Move**: `base_cost` energy spent, `+dead_agent_energy_gain` if eating
- **Die**: No energy cost

### Agent Management

Control agent processes and behavior:

```yaml
agent_management:
  max_agent_count: 100          # Maximum concurrent agents
  parallel_processing_threshold: 5   # Min agents for parallel processing
  max_parallel_threads: 8       # Maximum parallel threads
  
  response_timeout: 0.5         # Agent response timeout (seconds)
  process_cleanup_delay: 0.1    # Process cleanup delay
  graceful_death_timeout: 0.5   # Graceful termination timeout
  default_timeout_ms: 1000      # Default agent timeout (milliseconds)
  timeout_ms: 1000              # Agent response timeout (ms)
```

**Process Management:**
- Agents run as separate OS processes
- Timeouts prevent hanging simulations
- Parallel processing improves performance with many agents

### Simulation Control

Configure simulation timing and behavior:

```yaml
simulation:
  delay: 0.05                   # Delay between ticks (seconds)
  max_ticks: null               # Maximum ticks (null = unlimited)
  auto_reset: true              # Auto-reset after extinction
  safe_mode: true               # Enable safe code execution
  
  status_log_frequency: 10      # Log status every N ticks
  status_log_early_threshold: 5 # Always log first N ticks
  
  min_world_size: 5             # Minimum auto-sizing world size
  fallback_width: 80            # Fallback width for auto-sizing
  fallback_height: 24           # Fallback height for auto-sizing
```

**Timing Control:**
- `delay`: Controls simulation speed (0 = fastest, higher = slower)
- `max_ticks`: Automatic simulation termination
- `auto_reset`: Restart simulation after extinction

### Parallel Processing

Configure multi-processing options:

```yaml
parallel:
  enabled: false                # Enable parallel agent processing
  processor_count: null         # Processors to use (null = all available)
```

**Performance Impact:**
- Parallel processing improves performance with many agents
- Requires more system resources
- `null` processor count uses all available CPU cores

### Mutation Engine

Control genetic evolution parameters:

```yaml
mutation:
  rate: 0.5                     # Probability of mutating each line
  probability: 0.05             # Probability of logging mutations
  
  # Numeric variations
  small_variation_min: 1        # Min variation for small numbers
  small_variation_max: 2        # Max variation for small numbers
  large_variation_percent: 0.2  # Variation % for large numbers
  
  # Probability variations
  probability_variation_min: 0.1    # Min probability variation
  probability_variation_max: 0.3    # Max probability variation
  probability_min_bound: 0.1        # Min probability bound
  probability_max_bound: 0.9        # Max probability bound
  
  # Threshold variations
  threshold_variation_min: 1        # Min threshold variation
  threshold_variation_max: 3        # Max threshold variation
  
  # Operator mutations
  operator_probability: 0.1         # Operator mutation probability
  
  # Personality mutations
  personality_shift_min: -0.2       # Min personality shift
  personality_shift_max: 0.2        # Max personality shift
  personality_min_bound: 0.1        # Min personality bound
  personality_max_bound: 1.0        # Max personality bound
  personality_int_shift_min: -1     # Min integer personality shift
  personality_int_shift_max: 1      # Max integer personality shift
  personality_int_max_bound: 5      # Max integer personality bound
```

**Mutation Types:**
- **Numeric**: Changes numbers in agent code
- **Probability**: Adjusts probability thresholds
- **Threshold**: Modifies energy/condition thresholds
- **Operator**: Changes comparison operators
- **Personality**: Adjusts behavioral traits

### Genetic Pool

Configure evolutionary tracking:

```yaml
genetic_pool:
  fingerprint_length: 16        # Genetic fingerprint length
  survival_threshold: 100       # Survival threshold for lineage
  sample_size: 5                # Sample size for statistics
```

**Pool Management:**
- Stores successful agent variants
- Tracks lineage and evolution
- Provides parents for new agents

### Logging System

Control logging and output:

```yaml
logging:
  level: debug                  # Log level (debug, info, warn, error, fatal)
  max_agent_logs_per_simulation: 100  # Max agent logs before rotation
  survivor_filename: survivors.log     # Survivor codes log file
  survivor_max_count: 3               # Max survivors to log
```

**Log Levels:**
- **debug**: Detailed debugging information
- **info**: General simulation information
- **warn**: Warning messages
- **error**: Error conditions
- **fatal**: Critical errors

### Visual Display

Configure curses-based visual interface:

```yaml
display:
  visual_mode: true             # Use visual mode by default
```

**Visual Features:**
- Real-time grid display
- Color-coded agents by energy
- Interactive controls (WASD, space, R, Q)
- Status information overlay

### Benchmark Settings

Configure performance testing:

```yaml
benchmark:
  default_size: 20              # Default world size
  default_generations: 10       # Default generations to run
  default_runs: 3               # Default number of benchmark runs
```

### Agent Behavior Defaults

Default behavioral parameters for generated agents:

```yaml
agent_behavior:
  # Personality ranges
  personality_aggression_min: 0.3      # Min aggression
  personality_aggression_max: 0.9      # Max aggression
  personality_greed_min: 0.2           # Min greed
  personality_greed_max: 0.8           # Max greed
  personality_cooperation_min: 0.1     # Min cooperation
  personality_cooperation_max: 0.6     # Max cooperation
  
  # Death and survival
  personality_death_threshold_min: 1   # Min death threshold
  personality_death_threshold_max: 3   # Max death threshold
  death_history_check_length: 3        # Energy history length
  
  # Replication behavior
  replication_energy_base: 6            # Base replication energy
  replication_energy_greed_multiplier: 4   # Greed multiplier
  max_replications: 2                   # Max replications per agent
  min_replication_interval: 3           # Min turns between replications
  
  # Attack behavior
  attack_min_energy: 3                  # Min energy to attack
  weak_attack_min_energy: 2             # Min energy for weak attacks
  weak_attack_min_self_energy: 4        # Min self energy for weak attacks
  
  # Rest behavior
  rest_energy_base: 4                   # Base rest energy
  rest_energy_greed_multiplier: 3       # Greed multiplier for rest
```

### File System Paths

Configure file and directory locations:

```yaml
file_paths:
  agents_directory: agents              # Agent files directory
  base_agent_path: examples/agents/ruby_agent.rb  # Base agent script
  agent_memory_base_path: /tmp/agents   # Agent memory storage path
  default_agent_executable: simple_move_agent.rb  # Default agent
```

### Fitness Calculation

Configure evolutionary fitness metrics:

```yaml
fitness:
  energy_multiplier: 10         # Energy weight in fitness
  generation_multiplier: 5      # Generation weight in fitness
```

**Fitness Formula:**
```
fitness = (energy * energy_multiplier) + (generation * generation_multiplier)
```

## Command Line Overrides

### World Size Parameters

```bash
# Square grid
./bin/mutation start --size 30

# Rectangular grid  
./bin/mutation start --width 40 --height 20

# Auto-sized (no parameters)
./bin/mutation start
```

### Energy Settings

```bash
# Custom initial energy
./bin/mutation start --energy 25

# Combined with world size
./bin/mutation start --size 50 --energy 30
```

### Simulation Control

```bash
# Custom timing
./bin/mutation start --delay 0.1 --ticks 5000

# Multiple simulations
./bin/mutation start --simulations 5

# Visual/non-visual mode
./bin/mutation start --visual true
./bin/mutation start --visual false
```

### Performance Options

```bash
# Enable parallel processing
./bin/mutation start --parallel --processors 4

# Disable safe mode for performance
./bin/mutation start --safe false
```

### Custom Configuration

```bash
# Use custom config file
./bin/mutation start --config my_settings.yml

# Verbose logging
./bin/mutation start --verbose
```

## Configuration Examples

### Small World Testing

```yaml
# config/small_test.yml
world:
  size: 10
  initial_coverage: 0.2

simulation:
  delay: 0.2
  max_ticks: 500
  
energy:
  initial_min: 15
  initial_max: 25

logging:
  level: info
```

### Large Scale Performance

```yaml
# config/performance.yml
world:
  size: 100
  initial_coverage: 0.05

parallel:
  enabled: true
  processor_count: 8

simulation:
  delay: 0.01
  safe_mode: false

agent_management:
  max_agent_count: 500
  max_parallel_threads: 16
```

### Evolution Research

```yaml
# config/evolution.yml
world:
  size: 40

mutation:
  rate: 0.8
  probability: 0.2

genetic_pool:
  survival_threshold: 50

logging:
  level: debug
  max_agent_logs_per_simulation: 500
```

### Visual Demonstration

```yaml
# config/demo.yml
world:
  size: 25

simulation:
  delay: 0.15
  auto_reset: true

display:
  visual_mode: true

energy:
  initial_min: 35
  initial_max: 45
```

## Best Practices

### Development Configuration

1. **Use small worlds** for quick iteration
2. **Enable verbose logging** for debugging
3. **Increase delays** for observation
4. **Disable auto-reset** for controlled testing

### Production Configuration

1. **Optimize for performance** with parallel processing
2. **Use appropriate world sizes** for your hardware
3. **Configure log rotation** to prevent disk filling
4. **Set reasonable timeouts** for agent responses

### Research Configuration

1. **Enable detailed mutation logging** for analysis
2. **Configure genetic pool tracking** for lineage studies
3. **Use consistent random seeds** for reproducibility
4. **Archive successful configurations** for comparison

---

**[← Back to Documentation](../README.md#documentation)**