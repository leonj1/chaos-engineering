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
    echo "  region-failure <region>    - Simulate region failure (us-east-1|us-east-2|both)"
    echo "  latency <region> [ms]      - Inject latency (default: 2000ms)"
    echo "  monitor                    - Start monitoring dashboard"
    echo "  demo                       - Run demo sequence"
    echo ""
    echo "Examples:"
    echo "  $0 region-failure us-east-1"
    echo "  $0 latency both 3000"
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
    
    # Start monitoring in background
    print_info "Starting monitoring dashboard (in background)..."
    gnome-terminal --title="Chaos Monitoring" -- bash -c "$SCRIPT_DIR/monitoring/monitor.sh; read -p 'Press enter to close...'" 2>/dev/null || \
    xterm -title "Chaos Monitoring" -e "$SCRIPT_DIR/monitoring/monitor.sh" 2>/dev/null || \
    osascript -e "tell app \"Terminal\" to do script \"$SCRIPT_DIR/monitoring/monitor.sh\"" 2>/dev/null || \
    print_warning "Could not open monitoring in new terminal. Run manually: ./chaos-tests/monitoring/monitor.sh"
    
    sleep 3
    
    # Demo 1: Region Failure
    echo ""
    print_info "Demo 1: Region Failure Simulation"
    echo "--------------------------------"
    echo "Simulating US-EAST-1 region failure..."
    read -p "Press Enter to start..."
    
    python3 "$SCRIPT_DIR/scenarios/region_failure.py" us-east-1
    
    echo ""
    read -p "Press Enter to continue to next demo..."
    
    # Demo 2: Latency Injection
    echo ""
    print_info "Demo 2: Latency Injection"
    echo "------------------------"
    echo "Injecting 3 second latency in US-EAST-2..."
    read -p "Press Enter to start..."
    
    python3 "$SCRIPT_DIR/scenarios/latency_injection.py" us-east-2 3000
    
    echo ""
    print_success "Demo sequence completed!"
    echo ""
    echo "Check the monitoring dashboard for detailed metrics."
    echo "Monitoring logs are saved in: chaos-tests/reports/"
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