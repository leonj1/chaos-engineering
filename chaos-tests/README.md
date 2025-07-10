# Chaos Engineering Test Suite

This directory contains chaos engineering scenarios for testing the resilience of our multi-region nginx deployment on LocalStack.

## Available Chaos Scenarios

### 1. Region Failure Simulation
- **Purpose**: Test system behavior when an entire region becomes unavailable
- **Implementation**: Removes S3 objects to simulate region outage
- **Recovery**: Automatically restores content after test

### 2. Latency Injection
- **Purpose**: Test system behavior under network latency conditions
- **Implementation**: Replaces content with delayed-loading versions
- **Recovery**: Restores original fast-loading content

### 3. More scenarios (planned):
- DNS chaos
- Partial service degradation
- Load testing
- Storage failures

## Quick Start

### Run a specific chaos test:
```bash
# Simulate region failure
./chaos-tests/run-chaos-test.sh region-failure us-east-1

# Inject latency
./chaos-tests/run-chaos-test.sh latency us-east-2 3000

# Start monitoring dashboard
./chaos-tests/run-chaos-test.sh monitor

# Run demo sequence
./chaos-tests/run-chaos-test.sh demo
```

### Monitor system health:
```bash
./chaos-tests/monitoring/monitor.sh
```

## Directory Structure
```
chaos-tests/
├── scenarios/          # Chaos scenario implementations
│   ├── region_failure.py
│   └── latency_injection.py
├── monitoring/         # Monitoring and observability tools
│   └── monitor.sh
├── reports/           # Test results and logs
└── run-chaos-test.sh  # Main test runner
```

## Test Results

After running tests, check the `reports/` directory for:
- Monitoring logs with response times and availability metrics
- Test execution summaries

## Best Practices

1. **Always monitor** - Run the monitoring dashboard before starting chaos tests
2. **Start small** - Test one region before testing both
3. **Have recovery plan** - All scenarios include automatic recovery
4. **Document findings** - Record observations about system behavior

## Example Test Session

1. Start monitoring in one terminal:
   ```bash
   ./chaos-tests/monitoring/monitor.sh
   ```

2. In another terminal, run a chaos test:
   ```bash
   ./chaos-tests/run-chaos-test.sh region-failure us-east-1
   ```

3. Observe the monitoring dashboard to see:
   - Which region is failing
   - Response times
   - Overall availability

4. Press Enter to recover when prompted

5. Check logs in `reports/` for detailed metrics