# 🧠 Self-Mutating Agent Ecosystem with Generational Reseeding

## 📜 Purpose

This simulation models a digital ecosystem in which simple agents — defined by small pieces of executable code — interact, mutate, compete, and evolve over time. It is inspired by natural selection, where fitness emerges through the survival and replication of effective strategies.

When all agents die (extinction), the system automatically resets, seeding a new generation with mutated copies of the last surviving agent’s code. This allows successful behaviors to propagate and evolve across generations.

---

## 🧬 Key Mechanism

### 1. Agent Definition
Each agent contains:
- `energy`: A numeric value representing life force.
- `code_str`: A string of Ruby code defining the agent’s behavior.
- `behavior`: A compiled `Proc` (function) from `code_str`.

The behavior function takes in the agent’s local environment and returns an action, such as:
- `:attack`
- `:rest`
- `:replicate`
- `:die`

---

### 2. Mutation

When an agent replicates, its `code_str` is copied and slightly mutated:
- Constants or probabilities are changed.
- The structure remains valid Ruby code.
- Mutation is controlled to avoid syntax errors.

This mimics biological mutation.

---

### 3. Simulation Environment

- The world is a one-dimensional grid (array) of agents.
- Each simulation tick:
  - Agents observe neighboring energy.
  - Agents act based on their behavior code.
  - Energy is consumed or gained based on actions.
  - Agents may die if energy ≤ 0.

---

### 4. Extinction and Reseeding

If all agents die:
1. The last known survivor with the highest energy is selected.
2. Their code is printed for inspection.
3. A new generation is spawned using mutated clones of this agent’s code.
4. The simulation resets to tick 0 and continues infinitely.

---

## ♻️ Outcome

The system supports:
- Open-ended evolution
- Code-driven natural selection
- Emergence of increasingly complex or adaptive behavior

Over time, agent populations may:
- Persist longer
- Develop cooperative or parasitic dynamics
- Show novel behavior due to random mutation

---

## 🔍 Why This Is Valuable

- Demonstrates emergent complexity from simple rules
- Models a digital analog of evolutionary biology
- Explores how executable code can self-organize
- Provides a sandbox for evolutionary computation, agent behavior, and AI research

---

## 🚀 Potential Extensions

- Add 2D world and movement mechanics
- Log generation fitness metrics
- Visualize agent lineages
- Introduce environmental hazards or resources
- Allow agents to communicate or remember past actions

---
