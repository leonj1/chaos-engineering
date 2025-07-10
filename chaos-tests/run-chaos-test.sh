#!/bin/bash

# Chaos Test Runner
# Main script to execute chaos engineering scenarios

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Function to print colored messages
print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to show usage
show_usage() {
    echo "Chaos Engineering Test Runner"
    echo "============================"
    echo ""
    echo "Usage: $0 <scenario> [options]"
    echo ""
    echo "Scenarios:"
    echo "  region-failure <region>              - Simulate region failure (us-east-1|us-east-2|both)"
    echo "  latency <region> [ms]                - Inject latency (default: 2000ms)"
    echo "  service-outage <service> [region] [prob] [code] - Service outage simulation"
    echo "  api-throttling <service> [region] [rps]         - API rate limiting"
    echo "  cascade-failure <service> [region]              - Cascading service failures"
    echo "  network-partition <latency_ms> [jitter_ms]      - Network partition/latency"
    echo "  resource-exhaustion <service> <type>            - Resource limit exhaustion"
    echo "  monitor                              - Start monitoring dashboard"
    echo "  demo                                 - Run demo sequence"
    echo ""
    echo "Examples:"
    echo "  $0 region-failure us-east-1"
    echo "  $0 latency both 3000"
    echo "  $0 service-outage s3 us-east-1 0.5 503"
    echo "  $0 api-throttling dynamodb us-east-1 10"
    echo "  $0 cascade-failure s3"
    echo "  $0 network-partition 2000 500"
    echo "  $0 resource-exhaustion dynamodb throughput"
    echo "  $0 monitor"
    echo "  $0 demo"
}

# Function to check prerequisites
check_prerequisites() {
    print_info "Checking prerequisites..."
    
    # Check if LocalStack is running
    if ! curl -s http://localhost:4566/_localstack/health > /dev/null 2>&1; then
        print_error "LocalStack is not running. Please start it with 'make start'"
        exit 1
    fi
    
    # Check if nginx sites are accessible
    if ! curl -s http://localhost:4566/nginx-hello-world/index.html > /dev/null 2>&1; then
        print_error "Nginx sites are not accessible. Please ensure S3 bucket is configured."
        exit 1
    fi
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed."
        exit 1
    fi
    
    print_success "All prerequisites met"
}

# Function to run demo sequence
run_demo() {
    print_info "Starting Chaos Engineering Demo Sequence"
    echo "========================================"
    echo ""
    echo "This demo will showcase all 7 chaos scenarios with reduced durations"
    echo ""
    
    # Start monitoring in background
    print_info "Starting advanced monitoring dashboard (in background)..."
    gnome-terminal --title="Chaos Monitoring" -- bash -c "$SCRIPT_DIR/monitoring/monitor-advanced.sh; read -p 'Press enter to close...'" 2>/dev/null || \
    xterm -title "Chaos Monitoring" -e "$SCRIPT_DIR/monitoring/monitor-advanced.sh" 2>/dev/null || \
    osascript -e "tell app \"Terminal\" to do script \"$SCRIPT_DIR/monitoring/monitor-advanced.sh\"" 2>/dev/null || \
    print_warning "Could not open monitoring in new terminal. Run manually: ./chaos-tests/monitoring/monitor-advanced.sh"
    
    sleep 3
    
    # Demo 1: Region Failure
    echo ""
    print_info "Demo 1/7: Region Failure Simulation"
    echo "-----------------------------------"
    echo "Simulating US-EAST-1 region failure..."
    read -p "Press Enter to start..."
    
    # Run with auto-recovery after 10 seconds
    (sleep 10 && echo -e '\n') | python3 "$SCRIPT_DIR/scenarios/region_failure.py" us-east-1
    
    echo ""
    sleep 2
    
    # Demo 2: Latency Injection
    echo ""
    print_info "Demo 2/7: Latency Injection"
    echo "---------------------------"
    echo "Injecting 1 second latency in US-EAST-2..."
    
    # Run with auto-recovery after 10 seconds
    (sleep 10 && echo -e '\n') | python3 "$SCRIPT_DIR/scenarios/latency_injection.py" us-east-2 1000
    
    echo ""
    sleep 2
    
    # Demo 3: Service Outage
    echo ""
    print_info "Demo 3/7: Service Outage (S3)"
    echo "-----------------------------"
    echo "Simulating S3 service outage with 50% failure rate..."
    
    # Run with auto-recovery after 10 seconds
    (sleep 10 && echo -e '\n') | python3 "$SCRIPT_DIR/scenarios/service_outage.py" s3 us-east-1 0.5 503
    
    echo ""
    sleep 2
    
    # Demo 4: API Throttling
    echo ""
    print_info "Demo 4/7: API Throttling"
    echo "------------------------"
    echo "Testing API rate limiting on DynamoDB..."
    
    # Run with auto-skip after demo
    (sleep 5 && echo -e '\n\n') | python3 "$SCRIPT_DIR/scenarios/api_throttling.py" dynamodb us-east-1 5
    
    echo ""
    sleep 2
    
    # Demo 5: Cascade Failure
    echo ""
    print_info "Demo 5/7: Cascade Failure"
    echo "-------------------------"
    echo "Demonstrating cascading failures from S3..."
    
    # Run with auto-recovery
    (sleep 8 && echo -e '\n\n') | python3 "$SCRIPT_DIR/scenarios/cascade_failure.py" s3 us-east-1
    
    echo ""
    sleep 2
    
    # Demo 6: Network Partition
    echo ""
    print_info "Demo 6/7: Network Partition"
    echo "---------------------------"
    echo "Simulating network partition with 1 second latency..."
    
    # Run with auto-recovery
    (sleep 10 && echo -e '\n') | python3 "$SCRIPT_DIR/scenarios/network_partition.py" 1000 200
    
    echo ""
    sleep 2
    
    # Demo 7: Resource Exhaustion
    echo ""
    print_info "Demo 7/7: Resource Exhaustion"
    echo "-----------------------------"
    echo "Simulating DynamoDB throughput exhaustion..."
    
    # Run with auto-skip
    (sleep 8 && echo -e '\n\n') | python3 "$SCRIPT_DIR/scenarios/resource_exhaustion.py" dynamodb throughput
    
    echo ""
    print_success "Demo sequence completed!"
    echo ""
    echo "=== DEMO SUMMARY ==="
    echo "✓ Region Failure: Tested region unavailability"
    echo "✓ Latency Injection: Tested network delays"
    echo "✓ Service Outage: Tested service-specific failures"
    echo "✓ API Throttling: Tested rate limiting"
    echo "✓ Cascade Failure: Tested failure propagation"
    echo "✓ Network Partition: Tested connectivity issues"
    echo "✓ Resource Exhaustion: Tested resource limits"
    echo ""
    echo "Check the monitoring dashboard for detailed metrics."
    echo "For full testing, run: make chaos-test-all"
}

# Main script logic
case "$1" in
    "region-failure")
        check_prerequisites
        if [ -z "$2" ]; then
            print_error "Please specify region: us-east-1, us-east-2, or both"
            exit 1
        fi
        python3 "$SCRIPT_DIR/scenarios/region_failure.py" "$2"
        ;;
        
    "latency")
        check_prerequisites
        if [ -z "$2" ]; then
            print_error "Please specify region: us-east-1, us-east-2, or both"
            exit 1
        fi
        latency_ms="${3:-2000}"
        python3 "$SCRIPT_DIR/scenarios/latency_injection.py" "$2" "$latency_ms"
        ;;
        
    "service-outage")
        check_prerequisites
        if [ -z "$2" ]; then
            print_error "Please specify service: s3, dynamodb, lambda, sqs, sns"
            exit 1
        fi
        shift
        python3 "$SCRIPT_DIR/scenarios/service_outage.py" "$@"
        ;;
        
    "api-throttling")
        check_prerequisites
        if [ -z "$2" ]; then
            print_error "Please specify service: s3, dynamodb, lambda, sqs, sns, kinesis, apigateway"
            exit 1
        fi
        shift
        python3 "$SCRIPT_DIR/scenarios/api_throttling.py" "$@"
        ;;
        
    "cascade-failure")
        check_prerequisites
        if [ -z "$2" ]; then
            print_error "Please specify initial service: s3, dynamodb, lambda, rds, sqs, apigateway"
            exit 1
        fi
        shift
        python3 "$SCRIPT_DIR/scenarios/cascade_failure.py" "$@"
        ;;
        
    "network-partition")
        check_prerequisites
        if [ -z "$2" ]; then
            print_error "Please specify latency in ms or mode (gradual/extreme)"
            exit 1
        fi
        shift
        python3 "$SCRIPT_DIR/scenarios/network_partition.py" "$@"
        ;;
        
    "resource-exhaustion")
        check_prerequisites
        if [ -z "$2" ] || [ -z "$3" ]; then
            print_error "Please specify service and resource type"
            print_error "Example: $0 resource-exhaustion dynamodb throughput"
            exit 1
        fi
        shift
        python3 "$SCRIPT_DIR/scenarios/resource_exhaustion.py" "$@"
        ;;
        
    "monitor")
        check_prerequisites
        exec "$SCRIPT_DIR/monitoring/monitor.sh"
        ;;
        
    "demo")
        check_prerequisites
        run_demo
        ;;
        
    *)
        show_usage
        exit 1
        ;;
esac