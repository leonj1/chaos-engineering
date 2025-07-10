# Chaos Engineering Demo with LocalStack

## 📋 Purpose

This project demonstrates chaos engineering principles using LocalStack to simulate AWS infrastructure locally. It showcases how to test system resilience by intentionally introducing failures and observing system behavior under stress conditions.

### Key Objectives:
- **Learn Chaos Engineering**: Practice failure injection in a safe, local environment
- **Test Resilience**: Verify system behavior when regions fail or experience latency
- **Monitor Recovery**: Observe how systems recover from various failure scenarios
- **AWS Simulation**: Use LocalStack to simulate multi-region AWS deployments without cloud costs

## 🏗️ Architecture Overview

```mermaid
graph TB
    subgraph "LocalStack Environment"
        subgraph "US-EAST-1"
            S3E1[S3 Bucket<br/>nginx-hello-world]
            HTMLe1[index-us-east-1.html]
            S3E1 --> HTMLe1
        end
        
        subgraph "US-EAST-2"
            S3E2[S3 Bucket<br/>nginx-hello-world]
            HTMLe2[index-us-east-2.html]
            S3E2 --> HTMLe2
        end
        
        R53[Route53<br/>Round Robin]
        R53 --> S3E1
        R53 --> S3E2
        
        subgraph "Chaos API"
            CAPI[LocalStack Chaos API]
            FAULTS[Service Faults<br/>/_localstack/chaos/faults]
            EFFECTS[Network Effects<br/>/_localstack/chaos/effects]
            CAPI --> FAULTS
            CAPI --> EFFECTS
        end
    end
    
    Client[Client<br/>curl/browser]
    Client --> |":4566"| R53
    Client --> |API Calls| CAPI
    
    subgraph "Chaos Tests"
        RF[Region Failure]
        LI[Latency Injection]
        SO[Service Outage]
        TH[API Throttling]
        CF[Cascade Failure]
        NP[Network Partition]
        RE[Resource Exhaustion]
        MON[Monitor]
        
        RF --> |Delete Objects| S3E1
        RF --> |Delete Objects| S3E2
        LI --> |Replace Content| S3E1
        LI --> |Replace Content| S3E2
        SO --> |Configure| FAULTS
        TH --> |Configure| FAULTS
        CF --> |Configure| FAULTS
        NP --> |Configure| EFFECTS
        RE --> |Configure| FAULTS
        MON --> |Health Checks| Client
        MON --> |Status| CAPI
    end
```

## 🔧 LocalStack Chaos API

LocalStack provides a powerful Chaos API that enables advanced failure injection beyond basic infrastructure manipulation. The API consists of two main endpoints:

### Service Faults (`/_localstack/chaos/faults`)
Inject application-level failures for specific AWS services:
- **Service-specific failures**: Target S3, DynamoDB, Lambda, etc.
- **Configurable probability**: Set failure rates from 0% to 100%
- **Custom error codes**: Return specific HTTP status codes
- **Operation-level targeting**: Fail specific API operations

Example configuration:
```json
{
  "service": "dynamodb",
  "region": "us-east-1",
  "probability": 0.5,
  "error": {
    "statusCode": 429,
    "code": "ProvisionedThroughputExceededException",
    "message": "Throughput exceeded"
  }
}
```

### Network Effects (`/_localstack/chaos/effects`)
Introduce network-level disruptions:
- **Latency injection**: Add delays to all connections
- **Simulates real network issues**: Test timeout handling
- **Global impact**: Affects all services uniformly

Example configuration:
```json
{
  "latency": 2000  // 2 second delay
}
```

## 🚀 Quick Start

### Prerequisites
- Docker and Docker Compose
- LocalStack Pro license (set as `LOCALSTACK_AUTH_TOKEN` environment variable)
- Python 3.x
- Make
- curl

### Initial Setup

1. **Clone the repository**:
   ```bash
   git clone <repository-url>
   cd chaos-engineering
   ```

2. **Set LocalStack Pro token**:
   ```bash
   export LOCALSTACK_AUTH_TOKEN="your-token-here"
   ```

3. **Start LocalStack**:
   ```bash
   make start
   ```

4. **Deploy infrastructure**:
   ```bash
   make apply
   ```

5. **Verify deployment**:
   ```bash
   curl http://localhost:4566/nginx-hello-world/us-east-1.html
   curl http://localhost:4566/nginx-hello-world/us-east-2.html
   ```

## 📊 Chaos Test Flow

```mermaid
sequenceDiagram
    participant User
    participant Monitor
    participant ChaosTest
    participant LocalStack
    participant S3
    
    User->>Monitor: make chaos-monitor
    Monitor->>Monitor: Start health checks
    
    User->>ChaosTest: make chaos-region-failure
    ChaosTest->>LocalStack: Check prerequisites
    LocalStack-->>ChaosTest: Health OK
    
    ChaosTest->>S3: Backup original content
    S3-->>ChaosTest: Content saved
    
    ChaosTest->>S3: Delete region objects
    S3-->>ChaosTest: Objects deleted
    
    Monitor->>LocalStack: Health check
    LocalStack-->>Monitor: Region failure detected
    Monitor->>User: Display failure metrics
    
    ChaosTest->>User: Press Enter to recover
    User->>ChaosTest: [Enter]
    
    ChaosTest->>S3: Restore content
    S3-->>ChaosTest: Content restored
    
    Monitor->>LocalStack: Health check
    LocalStack-->>Monitor: All regions healthy
    Monitor->>User: Display recovery metrics
```

## 🛠️ Available Commands

### LocalStack Management
| Command | Description |
|---------|-------------|
| `make start` | Start LocalStack Pro container |
| `make stop` | Stop LocalStack Pro container |
| `make restart` | Restart LocalStack Pro |
| `make build` | Pull latest LocalStack Pro image |

### Infrastructure Management
| Command | Description |
|---------|-------------|
| `make init` | Initialize Terraform |
| `make plan` | Plan infrastructure changes |
| `make apply` | Deploy nginx to both regions |
| `make destroy` | Remove all infrastructure |

### Basic Chaos Tests
| Command | Description | Example |
|---------|-------------|---------|
| `make chaos-monitor` | Start monitoring dashboard | `make chaos-monitor` |
| `make chaos-monitor-advanced` | Advanced monitoring with Chaos API status | `make chaos-monitor-advanced` |
| `make chaos-region-failure` | Simulate region failure | `make chaos-region-failure CHAOS_REGION=us-east-2` |
| `make chaos-latency` | Inject network latency | `make chaos-latency CHAOS_REGION=both CHAOS_LATENCY_MS=3000` |

### Advanced Chaos Tests (LocalStack Chaos API)
| Command | Description | Example |
|---------|-------------|---------|
| `make chaos-service-outage` | Simulate service failures | `make chaos-service-outage CHAOS_SERVICE=dynamodb CHAOS_PROBABILITY=0.5` |
| `make chaos-api-throttling` | Test rate limiting | `make chaos-api-throttling CHAOS_SERVICE=lambda CHAOS_RPS_LIMIT=5` |
| `make chaos-cascade-failure` | Cascading service failures | `make chaos-cascade-failure CHAOS_SERVICE=s3` |
| `make chaos-network-partition` | Network partition simulation | `make chaos-network-partition CHAOS_NETWORK_LATENCY=5000` |
| `make chaos-network-gradual` | Gradual network degradation | `make chaos-network-gradual` |
| `make chaos-network-extreme` | Extreme partition (10s latency) | `make chaos-network-extreme` |
| `make chaos-resource-exhaustion` | Resource limit simulation | `make chaos-resource-exhaustion CHAOS_SERVICE=dynamodb CHAOS_RESOURCE_TYPE=throughput` |

### Utility Commands
| Command | Description | Details |
|---------|-------------|---------|
| `make chaos-demo` | Quick demo of all 7 scenarios | Auto-runs with reduced durations |
| `make chaos-test-all` | Run ALL scenarios comprehensively | Full test suite (15-20 min) |
| `make chaos-test-suite` | Interactive test menu | Select specific scenarios to run |
| `make chaos-help` | Show detailed help | Lists all commands with examples |

## 🧪 Chaos Scenarios

### 1. Region Failure Simulation

```mermaid
stateDiagram-v2
    [*] --> Healthy: Initial State
    Healthy --> BackupContent: Start Test
    BackupContent --> DeleteObjects: Inject Failure
    DeleteObjects --> RegionDown: Region Failed
    RegionDown --> RestoreContent: Recovery
    RestoreContent --> Healthy: Restored
    Healthy --> [*]
```

**What it tests**: System behavior when an entire AWS region becomes unavailable.

**How it works**:
- Deletes S3 objects to simulate region failure
- Monitors response codes and availability
- Restores content on recovery

### 2. Latency Injection

```mermaid
flowchart LR
    A[Normal Response<br/>~50ms] --> B[Inject Latency]
    B --> C[Delayed Response<br/>2000-5000ms]
    C --> D[Monitor Impact]
    D --> E[Remove Latency]
    E --> A
```

**What it tests**: System performance under network latency conditions.

**How it works**:
- Replaces content with JavaScript-delayed versions
- Simulates slow network conditions
- Measures impact on user experience

### 3. Service Outage (Chaos API)

```mermaid
graph TB
    subgraph "LocalStack Chaos API"
        API[Chaos API<br/>/_localstack/chaos/faults]
        F1[Fault Rule 1<br/>S3: 503 Error]
        F2[Fault Rule 2<br/>DynamoDB: 500 Error]
        F3[Fault Rule 3<br/>Lambda: 429 Error]
        
        API --> F1
        API --> F2
        API --> F3
    end
    
    Client[Client Request] --> |S3 Operation| F1
    Client --> |DynamoDB Operation| F2
    Client --> |Lambda Invoke| F3
    
    F1 --> |80% Probability| E1[ServiceUnavailable]
    F2 --> |100% Probability| E2[InternalServerError]
    F3 --> |50% Probability| E3[TooManyRequests]
```

**What it tests**: Application resilience to service-specific failures.

**How it works**:
- Uses LocalStack Chaos API to inject service faults
- Configurable failure probability and error codes
- Tests error handling and retry logic

### 4. API Throttling

```mermaid
sequenceDiagram
    participant Client
    participant LocalStack
    participant ChaosAPI
    
    Client->>LocalStack: Burst of requests
    LocalStack->>ChaosAPI: Check rate limit
    
    loop Rate Limit Exceeded
        ChaosAPI-->>LocalStack: Throttle (429)
        LocalStack-->>Client: TooManyRequests
        Note over Client: Implement backoff
        Client->>Client: Wait (exponential backoff)
    end
    
    Client->>LocalStack: Retry request
    LocalStack->>ChaosAPI: Within limit
    ChaosAPI-->>LocalStack: Allow
    LocalStack-->>Client: Success (200)
```

**What it tests**: Rate limiting behavior and backoff strategies.

**How it works**:
- Simulates API rate limits for various services
- Tests exponential backoff implementation
- Validates circuit breaker patterns

### 5. Cascade Failure

```mermaid
graph TD
    subgraph "Failure Cascade"
        S3[S3<br/>Initial Failure]
        L1[Lambda<br/>70% Failure]
        L2[CloudFront<br/>70% Failure]
        SQS[SQS<br/>50% Failure]
        SNS[SNS<br/>50% Failure]
        
        S3 -->|Depends On| L1
        S3 -->|Depends On| L2
        L1 -->|Depends On| SQS
        L1 -->|Depends On| SNS
    end
    
    style S3 fill:#ff6b6b
    style L1 fill:#ffa500
    style L2 fill:#ffa500
    style SQS fill:#ffeb3b
    style SNS fill:#ffeb3b
```

**What it tests**: How failures propagate through dependent services.

**How it works**:
- Starts with single service failure
- Simulates cascading failures in dependent services
- Tests system-wide resilience and recovery patterns

### 6. Network Partition

```mermaid
flowchart TB
    subgraph "Network States"
        N1[Normal<br/>10ms latency]
        N2[Degraded<br/>500ms latency]
        N3[Severe<br/>2000ms latency]
        N4[Partition<br/>10000ms latency]
    end
    
    N1 -->|Gradual| N2
    N2 -->|Degradation| N3
    N3 -->|Complete| N4
    
    subgraph "Application Behavior"
        A1[All requests succeed]
        A2[Some timeouts]
        A3[Many failures]
        A4[Service unavailable]
    end
    
    N1 -.-> A1
    N2 -.-> A2
    N3 -.-> A3
    N4 -.-> A4
```

**What it tests**: Network partition tolerance and timeout handling.

**How it works**:
- Uses Chaos API to inject network latency
- Simulates various network conditions
- Tests timeout configurations and failover logic

### 7. Resource Exhaustion

```mermaid
graph LR
    subgraph "Resource Types"
        RT1[DynamoDB<br/>Throughput]
        RT2[Lambda<br/>Concurrency]
        RT3[S3<br/>Storage Quota]
        RT4[Kinesis<br/>Shard Limit]
    end
    
    subgraph "Failure Modes"
        FM1[Throttling]
        FM2[Rejections]
        FM3[Quota Errors]
        FM4[Backpressure]
    end
    
    RT1 --> FM1
    RT2 --> FM2
    RT3 --> FM3
    RT4 --> FM4
    
    subgraph "Mitigation"
        M1[Auto-scaling]
        M2[Load Shedding]
        M3[Circuit Breaker]
        M4[Backoff Strategy]
    end
    
    FM1 --> M1
    FM2 --> M2
    FM3 --> M3
    FM4 --> M4
```

**What it tests**: System behavior under resource constraints.

**How it works**:
- Simulates various resource exhaustion scenarios
- Tests auto-scaling and backpressure handling
- Validates graceful degradation strategies

## 📈 Monitoring Dashboard

### Basic Monitoring
The basic monitoring dashboard tracks nginx availability:
- Response times for each region
- HTTP status codes
- Availability percentages
- Failure counts

```
🔍 Chaos Engineering Monitoring Dashboard
=========================================
[2024-01-10 10:30:45] Check #42
----------------------------------------
✓ US-EAST-1: OK (0.045s)
✗ US-EAST-2: FAILED (HTTP 404)
✓ Main Site: OK (0.052s)

Availability: US-E1: 100.00% | US-E2: 0.00%
```

### Advanced Monitoring
The advanced monitoring dashboard (`make chaos-monitor-advanced`) provides:
- Active Chaos API configurations
- Service-specific health status
- Failure type detection (throttling, outage, exhaustion)
- Real-time tips for mitigation

```
🔍 Advanced Chaos Engineering Monitoring Dashboard
==================================================
Active Chaos Configurations:
----------------------------
Service Faults:
{
  "id": "fault-123",
  "service": "dynamodb",
  "probability": 0.8,
  "error": {
    "statusCode": 429,
    "code": "ProvisionedThroughputExceededException"
  }
}

Service Health Status:
---------------------
s3:          ✓ Healthy        (0.045s)
dynamodb:    ⚠ Throttled      (0.123s)
lambda:      ✗ Outage         (timeout)

Cumulative Statistics:
--------------------
s3:          Availability:  98.5% | OK:  197 | Throttled:   2 | Outage:   1
dynamodb:    Availability:  60.0% | OK:  120 | Throttled:  76 | Outage:   4
lambda:      Availability:  85.0% | OK:  170 | Throttled:  15 | Outage:  15

💡 Tips:
  - Throttling detected: Implement exponential backoff
  - Service outage detected: Check circuit breaker implementation
```

## 📁 Project Structure

```
chaos-engineering/
├── docker-compose.yml          # LocalStack Pro configuration
├── Makefile                    # Build and test automation
├── terraform/
│   ├── main.tf                # Root Terraform configuration
│   ├── variables.tf           # Terraform variables
│   └── modules/
│       ├── s3-website/        # S3 static hosting module
│       └── route53/           # Route53 configuration
├── chaos-tests/
│   ├── scenarios/             # Chaos test implementations
│   │   ├── region_failure.py  # Region failure simulation
│   │   └── latency_injection.py # Latency injection
│   ├── monitoring/            # Monitoring tools
│   │   └── monitor.sh        # Real-time dashboard
│   ├── reports/              # Test results and logs
│   └── run-chaos-test.sh     # Main test runner
└── index-*.html              # Region-specific content
```

## 🔍 Testing Workflow

```mermaid
graph TD
    A[Start LocalStack] --> B[Deploy Infrastructure]
    B --> C[Start Monitoring]
    C --> D{Choose Scenario}
    
    D --> E[Region Failure]
    D --> F[Latency Injection]
    D --> G[Full Demo]
    
    E --> H[Observe Impact]
    F --> H
    G --> H
    
    H --> I[Recovery]
    I --> J[Analyze Results]
    J --> K[Review Logs]
    
    K --> L{More Tests?}
    L -->|Yes| D
    L -->|No| M[Stop LocalStack]
```

## 💡 Best Practices

1. **Always Monitor First**: Start the monitoring dashboard before running chaos tests
   ```bash
   # Terminal 1 - For basic tests
   make chaos-monitor
   
   # OR for advanced tests
   make chaos-monitor-advanced
   
   # Terminal 2
   make chaos-service-outage
   ```

2. **Start Small**: Test single services before complex scenarios
   ```bash
   # Start with single region
   make chaos-region-failure CHAOS_REGION=us-east-1
   
   # Then test both regions
   make chaos-region-failure CHAOS_REGION=both
   
   # Start with low failure probability
   make chaos-service-outage CHAOS_PROBABILITY=0.2
   
   # Increase gradually
   make chaos-service-outage CHAOS_PROBABILITY=0.8
   ```

3. **Test Progressive Failures**: Use gradual degradation modes
   ```bash
   # Test gradual network degradation
   make chaos-network-gradual
   
   # Test increasing latency
   make chaos-latency CHAOS_LATENCY_MS=500
   make chaos-latency CHAOS_LATENCY_MS=2000
   make chaos-latency CHAOS_LATENCY_MS=5000
   ```

4. **Combine Scenarios**: Test realistic failure combinations
   ```bash
   # Terminal 1: Network latency
   make chaos-network-partition CHAOS_NETWORK_LATENCY=1000
   
   # Terminal 2: Service throttling
   make chaos-api-throttling CHAOS_SERVICE=dynamodb
   ```

5. **Document Findings**: 
   - Check `chaos-tests/reports/` for detailed logs
   - Note system behavior under each scenario
   - Document recovery times and patterns

## 🐛 Troubleshooting

### LocalStack won't start
- Verify `LOCALSTACK_AUTH_TOKEN` is set correctly
- Check Docker is running: `docker ps`
- Review logs: `docker logs localstack-chaos-engineering`

### Terraform apply fails
- Ensure LocalStack is healthy: `make start`
- Check AWS CLI is configured for LocalStack
- Verify S3 bucket creation permissions

### Chaos tests fail
- Confirm infrastructure is deployed: `make apply`
- Check S3 bucket exists and has content
- Verify Python 3 is installed: `python3 --version`

## 📚 Learning Resources

- [Principles of Chaos Engineering](https://principlesofchaos.org/)
- [LocalStack Documentation](https://docs.localstack.cloud/)
- [AWS Well-Architected Framework - Reliability Pillar](https://docs.aws.amazon.com/wellarchitected/latest/reliability-pillar/welcome.html)

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Add your chaos scenario
4. Submit a pull request

## 📄 License

This project is for educational purposes. See LICENSE file for details.