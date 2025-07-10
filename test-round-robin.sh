#!/bin/bash

# Test round-robin behavior
echo "Testing nginx round-robin load balancing..."
echo "=========================================="
echo ""

# Counter for regions
us_east_1_count=0
us_east_2_count=0

# Make 10 requests
for i in {1..10}; do
    echo -n "Request $i: "
    
    # Make request and extract region
    response=$(curl -s http://localhost:4566/nginx-hello-world/index.html)
    
    # Check which region responded (using the HTML content)
    if echo "$response" | grep -q "US-EAST-1"; then
        echo "US-EAST-1"
        ((us_east_1_count++))
    elif echo "$response" | grep -q "US-EAST-2"; then
        echo "US-EAST-2"
        ((us_east_2_count++))
    else
        echo "Unknown response"
    fi
    
    # Small delay between requests
    sleep 0.5
done

echo ""
echo "Summary:"
echo "========"
echo "US-EAST-1: $us_east_1_count requests"
echo "US-EAST-2: $us_east_2_count requests"
echo ""

# For demo purposes, let's also show how to access specific regions directly
echo "Direct region access:"
echo "===================="
echo "US-EAST-1: curl http://localhost:4566/nginx-hello-world/us-east-1.html"
echo "US-EAST-2: curl http://localhost:4566/nginx-hello-world/us-east-2.html"