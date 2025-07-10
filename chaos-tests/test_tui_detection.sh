#!/bin/bash
# Test script to demonstrate TUI test detection

# Source the test status library
source "$(dirname "$0")/lib/test_status.sh"

echo "Simulating a chaos test for TUI detection..."

# Write a test status file
write_test_status "service-outage" "s3 (us-east-1)" "active" "Testing S3 service outage with 80% failure rate"

echo "Status file written. The TUI should now show:"
echo "  🧪 SERVICE-OUTAGE: s3 (us-east-1)"
echo "  └─ Testing S3 service outage with 80% failure rate [via status_file]"
echo ""
echo "The status file will auto-expire after 10 minutes."
echo "To clean up immediately, run: make chaos-cleanup"