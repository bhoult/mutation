#!/usr/bin/env python3
"""
Example Python agent for the mutation simulator
This agent implements a defensive strategy
"""

import json
import sys
import os

# Agent memory file
AGENT_ID = os.environ.get('AGENT_ID', 'unknown')
MEMORY_FILE = f"/tmp/agents/{AGENT_ID}/{AGENT_ID}.json"

def load_memory():
    try:
        with open(MEMORY_FILE, 'r') as f:
            return json.load(f)
    except:
        return {}

def save_memory(memory):
    try:
        with open(MEMORY_FILE, 'w') as f:
            json.dump(memory, f, indent=2)
    except:
        pass  # Memory is optional

def choose_action(world_state, memory):
    neighbors = world_state['neighbors']
    my_energy = world_state['energy']
    position = world_state['position']
    
    # Update memory
    memory['turns_played'] = memory.get('turns_played', 0) + 1
    memory['positions_visited'] = memory.get('positions_visited', [])
    memory['positions_visited'].append(position)
    memory['positions_visited'] = memory['positions_visited'][-20:]  # Keep last 20
    
    # Count threats (neighbors with energy >= our energy)
    threats = sum(1 for info in neighbors.values() if info['energy'] >= my_energy)
    
    # Defensive strategy
    if threats >= 2 and my_energy <= 4:
        # Multiple threats and low energy - try to replicate before dying
        if my_energy >= 3:
            action = {'action': 'replicate'}
            memory['emergency_replications'] = memory.get('emergency_replications', 0) + 1
        else:
            action = {'action': 'rest'}
    elif my_energy >= 10:
        # High energy - safe to replicate
        action = {'action': 'replicate'}
        memory['replications_made'] = memory.get('replications_made', 0) + 1
    elif threats > 0:
        # Some threats - attack the weakest one that's still threatening
        threatening_neighbors = {d: info for d, info in neighbors.items() 
                               if info['energy'] > 0 and info['energy'] >= my_energy - 2}
        if threatening_neighbors:
            target_dir = min(threatening_neighbors.keys(), 
                           key=lambda d: threatening_neighbors[d]['energy'])
            action = {'action': 'attack', 'target': target_dir}
            memory['defensive_attacks'] = memory.get('defensive_attacks', 0) + 1
        else:
            action = {'action': 'rest'}
    else:
        # No immediate threats - rest to build energy
        action = {'action': 'rest'}
        memory['peaceful_rests'] = memory.get('peaceful_rests', 0) + 1
    
    return action, memory

def main():
    memory = load_memory()
    
    try:
        for line in sys.stdin:
            world_state = json.loads(line.strip())
            
            action, updated_memory = choose_action(world_state, memory)
            save_memory(updated_memory)
            
            print(json.dumps(action))
            sys.stdout.flush()
            
            memory = updated_memory
            
    except Exception as e:
        # Fallback to rest if anything goes wrong
        print(json.dumps({'action': 'rest', 'message': f'Error: {str(e)}'}))
        sys.stdout.flush()

if __name__ == '__main__':
    main()