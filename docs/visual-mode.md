# Visual Mode

Using the curses-based visual interface for real-time simulation observation.

## Overview

Visual mode provides a real-time, interactive display of the simulation using the curses library. It shows agents as colored characters on a 2D grid, with energy levels represented by different colors and comprehensive status information.

## Getting Started

### Enabling Visual Mode

Visual mode is **enabled by default**. You can explicitly control it:

```bash
# Visual mode (default)
./bin/mutation start

# Explicitly enable visual mode
./bin/mutation start --visual true

# Disable visual mode  
./bin/mutation start --visual false
```

### System Requirements

- **Curses Library**: Required for terminal graphics
- **Color Terminal**: For energy-based color coding
- **Minimum Size**: 20×10 terminal recommended
- **Unix Environment**: Linux/macOS (Windows with WSL)

## Visual Elements

### Grid Display

The main area shows the 2D world grid:

```
┌─────────────────────────────┐
│ * *     x   *       *     x │  ← World grid
│   *   *       *   x         │
│ x       * *     *     *   * │
│     *           x   *       │
│   *   x   *   *       *   x │
│ *       *   x     *     *   │
└─────────────────────────────┘
```

### Agent Representation

**Living Agents** (`*`):
- 🟢 **Green**: High energy (8+ energy) - Healthy, active agents
- 🟡 **Yellow**: Medium energy (4-7 energy) - Moderate condition
- 🔴 **Red**: Low energy (1-3 energy) - Critical condition

**Dead Agents** (`x`):
- 🔴 **Red**: Dead agents (0 energy) - Available as food (+10 energy)

**Empty Space** (` `):
- **Blank**: No agent present, available for movement

### Status Panel

Bottom panel shows real-time simulation statistics:

```
┌─────────────────────────────┐
│                             │  ← Main grid area
│        Simulation           │
│         Display             │
│                             │
├─────────────────────────────┤
│Tick: 1247  Gen: 15         │  ← Status information
│Agents: 23/25  Cam: (5,3)   │
│Press WASD=move R=reset Q=quit│
└─────────────────────────────┘
```

**Status Fields:**
- **Tick**: Current simulation tick number
- **Gen**: Current generation number  
- **Agents**: Living agents / Total agents (including dead)
- **Cam**: Current camera position (for large worlds)

### Control Instructions

Bottom line shows available keyboard controls:
- **WASD**: Camera movement for large worlds
- **Space**: Pause/resume simulation
- **R**: Reset camera to origin (0,0)
- **Q/Esc**: Quit simulation

## Camera Controls

### Navigation (WASD)

For worlds larger than the terminal, use camera controls:

- **W**: Move camera north (up)
- **A**: Move camera west (left)  
- **S**: Move camera south (down)
- **D**: Move camera east (right)

**Camera Position Display:**
```
Cam: (15,8)  ← Current camera position
```

### Camera Management

**Reset to Origin:**
- Press **R** to return camera to (0,0)
- Useful when lost in large worlds

**Viewport Boundaries:**
- Camera cannot move beyond world boundaries
- Position clamped to valid world coordinates
- Visual feedback when at world edges

## Interactive Controls

### Pause/Resume

**Space Bar**: Toggle simulation pause
- **Paused**: Simulation stops, "PAUSED" indicator appears
- **Running**: Normal simulation speed resumes
- **Use Case**: Examine interesting configurations

### Speed Control

Control simulation speed via command line:

```bash
# Slow motion for detailed observation
./bin/mutation start --delay 0.2

# Fast simulation  
./bin/mutation start --delay 0.01

# Step-by-step control
./bin/mutation interactive
```

### Quit Options

**Q or Escape**: Clean exit
- Terminates all agent processes
- Saves final statistics
- Returns to command prompt

## Auto-Sizing

### Terminal Adaptation

When no world size is specified, visual mode automatically sizes the world to fit your terminal:

```bash
# Auto-size to terminal dimensions
./bin/mutation start

# Terminal size calculation:
# - Subtracts space for borders and status panel
# - Creates maximum usable grid area
# - Maintains reasonable minimum size
```

**Auto-sizing Logic:**
1. **Detect Terminal Size**: Query terminal dimensions
2. **Calculate Usable Area**: Subtract borders and status panel
3. **Apply Minimum Size**: Ensure world is at least 5×5
4. **Create Grid**: Size world to fit available space

### Size Override

Specify exact dimensions for consistent testing:

```bash
# Fixed square grid
./bin/mutation start --size 30

# Fixed rectangular grid
./bin/mutation start --width 50 --height 25
```

## Large World Navigation

### Viewport System

For worlds larger than terminal size:

```
World (50×50):
┌─────────────────────────────────────────────┐
│ * *     x   *       *     x                 │
│   *   *       *   x                         │ 
│ x       * *     *     *   *                 │
│     *           x   *                       │
│   ┌─────────────────────┐ *       *   x     │  ← Viewport
│ * │ *       *   x     * │   *   x           │    (visible area)
│   │   *   x   *   *     │     *             │
│   │ *       *     x   * │       *   x       │
│   │     *     *   x     │ *                 │
│   └─────────────────────┘                   │
│                                             │
└─────────────────────────────────────────────┘
```

### Navigation Strategies

**Systematic Exploration:**
1. Start at origin (0,0)
2. Use WASD to scan systematically
3. Watch for agent clusters and interesting patterns
4. Reset camera (R) to return to start

**Following Action:**
1. Watch status panel for agent count changes
2. Navigate to areas with activity
3. Use pause (Space) to examine configurations
4. Resume to continue observation

## Performance Considerations

### Display Optimization

Visual mode is optimized for performance:

- **Efficient Rendering**: Only updates changed cells
- **Smart Redraw**: Minimizes screen updates
- **Color Caching**: Reduces terminal color calls
- **Viewport Clipping**: Only renders visible area

### Large World Performance

For very large worlds (100×100+):

```bash
# Disable visual for maximum performance
./bin/mutation start --size 100 --visual false

# Or use visual with reduced delay
./bin/mutation start --size 100 --delay 0.001
```

### Memory Usage

Visual mode memory impact:
- **Minimal Overhead**: Uses existing world state
- **No Double Buffering**: Direct terminal output
- **Color State**: Small additional memory for color tracking

## Troubleshooting

### Common Issues

**Visual not starting:**
```bash
# Check if curses library is available
ruby -e "require 'curses'"

# Fallback to non-visual mode
./bin/mutation start --visual false
```

**Display corruption:**
```bash
# Reset terminal
reset

# Clear screen
clear

# Restart with fresh terminal
```

**Size issues:**
```bash
# Check terminal size
echo $COLUMNS $LINES

# Use specific size
./bin/mutation start --size 20
```

**Color problems:**
```bash
# Check color support
echo $TERM

# Force terminal type
TERM=xterm-256color ./bin/mutation start
```

### Performance Issues

**Slow rendering:**
```bash
# Reduce world size
./bin/mutation start --size 25

# Increase delay to reduce render frequency  
./bin/mutation start --delay 0.1

# Disable parallel processing
./bin/mutation start --parallel false
```

**High CPU usage:**
```bash
# Increase simulation delay
./bin/mutation start --delay 0.05

# Reduce agent count
./bin/mutation start --size 20
```

## Advanced Features

### Status Monitoring

Monitor detailed statistics during simulation:

- **Agent Count Tracking**: Living vs total agents
- **Generation Progression**: Evolution tracking
- **Tick Performance**: Simulation speed monitoring
- **Camera Position**: Navigation assistance

### Energy Visualization

Observe energy dynamics through color changes:

- **Population Health**: Overall color distribution
- **Energy Flow**: Watch agents change colors
- **Death Events**: Agents turning red (dead)
- **Recovery**: Dead agents being consumed

### Pattern Recognition

Use visual mode to identify:

- **Territorial Behavior**: Agent clustering patterns
- **Migration Patterns**: Movement trends
- **Combat Zones**: Areas of frequent agent death
- **Safe Zones**: Areas with stable populations

## Configuration

### Visual Mode Settings

```yaml
# config/mutation.yml
display:
  visual_mode: true             # Enable by default

simulation:
  delay: 0.05                   # Rendering speed
  
world:
  initial_coverage: 0.1         # Population density for visibility
```

### Custom Visual Configuration

```bash
# Slow motion for detailed observation
./bin/mutation start --delay 0.3

# Large world with navigation
./bin/mutation start --size 80 --delay 0.02

# Dense population for activity
./bin/mutation start --size 30 --energy 40
```

---

**[← Back to Documentation](../README.md#documentation)**