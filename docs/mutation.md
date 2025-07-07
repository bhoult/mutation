# Mutation Engine

Understanding genetic evolution and code mutation in the Mutation Simulator.

## Overview

The Mutation Engine drives evolutionary development by automatically modifying agent code when they replicate. This creates genetic diversity and enables natural selection to optimize agent behavior over time.

## Core Concepts

### Genetic Representation

Each agent is represented by its Ruby source code, which serves as its "DNA":

- **Genotype**: The actual Ruby code file containing decision logic
- **Phenotype**: The observable behavior when the code executes
- **Fitness**: Survival time and reproductive success in the environment
- **Lineage**: Parent-child relationships tracked through genetic fingerprints

### Mutation as Evolution Driver

```
Parent Agent Code → Mutation Engine → Offspring Code (Mutated)
       ↓                                        ↓
  Original Behavior                    Modified Behavior
       ↓                                        ↓
Natural Selection ←—————————————————— Competition for Survival
```

## Mutation Types

### 1. Numeric Mutations

Modifies numeric values in agent code:

**Small Numbers (< 10):**
```yaml
mutation:
  small_variation_min: 1      # Minimum change
  small_variation_max: 2      # Maximum change
```

```ruby
# Before mutation
if my_energy < 5
  { action: 'rest' }

# After mutation (5 → 7)  
if my_energy < 7
  { action: 'rest' }
```

**Large Numbers (≥ 10):**
```yaml
mutation:
  large_variation_percent: 0.2  # ±20% variation
```

```ruby
# Before mutation
if my_energy > 15
  { action: 'replicate' }

# After mutation (15 → 12, -20%)
if my_energy > 12
  { action: 'replicate' }
```

### 2. Probability Mutations

Adjusts probability values and thresholds:

```yaml
mutation:
  probability_variation_min: 0.1    # Minimum adjustment
  probability_variation_max: 0.3    # Maximum adjustment
  probability_min_bound: 0.1        # Lower bound
  probability_max_bound: 0.9        # Upper bound
```

```ruby
# Before mutation
if rand < 0.6
  { action: 'move', target: 'north' }

# After mutation (0.6 → 0.4)
if rand < 0.4
  { action: 'move', target: 'north' }
```

### 3. Threshold Mutations

Modifies energy and condition thresholds:

```yaml
mutation:
  threshold_variation_min: 1        # Minimum threshold change
  threshold_variation_max: 3        # Maximum threshold change
```

```ruby
# Before mutation
if my_energy <= 8
  { action: 'rest' }

# After mutation (8 → 5)
if my_energy <= 5
  { action: 'rest' }
```

### 4. Operator Mutations

Changes comparison operators:

```yaml
mutation:
  operator_probability: 0.1         # 10% chance of operator change
```

```ruby
# Before mutation
if my_energy > 10
  { action: 'attack', target: 'north' }

# After mutation (> → >=)
if my_energy >= 10
  { action: 'attack', target: 'north' }
```

**Possible Operator Changes:**
- `>` ↔ `>=`
- `<` ↔ `<=`
- `==` ↔ `!=`
- Random selection from valid operators

### 5. Personality Mutations

Modifies behavioral traits and strategy parameters:

```yaml
mutation:
  personality_shift_min: -0.2       # Minimum personality change
  personality_shift_max: 0.2        # Maximum personality change
  personality_min_bound: 0.1        # Lower personality bound
  personality_max_bound: 1.0        # Upper personality bound
```

```ruby
# Before mutation
aggression = 0.7
if aggression > 0.5 && enemies_nearby
  { action: 'attack', target: closest_enemy }

# After mutation (0.7 → 0.5)
aggression = 0.5
if aggression > 0.5 && enemies_nearby
  { action: 'attack', target: closest_enemy }
```

## Mutation Process

### 1. Code Analysis

When replication occurs, the mutation engine:

1. **Reads Parent Code**: Loads the parent agent's Ruby source file
2. **Parses Structure**: Identifies numeric values, operators, and patterns
3. **Selects Targets**: Chooses which elements to mutate
4. **Applies Mutations**: Modifies selected code elements
5. **Generates Offspring**: Creates new Ruby file with mutations

### 2. Mutation Rate Control

```yaml
mutation:
  rate: 0.5                    # Probability of mutating each line
  probability: 0.05            # Probability of logging mutations
```

**Line-by-Line Analysis:**
- Each line of code is examined for mutation candidates
- `rate` controls how often mutations occur
- Multiple mutations can occur in a single replication
- Mutations are logged for debugging when enabled

### 3. Mutation Application

```ruby
# Example mutation process
def apply_mutations(source_code)
  lines = source_code.split("\n")
  
  lines.map do |line|
    if rand < mutation_rate
      apply_random_mutation(line)
    else
      line
    end
  end.join("\n")
end
```

## Genetic Pool System

### Pool Management

The genetic pool maintains successful agent variants:

```yaml
genetic_pool:
  fingerprint_length: 16        # SHA256 hash length for identification
  survival_threshold: 100       # Minimum survival for lineage tracking
  sample_size: 5                # Sample size for genetic statistics
```

### Pool Structure

```
/tmp/genetic_pool/
├── agent_a1b2c3d4.rb          # Agent code file
├── agent_a1b2c3d4.meta        # Metadata file
├── agent_e5f6g7h8.rb
├── agent_e5f6g7h8.meta
└── ...
```

**Metadata Format:**
```json
{
  "fingerprint": "a1b2c3d4e5f6g7h8",
  "parent_fingerprint": "x9y8z7w6v5u4t3s2",
  "generation": 15,
  "created_at": "2024-01-15T10:30:45Z",
  "survival_ticks": 1247,
  "offspring_count": 3
}
```

### Selection Algorithm

**Weighted Random Selection:**
1. **Fitness Calculation**: Based on survival time and reproductive success
2. **Weight Assignment**: More successful agents have higher selection probability
3. **Random Selection**: Stochastic selection weighted by fitness
4. **Diversity Maintenance**: Prevents over-selection of single lineage

```ruby
def select_parent
  weights = genetic_pool.map { |agent| calculate_fitness(agent) }
  weighted_random_selection(genetic_pool, weights)
end

def calculate_fitness(agent)
  survival_weight = agent.survival_ticks * 0.7
  reproduction_weight = agent.offspring_count * 0.3
  survival_weight + reproduction_weight
end
```

## Evolution Patterns

### Emergent Behaviors

Through mutation and selection, agents develop complex behaviors:

**Early Evolution (Generations 1-10):**
- Basic energy management
- Simple movement patterns
- Random action selection
- High mortality rates

**Mid Evolution (Generations 10-50):**
- Efficient energy usage
- Food-seeking behaviors
- Basic combat strategies
- Territory awareness

**Advanced Evolution (Generations 50+):**
- Complex multi-step strategies
- Predictive behaviors
- Cooperative/competitive balance
- Environmental adaptation

### Common Evolutionary Paths

**Energy Efficiency Optimization:**
```ruby
# Generation 1: Wasteful
if my_energy > 5
  { action: 'attack', target: 'north' }

# Generation 20: Conservative
if my_energy > 15 && enemy_energy < 5
  { action: 'attack', target: 'north' }
```

**Food-Seeking Development:**
```ruby
# Generation 1: Random movement
{ action: 'move', target: ['north', 'south', 'east', 'west'].sample }

# Generation 30: Directed food searching
if dead_agents_nearby.any?
  direction = move_toward_closest(dead_agents_nearby)
  { action: 'move', target: direction }
end
```

## Lineage Tracking

### Fingerprint System

Each agent code variant gets a unique fingerprint:

```ruby
def generate_fingerprint(code)
  Digest::SHA256.hexdigest(code)[0...16]
end
```

### Family Trees

The system tracks evolutionary relationships:

```
        Agent_a1b2c3d4 (Gen 1)
               │
        ┌──────┴──────┐
        │             │
Agent_e5f6g7h8   Agent_i9j0k1l2 (Gen 2)
(Gen 2)              │
   │           ┌─────┴─────┐
   │           │           │
   │    Agent_m3n4o5p6  Agent_q7r8s9t0 (Gen 3)
   │    (Gen 3)        (Gen 3)
   │           │
   └───────────┼──→ Crossover potential
               │
        Agent_u1v2w3x4 (Gen 4)
        (Combined traits)
```

### Lineage Statistics

Track evolutionary success:

```ruby
{
  "lineage_id": "a1b2c3d4",
  "generation": 15,
  "total_offspring": 47,
  "survival_rate": 0.73,
  "avg_survival_time": 1247,
  "dominant_traits": ["aggressive", "energy_efficient"],
  "extinction_risk": "low"
}
```

## Configuration

### Mutation Parameters

Complete mutation configuration:

```yaml
mutation:
  # Basic mutation control
  rate: 0.5                         # Line mutation probability
  probability: 0.05                 # Mutation logging probability
  
  # Numeric mutations
  small_variation_min: 1            # Small number minimum change
  small_variation_max: 2            # Small number maximum change
  large_variation_percent: 0.2      # Large number percentage change
  
  # Probability mutations
  probability_variation_min: 0.1    # Minimum probability adjustment
  probability_variation_max: 0.3    # Maximum probability adjustment
  probability_min_bound: 0.1        # Probability lower bound
  probability_max_bound: 0.9        # Probability upper bound
  
  # Threshold mutations
  threshold_variation_min: 1        # Minimum threshold change
  threshold_variation_max: 3        # Maximum threshold change
  
  # Operator mutations
  operator_probability: 0.1         # Operator change probability
  
  # Personality mutations
  personality_shift_min: -0.2       # Minimum personality shift
  personality_shift_max: 0.2        # Maximum personality shift
  personality_min_bound: 0.1        # Personality lower bound
  personality_max_bound: 1.0        # Personality upper bound
  personality_int_shift_min: -1     # Integer personality minimum shift
  personality_int_shift_max: 1      # Integer personality maximum shift
  personality_int_max_bound: 5      # Integer personality upper bound
```

### Genetic Pool Configuration

```yaml
genetic_pool:
  fingerprint_length: 16        # Genetic fingerprint length
  survival_threshold: 100       # Minimum survival for tracking
  sample_size: 5                # Statistical sample size
```

## Advanced Concepts

### Convergent Evolution

Different lineages developing similar solutions:

```ruby
# Lineage A solution
if my_energy < 5 && dead_agents_nearby.any?
  { action: 'move', target: direction_to_food }

# Lineage B solution (convergent)
if my_energy <= 4 && food_available
  { action: 'move', target: food_direction }
```

### Evolutionary Arms Races

Competing strategies that drive each other's evolution:

**Attack vs Defense Evolution:**
1. **Aggressive agents** develop strong attack patterns
2. **Defensive agents** evolve evasion and energy conservation
3. **Aggressive agents** adapt to counter defensive strategies
4. **Defensive agents** develop counter-counter strategies
5. Cycle continues, driving complexity

### Genetic Diversity Maintenance

Prevent evolutionary stagnation:

- **Mutation Rate Balancing**: Enough variation without chaos
- **Selection Pressure**: Not too strong to eliminate diversity
- **Population Bottlenecks**: Extinction events reset genetic pool
- **Immigration**: Introduction of new base agents

---

**[← Back to Documentation](../README.md#documentation)**