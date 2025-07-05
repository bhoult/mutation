# Parallel Processing Notes

## Overview

The mutation simulator includes experimental parallel processing support that allows agent decisions to be computed using multiple threads.

## Current Limitations

### Ruby Global Interpreter Lock (GIL)

Ruby's GIL prevents true parallel execution of Ruby code, which means:

- **CPU-bound operations** (like agent behavior evaluation) don't benefit from threading
- The overhead of thread creation/synchronization often outweighs any benefits
- Sequential processing is typically faster for pure Ruby computations

### When Parallel Processing Might Help

1. **I/O-bound operations**: If agents perform file operations, network calls, etc.
2. **External libraries**: Using C extensions or JRuby that don't have GIL limitations
3. **Future extensions**: Database operations, complex mathematical computations

## Performance Testing

Run the parallel test to see performance characteristics on your system:

```bash
ruby examples/parallel_test.rb
```

## Usage

### Enable via Configuration

```yaml
# config/mutation.yml
parallel_agents: true
processor_count: 8  # or null for all processors
```

### Enable via CLI

```bash
# Enable with all processors
./bin/mutation start --parallel

# Enable with specific processor count
./bin/mutation start --parallel --processors 4
```

### Enable via API

```ruby
Mutation.configure do |config|
  config.parallel_agents = true
  config.processor_count = 4
end
```

## Implementation Details

The parallel processing works by:

1. **Phase 1**: Process agent decisions in parallel threads
2. **Phase 2**: Apply actions sequentially to avoid race conditions
3. **Threshold**: Only uses parallel processing when there are >10 living agents

This ensures thread safety while allowing for potential performance benefits in specific scenarios.

## Future Improvements

Potential enhancements for better parallel performance:

1. **JRuby**: Use JRuby for true thread parallelism
2. **Process-based**: Fork processes for truly parallel computation
3. **Hybrid approach**: Mix of threads and processes based on workload
4. **External computation**: Offload complex calculations to external services 