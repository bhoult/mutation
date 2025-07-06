
# Gemini Code Understanding

This document provides a high-level overview of the Mutation project, a Ruby-based evolutionary simulation.

## Project Overview

The Mutation project is a simulation of evolution where agents, defined by self-modifying Ruby code, compete for survival. The simulation runs in a 2D world where agents can perform actions like attacking other agents, resting to gain energy, or replicating to create offspring. The core of the project is the concept of mutation, where an agent's code can change during replication, leading to new behaviors and potentially more successful agents.

The project is well-structured, with a clear separation of concerns between the different components. It includes a command-line interface (CLI) for running simulations, a curses-based visualizer, and support for parallel processing.

## Key Components

### `lib/mutation.rb`

This is the main entry point of the library. It sets up the necessary requires for the other components and provides a top-level module for the project.

### `lib/mutation/agent.rb`

This file defines the `Agent` class, which is the core entity in the simulation. Each agent has:

-   **Energy**: A measure of its health.
-   **Code**: A string of Ruby code that defines its behavior.
-   **Behavior**: A compiled `Proc` from the code.
-   **Generation**: Its lineage in the evolutionary tree.

Agents can perform the following actions: `:attack`, `:rest`, `:replicate`, and `:die`.

### `lib/mutation/world.rb`

The `World` class represents the environment where the agents live. It's a 2D grid where agents can interact with their neighbors. The world is responsible for:

-   Stepping the simulation forward in time.
-   Managing the grid of agents.
-   Providing agents with information about their environment.

### `lib/mutation/simulator.rb`

The `Simulator` class orchestrates the entire simulation. It initializes the world, runs the simulation loop, and handles user input for interactive mode. It also provides features like:

-   Running the simulation for a specific number of ticks.
-   Running the simulation until all agents are dead (extinction).
-   Pausing, resuming, and stopping the simulation.

### `lib/mutation/cli.rb`

This file implements the command-line interface using the `thor` gem. It provides commands for:

-   Starting a simulation with various options.
-   Running the simulation in interactive mode.
-   Displaying the current configuration.
-   Running benchmark tests.
-   Starting a visual simulation with a curses-based display.

### `lib/mutation/mutation_engine.rb`

The `MutationEngine` is responsible for mutating the code of agents during replication. It can perform several types of mutations, including:

-   **Numeric mutations**: Changing numeric values in the code.
-   **Probability mutations**: Modifying probabilities.
-   **Operator mutations**: Changing comparison operators.
-   **Threshold mutations**: Altering decision boundaries.

## How to Run

The project can be run using the `bin/mutation` executable. For example, to start a basic simulation, you can run:

```bash
./bin/mutation start
```

The CLI provides several options for customizing the simulation, such as the world size, initial energy of agents, and simulation delay.

## Dependencies

The project uses the following gems:

-   `colorize`: For colored output in the console.
-   `curses`: For the terminal-based visualizer.
-   `logger`: For logging.
-   `parallel`: For parallel processing of agents.
-   `thor`: For the command-line interface.
-   `yaml`: For configuration file parsing.

For development and testing, it also uses `guard`, `guard-rspec`, `pry`, `rspec`, `rubocop`, `factory_bot`, and `simplecov`.
