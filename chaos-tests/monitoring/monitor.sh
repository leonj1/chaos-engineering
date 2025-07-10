#!/bin/bash

# Chaos Test Monitoring Script
# Continuously monitors the health and performance of the nginx deployment

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:4566/nginx-hello-world"
CHECK_INTERVAL=2
LOG_FILE="chaos-tests/reports/monitoring_$(date +%Y%m%d_%H%M%S).log"

# Ensure log directory exists
mkdir -p chaos-tests/reports

# Function to check endpoint health
check_endpoint() {
    local endpoint=$1
    local start_time=$(date +%s.%N)
    
    # Make request and capture response code and time
    response=$(curl -s -o /dev/null -w "%{http_code}|%{time_total}" "$endpoint" 2>/dev/null)
    local end_time=$(date +%s.%N)
    
    IFS='|' read -r http_code response_time <<< "$response"
    
    # Calculate request duration
    local duration=$(echo "$end_time - $start_time" | bc)
    
    echo "${http_code}|${response_time}|${duration}"
}

# Function to print status with color
print_status() {
    local region=$1
    local status=$2
    local response_time=$3
    
    if [ "$status" == "200" ]; then
        echo -e "${GREEN}✓${NC} $region: OK (${response_time}s)"
    else
        echo -e "${RED}✗${NC} $region: FAILED (HTTP $status)"
    fi
}

# Header
echo "🔍 Chaos Engineering Monitoring Dashboard"
echo "========================================="
echo "Base URL: $BASE_URL"
echo "Check Interval: ${CHECK_INTERVAL}s"
echo "Log File: $LOG_FILE"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""

# Write log header
echo "timestamp,endpoint,http_code,response_time,total_time" > "$LOG_FILE"

# Monitoring loop
iteration=0
us_east_1_failures=0
us_east_2_failures=0
total_checks=0

while true; do
    iteration=$((iteration + 1))
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Clear previous lines and print header
    if [ $iteration -gt 1 ]; then
        echo -e "\033[5A\033[K"
    fi
    
    echo "[$timestamp] Check #$iteration"
    echo "----------------------------------------"
    
    # Check US-EAST-1
    result=$(check_endpoint "$BASE_URL/us-east-1.html")
    IFS='|' read -r http_code response_time duration <<< "$result"
    print_status "US-EAST-1" "$http_code" "$response_time"
    echo "$timestamp,us-east-1,$http_code,$response_time,$duration" >> "$LOG_FILE"
    
    if [ "$http_code" != "200" ]; then
        us_east_1_failures=$((us_east_1_failures + 1))
    fi
    
    # Check US-EAST-2
    result=$(check_endpoint "$BASE_URL/us-east-2.html")
    IFS='|' read -r http_code response_time duration <<< "$result"
    print_status "US-EAST-2" "$http_code" "$response_time"
    echo "$timestamp,us-east-2,$http_code,$response_time,$duration" >> "$LOG_FILE"
    
    if [ "$http_code" != "200" ]; then
        us_east_2_failures=$((us_east_2_failures + 1))
    fi
    
    # Check main endpoint
    result=$(check_endpoint "$BASE_URL/index.html")
    IFS='|' read -r http_code response_time duration <<< "$result"
    print_status "Main Site" "$http_code" "$response_time"
    echo "$timestamp,main,$http_code,$response_time,$duration" >> "$LOG_FILE"
    
    total_checks=$((total_checks + 1))
    
    # Calculate availability
    us_east_1_availability=$(echo "scale=2; (($total_checks - $us_east_1_failures) * 100) / $total_checks" | bc)
    us_east_2_availability=$(echo "scale=2; (($total_checks - $us_east_2_failures) * 100) / $total_checks" | bc)
    
    echo ""
    echo -e "Availability: US-E1: ${us_east_1_availability}% | US-E2: ${us_east_2_availability}%"
    
    sleep $CHECK_INTERVAL
done