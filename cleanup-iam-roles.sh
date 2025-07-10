#!/bin/bash

# Clean up existing IAM roles that are causing conflicts

echo "Cleaning up existing IAM roles..."

# Function to delete an IAM role with all its attached policies
delete_iam_role() {
    local role_name=$1
    echo "Attempting to delete IAM role: $role_name"
    
    # Run in terraform docker container
    docker run --rm \
        --network host \
        -e AWS_ACCESS_KEY_ID=test \
        -e AWS_SECRET_ACCESS_KEY=test \
        -e AWS_DEFAULT_REGION=us-east-1 \
        amazon/aws-cli:latest \
        --endpoint-url=http://localhost:4566 \
        iam delete-role --role-name "$role_name" 2>/dev/null && \
        echo "✓ Deleted role: $role_name" || \
        echo "✗ Could not delete role: $role_name (may not exist or have attached policies)"
}

# Delete the specific role that's causing issues
delete_iam_role "nginx-hello-world-ecs-task-execution-us-east-2"
delete_iam_role "nginx-hello-world-ecs-task-execution-us-east-1"
delete_iam_role "nginx-hello-world-ecs-task-us-east-2"
delete_iam_role "nginx-hello-world-ecs-task-us-east-1"

echo "IAM role cleanup completed."