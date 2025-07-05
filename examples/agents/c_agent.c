/**
 * Example C agent for the mutation simulator
 * This agent implements a simple random strategy
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

#define MAX_LINE_SIZE 2048
#define MAX_DIRECTION_SIZE 32

typedef struct {
    int energy;
    char agent_id[64];
} Neighbor;

typedef struct {
    int tick;
    char agent_id[64];
    int position[2];
    int energy;
    int world_size[2];
    Neighbor neighbors[8];
    int generation;
    int timeout_ms;
} WorldState;

int parse_world_state(const char* json, WorldState* state) {
    // Simple JSON parsing for demo - in practice you'd use a proper JSON library
    // This is a simplified parser that looks for specific patterns
    
    // Initialize with defaults
    memset(state, 0, sizeof(WorldState));
    
    // Extract basic values (simplified parsing)
    if (sscanf(json, "%*[^\"tick\":]%*[^:]:%d", &state->tick) != 1) return 0;
    if (sscanf(json, "%*[^\"energy\":]%*[^:]:%d", &state->energy) != 1) return 0;
    
    return 1;
}

const char* choose_action(WorldState* state) {
    static char response[256];
    
    // Simple random strategy
    int choice = rand() % 100;
    
    if (choice < 30 && state->energy > 5) {
        // 30% chance to attack if we have decent energy
        const char* directions[] = {"north", "south", "east", "west"};
        const char* direction = directions[rand() % 4];
        snprintf(response, sizeof(response), 
                "{\"action\": \"attack\", \"target\": \"%s\"}", direction);
    } else if (choice < 40 && state->energy > 8) {
        // 10% chance to replicate if we have high energy  
        strcpy(response, "{\"action\": \"replicate\"}");
    } else {
        // Default to rest
        strcpy(response, "{\"action\": \"rest\"}");
    }
    
    return response;
}

int main() {
    char line[MAX_LINE_SIZE];
    WorldState state;
    
    // Seed random number generator
    srand(time(NULL) + getpid());
    
    // Main loop: read world state from stdin, output action to stdout
    while (fgets(line, sizeof(line), stdin)) {
        // Remove newline
        line[strcspn(line, "\n")] = 0;
        
        if (parse_world_state(line, &state)) {
            const char* action = choose_action(&state);
            printf("%s\n", action);
            fflush(stdout);
        } else {
            // Fallback to rest if parsing fails
            printf("{\"action\": \"rest\"}\n");
            fflush(stdout);
        }
    }
    
    return 0;
}