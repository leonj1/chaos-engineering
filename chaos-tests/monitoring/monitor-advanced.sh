#!/bin/bash

# Advanced Chaos Test Monitoring Script
# Monitors additional failure types and Chaos API status

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="http://localhost:4566"
NGINX_URL="http://localhost:4566/nginx-hello-world"
CHECK_INTERVAL=2
LOG_FILE="chaos-tests/reports/monitoring_advanced_$(date +%Y%m%d_%H%M%S).log"

# Ensure log directory exists
mkdir -p chaos-tests/reports

# Function to check Chaos API faults
check_chaos_faults() {
    response=$(curl -s "$BASE_URL/_localstack/chaos/faults" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$response" ] && [ "$response" != "[]" ]; then
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    else
        echo "none"
    fi
}

# Function to check Chaos API effects (network)
check_chaos_effects() {
    response=$(curl -s "$BASE_URL/_localstack/chaos/effects" 2>/dev/null)
    if [ $? -eq 0 ] && [ -n "$response" ] && [ "$response" != "[]" ]; then
        echo "$response" | python3 -m json.tool 2>/dev/null || echo "$response"
    else
        echo "none"
    fi
}

# Function to check nginx endpoint
check_nginx_endpoint() {
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

# Function to test service
test_service() {
    local service=$1
    local operation=$2
    local start_time=$(date +%s.%N)
    
    case $service in
        "s3")
            response=$(docker run --rm --network host \
                -e AWS_ACCESS_KEY_ID=test \
                -e AWS_SECRET_ACCESS_KEY=test \
                -e AWS_DEFAULT_REGION=us-east-1 \
                amazon/aws-cli \
                --endpoint-url $BASE_URL \
                s3 ls 2>&1)
            ;;
        "dynamodb")
            response=$(docker run --rm --network host \
                -e AWS_ACCESS_KEY_ID=test \
                -e AWS_SECRET_ACCESS_KEY=test \
                -e AWS_DEFAULT_REGION=us-east-1 \
                amazon/aws-cli \
                --endpoint-url $BASE_URL \
                dynamodb list-tables 2>&1)
            ;;
        "lambda")
            response=$(docker run --rm --network host \
                -e AWS_ACCESS_KEY_ID=test \
                -e AWS_SECRET_ACCESS_KEY=test \
                -e AWS_DEFAULT_REGION=us-east-1 \
                amazon/aws-cli \
                --endpoint-url $BASE_URL \
                lambda list-functions 2>&1)
            ;;
        *)
            response="Service not monitored"
            ;;
    esac
    
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    
    # Detect error types
    if echo "$response" | grep -q "ServiceUnavailable\|InternalError\|ServiceException"; then
        echo "503|$duration|service_outage"
    elif echo "$response" | grep -q "SlowDown\|TooManyRequests\|ThrottlingException\|ProvisionedThroughputExceededException"; then
        echo "429|$duration|throttled"
    elif echo "$response" | grep -q "QuotaExceeded\|LimitExceededException\|ResourceInUseException"; then
        echo "400|$duration|resource_exhausted"
    elif echo "$response" | grep -q "An error occurred"; then
        echo "500|$duration|error"
    else
        echo "200|$duration|ok"
    fi
}

# Header
clear
echo -e "${BLUE}🔍 Advanced Chaos Engineering Monitoring Dashboard${NC}"
echo "=================================================="
echo "Base URL: $BASE_URL"
echo "Check Interval: ${CHECK_INTERVAL}s"
echo "Log File: $LOG_FILE"
echo ""
echo "Press Ctrl+C to stop monitoring"
echo ""

# Write log header
echo "timestamp,check_type,service,status_code,response_time,failure_type,details" > "$LOG_FILE"

# Main monitoring loop
iteration=0
declare -A service_stats
declare -A nginx_stats
nginx_failures_e1=0
nginx_failures_e2=0
nginx_total_checks=0

while true; do
    iteration=$((iteration + 1))
    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Clear screen and show header
    clear
    echo -e "${BLUE}🔍 Advanced Chaos Engineering Monitoring Dashboard${NC}"
    echo "=================================================="
    echo "[$timestamp] Check #$iteration"
    echo ""
    
    # Check active Chaos API configurations
    echo -e "${PURPLE}Active Chaos Configurations:${NC}"
    echo "----------------------------"
    
    faults=$(check_chaos_faults)
    effects=$(check_chaos_effects)
    
    if [ "$faults" != "none" ]; then
        echo -e "${YELLOW}Service Faults:${NC}"
        echo "$faults" | head -10
        echo ""
    fi
    
    if [ "$effects" != "none" ]; then
        echo -e "${YELLOW}Network Effects:${NC}"
        echo "$effects" | head -5
        echo ""
    fi
    
    if [ "$faults" == "none" ] && [ "$effects" == "none" ]; then
        echo -e "${GREEN}No active chaos configurations${NC}"
        echo ""
    fi
    
    # Monitor Nginx Web Servers
    echo -e "${CYAN}Nginx Web Servers:${NC}"
    echo "-----------------"
    
    # Check US-EAST-1
    result=$(check_nginx_endpoint "$NGINX_URL/us-east-1.html")
    IFS='|' read -r http_code response_time duration <<< "$result"
    if [ "$http_code" == "200" ]; then
        echo -e "${GREEN}✓${NC} US-EAST-1: OK (${response_time}s)"
    else
        echo -e "${RED}✗${NC} US-EAST-1: FAILED (HTTP $http_code)"
        nginx_failures_e1=$((nginx_failures_e1 + 1))
    fi
    echo "$timestamp,nginx_check,us-east-1,$http_code,$response_time,$duration" >> "$LOG_FILE"
    
    # Check US-EAST-2
    result=$(check_nginx_endpoint "$NGINX_URL/us-east-2.html")
    IFS='|' read -r http_code response_time duration <<< "$result"
    if [ "$http_code" == "200" ]; then
        echo -e "${GREEN}✓${NC} US-EAST-2: OK (${response_time}s)"
    else
        echo -e "${RED}✗${NC} US-EAST-2: FAILED (HTTP $http_code)"
        nginx_failures_e2=$((nginx_failures_e2 + 1))
    fi
    echo "$timestamp,nginx_check,us-east-2,$http_code,$response_time,$duration" >> "$LOG_FILE"
    
    # Check main site
    result=$(check_nginx_endpoint "$NGINX_URL/index.html")
    IFS='|' read -r http_code response_time duration <<< "$result"
    if [ "$http_code" == "200" ]; then
        echo -e "${GREEN}✓${NC} Main Site: OK (${response_time}s)"
    else
        echo -e "${RED}✗${NC} Main Site: FAILED (HTTP $http_code)"
    fi
    echo "$timestamp,nginx_check,main,$http_code,$response_time,$duration" >> "$LOG_FILE"
    
    nginx_total_checks=$((nginx_total_checks + 1))
    
    # Calculate nginx availability
    nginx_e1_availability=$(echo "scale=2; (($nginx_total_checks - $nginx_failures_e1) * 100) / $nginx_total_checks" | bc)
    nginx_e2_availability=$(echo "scale=2; (($nginx_total_checks - $nginx_failures_e2) * 100) / $nginx_total_checks" | bc)
    
    echo -e "Availability: US-E1: ${nginx_e1_availability}% | US-E2: ${nginx_e2_availability}%"
    
    # Monitor AWS Services
    echo ""
    echo -e "${BLUE}AWS Services:${NC}"
    echo "-------------"
    
    services=("s3" "dynamodb" "lambda")
    for service in "${services[@]}"; do
        result=$(test_service "$service" "list")
        IFS='|' read -r status_code response_time failure_type <<< "$result"
        
        # Update stats
        key="${service}_${failure_type}"
        service_stats[$key]=$((${service_stats[$key]:-0} + 1))
        
        # Display status
        case $failure_type in
            "ok")
                icon="${GREEN}✓${NC}"
                status_text="${GREEN}Healthy${NC}"
                ;;
            "throttled")
                icon="${YELLOW}⚠${NC}"
                status_text="${YELLOW}Throttled${NC}"
                ;;
            "service_outage")
                icon="${RED}✗${NC}"
                status_text="${RED}Outage${NC}"
                ;;
            "resource_exhausted")
                icon="${PURPLE}◆${NC}"
                status_text="${PURPLE}Exhausted${NC}"
                ;;
            *)
                icon="${RED}?${NC}"
                status_text="${RED}Error${NC}"
                ;;
        esac
        
        printf "%-12s %s %-20s (%.3fs)\n" "$service:" "$icon" "$status_text" "$response_time"
        
        # Log to file
        echo "$timestamp,service_check,$service,$status_code,$response_time,$failure_type," >> "$LOG_FILE"
    done
    
    # Show combined statistics
    echo ""
    echo -e "${BLUE}Cumulative Statistics:${NC}"
    echo "--------------------"
    
    # Nginx stats
    echo -e "${CYAN}Nginx Servers:${NC}"
    printf "  US-EAST-1:   Availability: %5.1f%% | Checks: %3d | Failures: %3d\n" \
        "$nginx_e1_availability" "$nginx_total_checks" "$nginx_failures_e1"
    printf "  US-EAST-2:   Availability: %5.1f%% | Checks: %3d | Failures: %3d\n" \
        "$nginx_e2_availability" "$nginx_total_checks" "$nginx_failures_e2"
    
    # AWS Service stats
    echo -e "${BLUE}AWS Services:${NC}"
    for service in "${services[@]}"; do
        total=0
        ok_count=${service_stats["${service}_ok"]:-0}
        throttled_count=${service_stats["${service}_throttled"]:-0}
        outage_count=${service_stats["${service}_service_outage"]:-0}
        exhausted_count=${service_stats["${service}_resource_exhausted"]:-0}
        error_count=${service_stats["${service}_error"]:-0}
        
        total=$((ok_count + throttled_count + outage_count + exhausted_count + error_count))
        
        if [ $total -gt 0 ]; then
            availability=$(echo "scale=2; ($ok_count * 100) / $total" | bc)
            printf "  %-10s Avail: %5.1f%% | OK: %3d | Throttled: %3d | Outage: %3d | Exhausted: %3d\n" \
                "$service:" "$availability" "$ok_count" "$throttled_count" "$outage_count" "$exhausted_count"
        fi
    done
    
    # Show tips based on current failures
    echo ""
    if [ "$faults" != "none" ] || [ "$effects" != "none" ] || [ $nginx_failures_e1 -gt 0 ] || [ $nginx_failures_e2 -gt 0 ]; then
        echo -e "${YELLOW}💡 Tips:${NC}"
        if [ $nginx_failures_e1 -gt 0 ] || [ $nginx_failures_e2 -gt 0 ]; then
            echo "  - Nginx failures detected: Check S3 bucket content and permissions"
        fi
        if echo "$faults" | grep -q "429\|ThrottlingException"; then
            echo "  - Throttling detected: Implement exponential backoff"
        fi
        if echo "$faults" | grep -q "503\|ServiceUnavailable"; then
            echo "  - Service outage detected: Check circuit breaker implementation"
        fi
        if echo "$effects" | grep -q "latency"; then
            echo "  - Network latency detected: Verify timeout configurations"
        fi
    fi
    
    sleep $CHECK_INTERVAL
done