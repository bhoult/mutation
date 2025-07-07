# World Mechanics

Understanding the grid environment, energy system, and evolutionary mechanics.

## Grid Environment

### 2D Grid System

The simulation world is a 2D grid where agents exist and interact:

- **Coordinate System**: Standard Cartesian coordinates (x, y) with (0,0) at top-left
- **Grid Types**: Supports both square grids (`size`) and rectangular grids (`width` × `height`)
- **Boundaries**: Hard boundaries - agents cannot move outside the world
- **Sparse Population**: Typically starts with 10% world coverage for realistic dynamics

### Grid Configuration

```yaml
world:
  size: 20                    # Square grid (20×20)
  # OR
  width: 30                   # Rectangular grid
  height: 20                  # (30×20)
  initial_coverage: 0.1       # 10% initial population
```

### Position and Movement

**Coordinate Examples:**
```
(0,0) ─── (1,0) ─── (2,0)
  │         │         │
(0,1) ─── (1,1) ─── (2,1)
  │         │         │  
(0,2) ─── (1,2) ─── (2,2)
```

**Movement Directions:**
- **Cardinal**: North, South, East, West
- **Diagonal**: North-East, North-West, South-East, South-West
- **Moore Neighborhood**: All 8 adjacent cells are accessible

## Energy System

### Energy Fundamentals

Energy is the core resource driving all agent behavior:

- **Initial Energy**: New agents start with 28-42 energy (configurable range)
- **Energy Decay**: All agents lose 1 energy per tick automatically
- **Death Threshold**: Agents die when energy reaches 0
- **Energy Conservation**: Total energy in system decreases over time (entropy)

### Energy Sources and Costs

#### Energy Gains
```yaml
action_costs:
  rest:
    energy_gain: 1            # +1 energy from resting
  attack:
    energy_gain: 1            # +1 energy from successful attack
  move:
    dead_agent_energy_gain: 10 # +10 energy from eating dead agents
```

#### Energy Costs
```yaml
action_costs:
  base_cost: 0.2              # Every action costs 0.2 energy
  attack:
    cost: 1.0                 # Additional 1.0 energy for attacking
  replicate:
    cost: 5                   # Total 5 energy to create offspring
```

### Energy Calculations

**Per-Tick Energy Changes:**
1. **Decay**: -1 energy (automatic)
2. **Base Action Cost**: -0.2 energy (for any action)
3. **Specific Action Cost**: Varies by action type
4. **Energy Gains**: From rest, attacks, or eating

**Example Energy Flow:**
```
Agent starts with 10 energy
- Decay: 10 - 1 = 9
- Move action: 9 - 0.2 = 8.8
- Eat dead agent: 8.8 + 10 = 18.8
Final energy: 18.8
```

## Vision System

### 5-Square Radius Vision

Agents can observe their environment in a 5-square radius (11×11 grid):

```
· · · · · A · · · · ·    A = Agent position
· · · · · · · · · · ·    · = Observable cells  
· · · · · · · · · · ·    □ = Outside vision
· · · · · · · · · · ·    
· · · · · · · · · · ·    Vision radius: 5 squares
· · · · · O · · · · ·    Total observable: 11×11 = 121 cells
· · · · · · · · · · ·    (minus agent's own position)
· · · · · · · · · · ·
· · · · · · · · · · ·
· · · · · · · · · · ·
· · · · · · · · · · ·
```

### Vision Data Format

Vision information is provided as relative coordinates:

```json
{
  "vision": {
    "0,-1": {"type": "living_agent", "energy": 5},     // North: living agent
    "1,1": {"type": "dead_agent"},                     // Southeast: dead agent
    "-2,0": {"type": "boundary"},                      // West: world boundary
    "3,-2": {"type": "living_agent", "energy": 12}    // Northeast: distant agent
  }
}
```

**Vision Types:**
- **`living_agent`**: Contains `energy` field
- **`dead_agent`**: Can be consumed for +10 energy
- **`boundary`**: Position outside world limits
- **Empty cells**: Not included (reduces message size)

### Distance Calculations

**Manhattan Distance** (used for pathfinding):
```ruby
distance = (dx.abs + dy.abs)
```

**Euclidean Distance** (for true distance):
```ruby
distance = Math.sqrt(dx*dx + dy*dy)
```

## Actions and Interactions

### Available Actions

#### 1. Attack
Damage neighboring agents and gain energy.

```yaml
attack:
  cost: 1.0                 # Energy cost (plus 0.2 base)
  damage: 3                 # Damage dealt to target
  energy_gain: 1            # Energy gained from successful attack
```

**Mechanics:**
- **Range**: Adjacent cells only (Moore neighborhood)
- **Target Selection**: Must specify direction
- **Success Condition**: Target must be living agent
- **Energy Transfer**: Attacker gains 1, target loses 3

#### 2. Rest
Recover energy by doing nothing.

```yaml
rest:
  energy_gain: 1            # Energy recovered
```

**Mechanics:**
- **Cost**: Only base cost (0.2 energy)
- **Use Case**: When energy is low or no beneficial actions available
- **Default Action**: Invalid commands default to rest

#### 3. Replicate
Create mutated offspring.

```yaml
replicate:
  cost: 5                   # Total energy cost
```

**Mechanics:**
- **Requirements**: Sufficient energy and empty adjacent cell
- **Placement**: Random empty adjacent space
- **Mutation**: Offspring code automatically mutated
- **Parent Cost**: 5 energy immediately deducted

#### 4. Move
Change position, potentially eating dead agents.

```yaml
move:
  dead_agent_energy_gain: 10  # Bonus energy from eating
```

**Mechanics:**
- **Cost**: Only base cost (0.2 energy)
- **Movement**: One cell in specified direction
- **Eating**: Moving onto dead agent grants +10 energy
- **Blocking**: Cannot move onto living agents

#### 5. Die
Voluntary termination.

**Mechanics:**
- **Cost**: None
- **Result**: Immediate agent removal from world
- **Use Case**: Altruistic behavior or hopeless situations

### Action Processing Order

Actions are processed in a specific sequence to ensure fairness:

1. **Collection Phase** (Parallel)
   - Send world state to all agents
   - Collect responses with timeout
   - Default to 'rest' for non-responsive agents

2. **Validation Phase** (Sequential)
   - Validate action parameters
   - Check energy requirements
   - Verify target positions

3. **Application Phase** (Sequential)
   - Apply attacks first (combat resolution)
   - Process movement (position changes)
   - Handle replication (create offspring)
   - Process rest actions
   - Handle voluntary deaths

4. **Physics Phase** (Sequential)
   - Apply energy decay
   - Remove dead agents
   - Update world state

## Evolutionary Mechanics

### Natural Selection

Evolution occurs through survival and reproduction pressures:

**Selection Pressures:**
- **Energy Efficiency**: Agents that manage energy well survive longer
- **Competitive Advantage**: Better combat or evasion strategies
- **Reproductive Success**: Ability to replicate effectively
- **Environmental Adaptation**: Responding to changing conditions

### Mutation System

When agents replicate, their code undergoes automatic mutation:

**Mutation Types:**
- **Numeric Values**: Energy thresholds, probabilities (±20% or ±1-2)
- **Comparison Operators**: >, <, >=, <= (10% chance to change)
- **Boolean Logic**: and, or, not operations
- **Strategy Parameters**: Behavioral weights and preferences

**Mutation Example:**
```ruby
# Parent code
if my_energy > 10
  { action: 'replicate' }

# Possible offspring mutation
if my_energy > 8    # Threshold mutated from 10 to 8
  { action: 'replicate' }
```

### Genetic Pool

Successful agent codes are preserved in a genetic pool:

- **Location**: `/tmp/genetic_pool/`
- **Fingerprinting**: SHA256 hash for unique identification
- **Lineage Tracking**: Parent-child relationships maintained
- **Selection**: Weighted random selection for new agents
- **Persistence**: Survives simulation restarts

## Environmental Dynamics

### Population Dynamics

**Birth and Death Cycles:**
- Agents die from energy depletion or attacks
- New agents created through replication
- Population oscillates based on resource availability
- Extinction events trigger simulation reset (if enabled)

**Carrying Capacity:**
- World size limits maximum sustainable population
- Energy decay creates constant selective pressure
- Dead agents provide temporary energy sources
- Resource competition drives evolution

### Spatial Effects

**Territory and Movement:**
- Agent density affects local competition
- Movement costs energy but enables resource access
- Dead agent distribution creates food patches
- Boundary effects limit movement options

**Strategic Positioning:**
- Center positions: More movement options, higher competition
- Edge positions: Limited movement, potential safety
- Corner positions: Least movement options, highest safety

### Energy Economics

**Energy Flow:**
```
New Agents (28-42 energy)
    ↓
Living Agents (energy decay -1/tick)
    ↓
Dead Agents (energy = 0, become food +10)
    ↓
Consumed (energy transferred to living agents)
    ↓
Net Energy Loss (system entropy)
```

**Economic Principles:**
- **Scarcity**: Limited total energy drives competition
- **Trade-offs**: All actions have energy costs
- **Investment**: Replication requires significant energy investment
- **Returns**: Successful strategies yield survival and reproduction

---

**[← Back to Documentation](../README.md#documentation)**