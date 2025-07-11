# LocalStack Chaos Engineering Makefile
# Supports both docker and docker-compose commands

# Default port (can be overridden)
LOCALSTACK_PORT ?= 4566
export LOCALSTACK_PORT

# Docker compose command detection
DOCKER_COMPOSE := $(shell command -v docker-compose 2> /dev/null)
ifeq ($(DOCKER_COMPOSE),)
	DOCKER_COMPOSE := docker compose
endif

# Project name for consistency
PROJECT_NAME := chaos-engineering

.PHONY: help all start stop restart build init plan apply destroy upload-files chaos-monitor chaos-region-failure chaos-latency chaos-demo chaos-help chaos-main-site-failure

# Default target
.DEFAULT_GOAL := help

# Run all targets in the expected order
all: build start init-clean init plan apply upload-files
	@echo "✓ All chaos engineering tests completed successfully!"
	@echo "Check chaos-tests/reports/ for detailed test results"

start:
	@echo "Starting LocalStack Pro on port $(LOCALSTACK_PORT)..."
	@if [ -z "$$LOCALSTACK_AUTH_TOKEN" ]; then \
		echo "Error: LOCALSTACK_AUTH_TOKEN environment variable is not set"; \
		echo "Please set your LocalStack Pro authentication token"; \
		exit 1; \
	fi
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) up -d
	@echo "Waiting for LocalStack Pro to be healthy..."
	@for i in $$(seq 1 30); do \
		if docker exec localstack-chaos-engineering curl -f http://localhost:4566/_localstack/health >/dev/null 2>&1; then \
			echo "LocalStack Pro is ready!"; \
			break; \
		fi; \
		if [ $$i -eq 30 ]; then \
			echo "Timeout waiting for LocalStack Pro to start"; \
			exit 1; \
		fi; \
		echo "Waiting for LocalStack Pro... ($$i/30)"; \
		sleep 2; \
	done

stop: destroy-aws
	@echo "Stopping LocalStack Pro and cleaning up resources..."
	@echo "Destroying AWS resources first..."
	@$(MAKE) destroy-aws || true
	@echo "Cleaning up terraform state..."
	@$(MAKE) terraform-clean || true
	@echo "Stopping LocalStack containers..."
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) down
	@echo "LocalStack Pro stopped and resources cleaned up."

restart: stop start
	@echo "LocalStack Pro restarted successfully."

# Build target - pulls the latest LocalStack Pro image
build:
	@echo "Pulling latest LocalStack Pro image..."
	docker pull localstack/localstack-pro:latest

# Terraform commands
TERRAFORM_IMAGE := terraform-runner:latest
# Note: The Docker image now runs as user 1000:1000 internally
# This matches the typical Linux user ID to prevent permission issues
TERRAFORM_RUN := docker run --rm \
	--network host \
	--user 1000:1000 \
	-v $(shell pwd)/terraform:/workspace \
	-v $(shell pwd):/app \
	-e AWS_ACCESS_KEY_ID=test \
	-e AWS_SECRET_ACCESS_KEY=test \
	-e AWS_DEFAULT_REGION=us-east-1 \
	$(TERRAFORM_IMAGE)

# Build terraform Docker image
build-terraform:
	@echo "Building Terraform Docker image..."
	docker build -f Dockerfile.terraform -t $(TERRAFORM_IMAGE) .

# Clean terraform state and cache
terraform-clean:
	@echo "Cleaning Terraform state and cache..."
	@rm -f terraform/terraform.tfstate* || true
	@rm -f terraform/tfplan || true
	@rm -f terraform/.terraform.lock.hcl || true
	@rm -rf terraform/.terraform || true
	@echo "Terraform state cleaned."

# Fix permissions on terraform files owned by root
fix-terraform-permissions:
	@echo "Fixing permissions on terraform files..."
	@if [ -d terraform/.terraform ] || [ -f terraform/.terraform.lock.hcl ]; then \
		echo "Found root-owned terraform files, fixing ownership..."; \
		sudo chown -R $(shell id -u):$(shell id -g) terraform/ || true; \
		echo "Ownership fixed."; \
	else \
		echo "No root-owned terraform files found."; \
	fi

# Initialize Terraform
init: build-terraform fix-terraform-permissions
	@echo "Initializing Terraform..."
	$(TERRAFORM_RUN) init

# Initialize with clean state
init-clean: terraform-clean init
	@echo "Terraform initialized with clean state."

# Plan Terraform changes
plan: build-terraform
	@echo "Planning Terraform changes..."
	$(TERRAFORM_RUN) plan -out=tfplan

# Apply Terraform changes
apply: build-terraform
	@echo "Applying Terraform changes..."
	@if [ -f terraform/tfplan ]; then \
		$(TERRAFORM_RUN) apply tfplan; \
	else \
		$(TERRAFORM_RUN) apply -auto-approve; \
	fi

# Destroy Terraform resources
destroy: build-terraform
	@echo "Destroying Terraform resources..."
	$(TERRAFORM_RUN) destroy -auto-approve

# Force unlock terraform state (pass LOCK_ID if known)
terraform-unlock: build-terraform
	@echo "Force unlocking Terraform state..."
	@if [ -z "$(LOCK_ID)" ]; then \
		echo "Attempting to unlock any existing locks..."; \
		$(TERRAFORM_RUN) force-unlock -force auto || true; \
	else \
		$(TERRAFORM_RUN) force-unlock -force $(LOCK_ID) || true; \
	fi
	@echo "Terraform state unlock attempted."

# Destroy AWS resources with proper cleanup
destroy-aws: build-terraform
	@echo "Destroying AWS resources with cleanup..."
	@echo "Attempting to unlock any existing terraform locks..."
	@$(MAKE) terraform-unlock || true
	@echo "Importing existing IAM resources to state if they exist..."
	@$(TERRAFORM_RUN) import module.ecs_us_east_1.aws_iam_role.ecs_task_execution nginx-hello-world-ecs-task-execution-us-east-1 2>/dev/null || true
	@$(TERRAFORM_RUN) import module.ecs_us_east_2.aws_iam_role.ecs_task_execution nginx-hello-world-ecs-task-execution-us-east-2 2>/dev/null || true
	@echo "Destroying terraform resources..."
	@$(TERRAFORM_RUN) destroy -auto-approve || true
	@echo "AWS resources destroyed."

# Upload HTML files to S3 bucket
upload-files:
	@echo "Uploading HTML files to S3 bucket..."
	@if ! docker exec localstack-chaos-engineering awslocal s3 ls s3://nginx-hello-world >/dev/null 2>&1; then \
		echo "Error: S3 bucket 'nginx-hello-world' not found. Run 'make apply' first."; \
		exit 1; \
	fi
	@echo "Uploading index.html..."
	@docker exec -i localstack-chaos-engineering awslocal s3 cp - s3://nginx-hello-world/index.html \
		--content-type text/html < index.html
	@echo "Uploading us-east-1.html..."
	@docker exec -i localstack-chaos-engineering awslocal s3 cp - s3://nginx-hello-world/us-east-1.html \
		--content-type text/html < index-us-east-1.html
	@echo "Uploading us-east-2.html..."
	@docker exec -i localstack-chaos-engineering awslocal s3 cp - s3://nginx-hello-world/us-east-2.html \
		--content-type text/html < index-us-east-2.html
	@echo "✓ HTML files uploaded successfully!"
	@echo "Access the website at: http://localhost:$(LOCALSTACK_PORT)/nginx-hello-world/index.html"

# Chaos Engineering Targets
CHAOS_REGION ?= us-east-1
CHAOS_LATENCY_MS ?= 2000
CHAOS_SERVICE ?= s3
CHAOS_PROBABILITY ?= 1.0
CHAOS_ERROR_CODE ?= 503
CHAOS_RPS_LIMIT ?= 10
CHAOS_RESOURCE_TYPE ?= throughput
CHAOS_NETWORK_LATENCY ?= 2000
CHAOS_NETWORK_JITTER ?= 500

# Run chaos monitoring dashboard
chaos-monitor:
	@echo "Starting Chaos Engineering Monitoring Dashboard..."
	@echo "Press Ctrl+C to stop monitoring"
	@./chaos-tests/monitoring/monitor.sh

# Run advanced chaos monitoring dashboard
chaos-monitor-advanced:
	@echo "Starting Advanced Chaos Engineering Monitoring Dashboard..."
	@echo "Press Ctrl+C to stop monitoring"
	@./chaos-tests/monitoring/monitor-advanced.sh

# Build the TUI monitor using Docker
build-monitor-tui:
	@echo "Building Chaos Monitor TUI..."
	@docker build -f Dockerfile.monitor -t chaos-monitor-tui:latest .
	@echo "✓ Monitor TUI built successfully"

# Run the TUI monitor
chaos-monitor-tui: build-monitor-tui
	@echo "Starting Chaos Monitor TUI..."
	@echo "Controls: 'q' to quit, 'r' to force refresh"
	@# Try to get terraform outputs if available
	@DOMAIN_NAME=$$(cd terraform && terraform output -raw domain_name 2>/dev/null || echo "hello.localstack.cloud"); \
	ALB_US_EAST_1=$$(cd terraform && terraform output -raw us_east_1_alb_dns 2>/dev/null || echo ""); \
	ALB_US_EAST_2=$$(cd terraform && terraform output -raw us_east_2_alb_dns 2>/dev/null || echo ""); \
	docker run --rm -it \
		--network host \
		-v /var/run/docker.sock:/var/run/docker.sock:ro \
		-e CHAOS_DOMAIN_NAME="$$DOMAIN_NAME" \
		-e CHAOS_ALB_US_EAST_1="$$ALB_US_EAST_1" \
		-e CHAOS_ALB_US_EAST_2="$$ALB_US_EAST_2" \
		chaos-monitor-tui:latest

# Run region failure chaos test
chaos-region-failure:
	@echo "Running Region Failure Chaos Test..."
	@echo "Target Region: $(CHAOS_REGION)"
	@./chaos-tests/run-chaos-test.sh region-failure $(CHAOS_REGION)

# Run latency injection chaos test
chaos-latency:
	@echo "Running Latency Injection Chaos Test..."
	@echo "Target Region: $(CHAOS_REGION)"
	@echo "Latency: $(CHAOS_LATENCY_MS)ms"
	@./chaos-tests/run-chaos-test.sh latency $(CHAOS_REGION) $(CHAOS_LATENCY_MS)

# Run service outage chaos test
chaos-service-outage:
	@echo "Running Service Outage Chaos Test..."
	@echo "Service: $(CHAOS_SERVICE)"
	@echo "Region: $(CHAOS_REGION)"
	@echo "Probability: $(CHAOS_PROBABILITY)"
	@echo "Error Code: $(CHAOS_ERROR_CODE)"
	@./chaos-tests/run-chaos-test.sh service-outage $(CHAOS_SERVICE) $(CHAOS_REGION) $(CHAOS_PROBABILITY) $(CHAOS_ERROR_CODE)

# Run API throttling chaos test
chaos-api-throttling:
	@echo "Running API Throttling Chaos Test..."
	@echo "Service: $(CHAOS_SERVICE)"
	@echo "Region: $(CHAOS_REGION)"
	@echo "RPS Limit: $(CHAOS_RPS_LIMIT)"
	@./chaos-tests/run-chaos-test.sh api-throttling $(CHAOS_SERVICE) $(CHAOS_REGION) $(CHAOS_RPS_LIMIT)

# Run cascade failure chaos test
chaos-cascade-failure:
	@echo "Running Cascade Failure Chaos Test..."
	@echo "Initial Service: $(CHAOS_SERVICE)"
	@echo "Region: $(CHAOS_REGION)"
	@./chaos-tests/run-chaos-test.sh cascade-failure $(CHAOS_SERVICE) $(CHAOS_REGION)

# Run network partition chaos test
chaos-network-partition:
	@echo "Running Network Partition Chaos Test..."
	@echo "Latency: $(CHAOS_NETWORK_LATENCY)ms"
	@echo "Jitter: $(CHAOS_NETWORK_JITTER)ms"
	@./chaos-tests/run-chaos-test.sh network-partition $(CHAOS_NETWORK_LATENCY) $(CHAOS_NETWORK_JITTER)

# Run network partition with gradual degradation
chaos-network-gradual:
	@echo "Running Gradual Network Degradation Test..."
	@./chaos-tests/run-chaos-test.sh network-partition gradual

# Run extreme network partition
chaos-network-extreme:
	@echo "Running Extreme Network Partition Test..."
	@./chaos-tests/run-chaos-test.sh network-partition extreme

# Run resource exhaustion chaos test
chaos-resource-exhaustion:
	@echo "Running Resource Exhaustion Chaos Test..."
	@echo "Service: $(CHAOS_SERVICE)"
	@echo "Resource Type: $(CHAOS_RESOURCE_TYPE)"
	@./chaos-tests/run-chaos-test.sh resource-exhaustion $(CHAOS_SERVICE) $(CHAOS_RESOURCE_TYPE)

# Run main site failure test
chaos-main-site-failure:
	@echo "Running Main Site Failure Test..."
	@echo "This test verifies that the main site shows as offline when both regions are down"
	@./chaos-tests/run-chaos-test.sh main-site-failure

# Run full chaos demo
chaos-demo:
	@echo "Running Chaos Engineering Demo..."
	@echo "This will demonstrate various failure scenarios"
	@./chaos-tests/run-chaos-test.sh demo

# Run all chaos scenarios comprehensively
chaos-test-all:
	@echo "Running ALL Chaos Engineering Scenarios..."
	@echo "This will test all 9 chaos scenarios sequentially"
	@echo "Estimated time: 15-20 minutes"
	@echo ""
	@echo "TIP: Run 'make chaos-monitor-advanced' or 'make chaos-monitor-tui' in another terminal"
	@echo ""
	@./chaos-tests/run-all-scenarios.sh

# Clean up any stale chaos faults
chaos-cleanup:
	@echo "Cleaning up chaos faults..."
	@python3 chaos-tests/lib/cleanup_faults.py
	@rm -f /tmp/chaos-tests/*.status.json 2>/dev/null || true
	@echo "✓ Cleanup complete"

# Interactive chaos test suite
chaos-test-suite:
	@echo "Starting Interactive Chaos Test Suite..."
	@echo "Select specific scenarios to run"
	@./chaos-tests/interactive-test-suite.sh

# Show chaos test help
chaos-help:
	@echo "Chaos Engineering Test Commands:"
	@echo "================================"
	@echo ""
	@echo "Basic Scenarios:"
	@echo "  make chaos-monitor"
	@echo "    Start the monitoring dashboard to observe system health"
	@echo ""
	@echo "  make chaos-region-failure [CHAOS_REGION=us-east-1|us-east-2|both]"
	@echo "    Simulate a region failure (default: us-east-1)"
	@echo "    Example: make chaos-region-failure CHAOS_REGION=us-east-2"
	@echo ""
	@echo "  make chaos-latency [CHAOS_REGION=...] [CHAOS_LATENCY_MS=2000]"
	@echo "    Inject latency into a region (default: us-east-1, 2000ms)"
	@echo "    Example: make chaos-latency CHAOS_REGION=both CHAOS_LATENCY_MS=3000"
	@echo ""
	@echo "Advanced Scenarios (using LocalStack Chaos API):"
	@echo "  make chaos-service-outage [CHAOS_SERVICE=s3] [CHAOS_PROBABILITY=1.0] [CHAOS_ERROR_CODE=503]"
	@echo "    Simulate service outage with configurable failure rate"
	@echo "    Example: make chaos-service-outage CHAOS_SERVICE=dynamodb CHAOS_PROBABILITY=0.5"
	@echo ""
	@echo "  make chaos-api-throttling [CHAOS_SERVICE=s3] [CHAOS_RPS_LIMIT=10]"
	@echo "    Simulate API rate limiting and throttling"
	@echo "    Example: make chaos-api-throttling CHAOS_SERVICE=lambda CHAOS_RPS_LIMIT=5"
	@echo ""
	@echo "  make chaos-cascade-failure [CHAOS_SERVICE=s3]"
	@echo "    Simulate cascading failures across dependent services"
	@echo "    Example: make chaos-cascade-failure CHAOS_SERVICE=dynamodb"
	@echo ""
	@echo "  make chaos-network-partition [CHAOS_NETWORK_LATENCY=2000] [CHAOS_NETWORK_JITTER=500]"
	@echo "    Simulate network partition with latency"
	@echo "    Example: make chaos-network-partition CHAOS_NETWORK_LATENCY=5000"
	@echo ""
	@echo "  make chaos-network-gradual"
	@echo "    Test gradual network degradation"
	@echo ""
	@echo "  make chaos-network-extreme"
	@echo "    Test extreme network partition (10s latency)"
	@echo ""
	@echo "  make chaos-resource-exhaustion [CHAOS_SERVICE=dynamodb] [CHAOS_RESOURCE_TYPE=throughput]"
	@echo "    Simulate resource exhaustion scenarios"
	@echo "    Supported combinations:"
	@echo "      - dynamodb throughput/storage"
	@echo "      - lambda concurrency/storage"
	@echo "      - s3 storage/requests"
	@echo "      - kinesis shards/throughput"
	@echo "    Example: make chaos-resource-exhaustion CHAOS_SERVICE=lambda CHAOS_RESOURCE_TYPE=concurrency"
	@echo ""
	@echo "  make chaos-main-site-failure"
	@echo "    Test that main site shows offline when both regions are down"
	@echo "    Verifies VIP/Route53 behavior during complete regional outages"
	@echo ""
	@echo "Test Execution Commands:"
	@echo "  make chaos-demo"
	@echo "    Run a quick demo of all chaos scenarios"
	@echo ""
	@echo "  make chaos-test-all"
	@echo "    Run ALL scenarios comprehensively (15-20 minutes)"
	@echo ""
	@echo "  make chaos-test-suite"
	@echo "    Interactive menu to select specific scenarios to run"
	@echo ""
	@echo "Prerequisites:"
	@echo "  - LocalStack must be running (make start)"
	@echo "  - Infrastructure must be deployed (make apply)"
	@echo ""
	@echo "Tips:"
	@echo "  - Run 'make chaos-monitor' or 'make chaos-monitor-advanced' in a separate terminal"
	@echo "  - Check chaos-tests/reports/ for detailed logs after tests"
	@echo "  - Use environment variables to customize test parameters"
	@echo ""
	@echo "Quick Start:"
	@echo "  1. make start                  # Start LocalStack"
	@echo "  2. make apply                  # Deploy infrastructure"
	@echo "  3. make chaos-monitor-advanced # In terminal 1"
	@echo "  4. make chaos-test-all         # In terminal 2"
