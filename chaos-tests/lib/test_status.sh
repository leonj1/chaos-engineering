#!/bin/bash
# Chaos Test Status Reporter
# Used by chaos tests to report their status to the monitoring system

STATUS_DIR="/tmp/chaos-tests"
mkdir -p "$STATUS_DIR"

# Function to write test status
write_test_status() {
    local test_type="$1"
    local target="$2"
    local status="$3"
    local details="$4"
    
    local filename="${STATUS_DIR}/${test_type}_$(date +%s).status.json"
    
    cat > "$filename" << EOF
{
    "test_type": "$test_type",
    "target": "$target",
    "status": "$status",
    "start_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "details": "$details",
    "pid": $$
}
EOF
}

# Function to clean up old status files
cleanup_old_status() {
    find "$STATUS_DIR" -name "*.status.json" -mmin +10 -delete 2>/dev/null
}

# Export functions for use in other scripts
export -f write_test_status
export -f cleanup_old_status

# If called with arguments, write status immediately
if [ $# -ge 3 ]; then
    write_test_status "$@"
    cleanup_old_status
fi