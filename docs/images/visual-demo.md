# Visual Mode Demo (100×100 Grid)

```
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│  *   *       x         *     x             *   *           x     *               *         x       *     │
│      *   *       *   x             *                   *       *     x   *           *         *     *   │
│  x       * *     *     *   *           *     x               *   *       x         *           *         │
│      *           x   *               *         *   x           *             x   *       *     x         │
│    *   x   *   *       *   x     *           *       *     x       *   *           *   x         *       │
│  *       *   x     *     *           x   *       *           *   x     *       *         *   x           │
│          *     x   *       *   x               *   *     x         *       x   *           *             │
│  *   x       *         *   x     *       x   *       *         x   *     *       *   x         *         │
│      *     x       *         *   x           *   x     *           *   x       *         *               │
│  x   *       *   x     *           *     x       *         x   *       *     x       *   *     x         │
│  *           x   *       *     x         *   *           x   *         *   x       *         *           │
│      x   *       *         x   *     *           *   x         *     x   *       *           x           │
│  *       *     x   *           *   x     *     x       *   *         x   *         *   x         *       │
│    *   x         *     x   *       *           *   x       *         x       *   *         *   x         │
│  x       *   *         x   *     *       x   *         *   x     *         x   *       *         *       │
│  *     x       *   *         x       *         *   x         *   x       *         x   *         x       │
│      *         x   *     *         x   *     *           x   *         *   x     *         *             │
│  x   *       *         x   *           *   x     *         x       *   *         x         *   x         │
│  *         x   *     *         x   *         *   x           *         x   *   *         x       *       │
│      x   *         *   x     *           x   *       *         x   *         *   x     *                 │
│                                         ... continues for 100×100 ...                                    │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
┌─────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│ Tick: 1247        Generation: 15        Agents: 87/103        Camera: (25,18)        Procs: 87          │
│ WASD=Navigate | SPACE=Pause | R=Reset View | Q=Quit                                                      │
└─────────────────────────────────────────────────────────────────────────────────────────────────────────┘
```

## Visual Elements

- **`*`** = Living agents (displayed in color based on energy level)
  - 🟢 Green: High energy (8+ energy)
  - 🟡 Yellow: Medium energy (4-7 energy)  
  - 🔴 Red: Low energy (1-3 energy)
- **`x`** = Dead agents (red) - can be consumed for +10 energy
- **` `** = Empty space (available for movement)

## Interactive Controls

- **WASD**: Navigate camera around large worlds
- **SPACE**: Pause/resume simulation
- **R**: Reset camera to origin (0,0) 
- **Q/Esc**: Quit simulation

## Features Demonstrated

✅ **Large Scale**: Full 100×100 grid world with hundreds of agents  
✅ **Real-time**: Live simulation with configurable speed  
✅ **Navigation**: WASD camera controls for exploring large worlds  
✅ **Statistics**: Live tick count, generation, agent count, and camera position  
✅ **Energy Visualization**: Color-coded agents show health status  
✅ **Survival Tracking**: Monitor population dynamics and evolution  

## Running This Demo

```bash
# Start 100×100 visual simulation
./bin/mutation start --size 100

# Navigate with WASD keys
# Watch agents evolve and compete in real-time
# Use SPACE to pause for detailed observation
```