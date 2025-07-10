#!/bin/bash

# Interactive Chaos Test Suite
# Allows selecting specific scenarios to run

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

# Array of scenarios
declare -a SCENARIOS=(
    "Region Failure Simulation"
    "Latency Injection"
    "Service Outage (Chaos API)"
    "API Throttling"
    "Cascade Failure"
    "Network Partition"
    "Resource Exhaustion"
)

declare -a SCENARIO_CMDS=(
    "./chaos-tests/run-chaos-test.sh region-failure us-east-1"
    "./chaos-tests/run-chaos-test.sh latency us-east-2 2000"
    "./chaos-tests/run-chaos-test.sh service-outage s3 us-east-1 0.8 503"
    "./chaos-tests/run-chaos-test.sh api-throttling dynamodb us-east-1 10"
    "./chaos-tests/run-chaos-test.sh cascade-failure s3 us-east-1"
    "./chaos-tests/run-chaos-test.sh network-partition 2000 500"
    "./chaos-tests/run-chaos-test.sh resource-exhaustion dynamodb throughput"
)

declare -a SCENARIO_DESCRIPTIONS=(
    "Test system behavior when an AWS region becomes unavailable"
    "Inject network latency to test timeout handling"
    "Simulate service-specific failures using LocalStack Chaos API"
    "Test rate limiting and backoff strategies"
    "Simulate cascading failures across dependent services"
    "Test network partition tolerance and degraded connectivity"
    "Simulate resource exhaustion (throughput, storage, concurrency)"
)

# Selected scenarios
declare -a SELECTED_SCENARIOS=()

# Function to print header
print_header() {
    clear
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║         CHAOS ENGINEERING INTERACTIVE TEST SUITE              ║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# Function to show menu
show_menu() {
    print_header
    echo -e "${CYAN}Select scenarios to run:${NC}"
    echo ""
    
    for i in "${!SCENARIOS[@]}"; do
        local num=$((i + 1))
        local selected=""
        
        # Check if scenario is selected
        for s in "${SELECTED_SCENARIOS[@]}"; do
            if [ "$s" == "$i" ]; then
                selected="${GREEN}[✓]${NC}"
                break
            fi
        done
        
        if [ -z "$selected" ]; then
            selected="[ ]"
        fi
        
        echo -e "  $selected ${YELLOW}$num.${NC} ${SCENARIOS[$i]}"
        echo -e "      ${BLUE}${SCENARIO_DESCRIPTIONS[$i]}${NC}"
        echo ""
    done
    
    echo -e "${CYAN}Commands:${NC}"
    echo -e "  ${YELLOW}1-7${NC}  Toggle scenario selection"
    echo -e "  ${YELLOW}A${NC}    Select all scenarios"
    echo -e "  ${YELLOW}C${NC}    Clear all selections"
    echo -e "  ${YELLOW}P${NC}    Predefined test suites"
    echo -e "  ${YELLOW}R${NC}    Run selected scenarios"
    echo -e "  ${YELLOW}Q${NC}    Quit"
    echo ""
    
    if [ ${#SELECTED_SCENARIOS[@]} -gt 0 ]; then
        echo -e "${GREEN}Selected: ${#SELECTED_SCENARIOS[@]} scenario(s)${NC}"
    else
        echo -e "${YELLOW}No scenarios selected${NC}"
    fi
}

# Function to toggle scenario
toggle_scenario() {
    local index=$1
    local found=0
    local new_selected=()
    
    # Check if already selected
    for s in "${SELECTED_SCENARIOS[@]}"; do
        if [ "$s" == "$index" ]; then
            found=1
        else
            new_selected+=("$s")
        fi
    done
    
    if [ $found -eq 0 ]; then
        # Add to selection
        SELECTED_SCENARIOS+=("$index")
        # Sort the array
        IFS=$'\n' SELECTED_SCENARIOS=($(sort -n <<<"${SELECTED_SCENARIOS[*]}"))
    else
        # Remove from selection
        SELECTED_SCENARIOS=("${new_selected[@]}")
    fi
}

# Function to show predefined suites
show_predefined_suites() {
    print_header
    echo -e "${CYAN}Predefined Test Suites:${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} Basic Tests (Region Failure + Latency)"
    echo -e "  ${YELLOW}2.${NC} API Tests (Service Outage + Throttling)"
    echo -e "  ${YELLOW}3.${NC} Network Tests (Latency + Network Partition)"
    echo -e "  ${YELLOW}4.${NC} Advanced Tests (Cascade + Resource Exhaustion)"
    echo -e "  ${YELLOW}5.${NC} Comprehensive (All scenarios)"
    echo ""
    echo -e "  ${YELLOW}B${NC} Back to main menu"
    echo ""
    
    read -p "Select suite: " suite_choice
    
    case $suite_choice in
        1)
            SELECTED_SCENARIOS=(0 1)
            ;;
        2)
            SELECTED_SCENARIOS=(2 3)
            ;;
        3)
            SELECTED_SCENARIOS=(1 5)
            ;;
        4)
            SELECTED_SCENARIOS=(4 6)
            ;;
        5)
            SELECTED_SCENARIOS=(0 1 2 3 4 5 6)
            ;;
        [Bb])
            return
            ;;
    esac
}

# Function to run selected scenarios
run_selected_scenarios() {
    if [ ${#SELECTED_SCENARIOS[@]} -eq 0 ]; then
        echo -e "${RED}No scenarios selected!${NC}"
        read -p "Press Enter to continue..."
        return
    fi
    
    print_header
    echo -e "${CYAN}Running ${#SELECTED_SCENARIOS[@]} selected scenario(s)...${NC}"
    echo ""
    
    # Ask about monitoring
    echo -e "${YELLOW}Recommendation:${NC} Run monitoring in another terminal:"
    echo -e "  make chaos-monitor-advanced"
    echo ""
    read -p "Press Enter to continue..."
    
    # Run each selected scenario
    local count=0
    for i in "${SELECTED_SCENARIOS[@]}"; do
        count=$((count + 1))
        echo ""
        echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
        echo -e "${CYAN}Scenario $count/${#SELECTED_SCENARIOS[@]}: ${SCENARIOS[$i]}${NC}"
        echo -e "${PURPLE}════════════════════════════════════════════════════════════════${NC}"
        
        # Execute the scenario
        eval "${SCENARIO_CMDS[$i]}"
        
        # Wait between scenarios
        if [ $count -lt ${#SELECTED_SCENARIOS[@]} ]; then
            echo ""
            echo -e "${YELLOW}Recovery period...${NC}"
            sleep 5
        fi
    done
    
    echo ""
    echo -e "${GREEN}All selected scenarios completed!${NC}"
    read -p "Press Enter to return to menu..."
}

# Main loop
while true; do
    show_menu
    
    read -p "Enter choice: " choice
    
    case $choice in
        [1-7])
            toggle_scenario $((choice - 1))
            ;;
        [Aa])
            SELECTED_SCENARIOS=(0 1 2 3 4 5 6)
            ;;
        [Cc])
            SELECTED_SCENARIOS=()
            ;;
        [Pp])
            show_predefined_suites
            ;;
        [Rr])
            run_selected_scenarios
            ;;
        [Qq])
            echo -e "${GREEN}Goodbye!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice!${NC}"
            sleep 1
            ;;
    esac
done