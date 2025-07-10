#!/bin/bash

# Comprehensive Chaos Test Runner
# Runs all chaos engineering scenarios systematically

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR/.."

# Test configuration
REPORT_FILE="chaos-tests/reports/comprehensive_test_$(date +%Y%m%d_%H%M%S).log"
TOTAL_SCENARIOS=7
CURRENT_SCENARIO=0
FAILED_SCENARIOS=0
SKIPPED_SCENARIOS=0

# Ensure reports directory exists
mkdir -p chaos-tests/reports

# Function to print colored messages
print_header() {
    echo -e "\n${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}$1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
}

print_scenario() {
    CURRENT_SCENARIO=$((CURRENT_SCENARIO + 1))
    echo -e "\n${CYAN}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${CYAN}│ Scenario $CURRENT_SCENARIO/$TOTAL_SCENARIOS: $1${NC}"
    echo -e "${CYAN}└─────────────────────────────────────────────────────────────┘${NC}"
}

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

# Function to wait with countdown
wait_with_countdown() {
    local seconds=$1
    local message="${2:-Waiting}"
    
    for ((i=$seconds; i>0; i--)); do
        echo -ne "\r${message}: $i seconds... "
        sleep 1
    done
    echo -ne "\r${message}: Done!            \n"
}

# Function to run a scenario with error handling
run_scenario() {
    local name=$1
    local command=$2
    local recovery_time=${3:-5}
    
    echo "Command: $command" | tee -a "$REPORT_FILE"
    echo "Start time: $(date)" | tee -a "$REPORT_FILE"
    
    # Execute the command
    if eval "$command" 2>&1 | tee -a "$REPORT_FILE"; then
        print_success "Scenario completed successfully"
        echo "Status: SUCCESS" >> "$REPORT_FILE"
    else
        print_error "Scenario failed"
        echo "Status: FAILED" >> "$REPORT_FILE"
        FAILED_SCENARIOS=$((FAILED_SCENARIOS + 1))
    fi
    
    echo "End time: $(date)" >> "$REPORT_FILE"
    echo "---" >> "$REPORT_FILE"
    
    # Recovery time
    if [ $CURRENT_SCENARIO -lt $TOTAL_SCENARIOS ]; then
        wait_with_countdown $recovery_time "Recovery time"
    fi
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
        print_warning "Nginx sites may not be fully deployed. Continuing anyway..."
    fi
    
    # Check Python 3
    if ! command -v python3 &> /dev/null; then
        print_error "Python 3 is required but not installed."
        exit 1
    fi
    
    print_success "Prerequisites checked"
}

# Function to show summary
show_summary() {
    print_header "TEST SUMMARY"
    
    local passed=$((TOTAL_SCENARIOS - FAILED_SCENARIOS - SKIPPED_SCENARIOS))
    
    echo -e "Total scenarios: ${TOTAL_SCENARIOS}"
    echo -e "${GREEN}Passed: ${passed}${NC}"
    echo -e "${RED}Failed: ${FAILED_SCENARIOS}${NC}"
    echo -e "${YELLOW}Skipped: ${SKIPPED_SCENARIOS}${NC}"
    echo -e "\nDetailed report: ${REPORT_FILE}"
    
    # Generate summary in report
    {
        echo ""
        echo "=== FINAL SUMMARY ==="
        echo "Total scenarios: $TOTAL_SCENARIOS"
        echo "Passed: $passed"
        echo "Failed: $FAILED_SCENARIOS"
        echo "Skipped: $SKIPPED_SCENARIOS"
        echo "Report generated: $(date)"
    } >> "$REPORT_FILE"
}

# Main execution
clear
print_header "COMPREHENSIVE CHAOS ENGINEERING TEST SUITE"
echo -e "This will run all ${TOTAL_SCENARIOS} chaos scenarios sequentially"
echo -e "Estimated time: 15-20 minutes"
echo -e "Report will be saved to: ${REPORT_FILE}"
echo ""

# Initialize report
{
    echo "=== COMPREHENSIVE CHAOS TEST REPORT ==="
    echo "Started: $(date)"
    echo "LocalStack endpoint: http://localhost:4566"
    echo ""
} > "$REPORT_FILE"

# Check prerequisites
check_prerequisites

# Note about monitoring
echo ""
print_info "TIP: Run the monitoring dashboard in another terminal:"
echo -e "  ${CYAN}make chaos-monitor-advanced${NC} or ${CYAN}make chaos-monitor-tui${NC}"
echo ""
print_info "Starting tests in 3 seconds..."
sleep 3

# Scenario 1: Region Failure
print_scenario "Region Failure Simulation"
print_info "Testing system behavior when a region becomes unavailable"
run_scenario "Region Failure" \
    "python3 $SCRIPT_DIR/scenarios/region_failure.py us-east-1 <<< $'\n'" \
    10

# Scenario 2: Latency Injection
print_scenario "Latency Injection"
print_info "Testing system performance under network latency (2 seconds)"
run_scenario "Latency Injection" \
    "python3 $SCRIPT_DIR/scenarios/latency_injection.py us-east-2 2000 <<< $'\n'" \
    10

# Scenario 3: Service Outage
print_scenario "Service Outage (S3)"
print_info "Testing S3 service outage with 80% failure probability"
run_scenario "Service Outage" \
    "python3 $SCRIPT_DIR/scenarios/service_outage.py s3 us-east-1 0.8 503 <<< $'\n'" \
    10

# Scenario 4: API Throttling
print_scenario "API Throttling (DynamoDB)"
print_info "Testing DynamoDB rate limiting with 10 RPS limit"
run_scenario "API Throttling" \
    "python3 $SCRIPT_DIR/scenarios/api_throttling.py dynamodb us-east-1 10 <<< $'\n\n'" \
    10

# Scenario 5: Cascade Failure
print_scenario "Cascade Failure"
print_info "Testing cascading failures starting from S3"
run_scenario "Cascade Failure" \
    "python3 $SCRIPT_DIR/scenarios/cascade_failure.py s3 us-east-1 <<< $'\n\n'" \
    10

# Scenario 6: Network Partition
print_scenario "Network Partition"
print_info "Testing network partition with 3 second latency"
run_scenario "Network Partition" \
    "python3 $SCRIPT_DIR/scenarios/network_partition.py 3000 500 <<< $'\n'" \
    10

# Scenario 7: Resource Exhaustion
print_scenario "Resource Exhaustion"
print_info "Testing DynamoDB throughput exhaustion"
run_scenario "Resource Exhaustion" \
    "python3 $SCRIPT_DIR/scenarios/resource_exhaustion.py dynamodb throughput <<< $'\n\n'" \
    5

# Show summary
show_summary

# Show report location
echo ""
print_info "Detailed report saved to: $REPORT_FILE"
print_info "To view the report, run: less $REPORT_FILE"

# Success exit
if [ $FAILED_SCENARIOS -eq 0 ]; then
    print_success "All chaos scenarios completed successfully!"
    exit 0
else
    print_warning "Some scenarios failed. Check the report for details."
    exit 1
fi