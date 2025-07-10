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

.PHONY: help start stop restart build init plan apply destroy chaos-monitor chaos-region-failure chaos-latency chaos-demo chaos-help

# Default target
.DEFAULT_GOAL := help

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

stop:
	@echo "Stopping LocalStack Pro..."
	$(DOCKER_COMPOSE) -p $(PROJECT_NAME) down
	@echo "LocalStack Pro stopped."

restart: stop start
	@echo "LocalStack Pro restarted successfully."

# Build target - pulls the latest LocalStack Pro image
build:
	@echo "Pulling latest LocalStack Pro image..."
	docker pull localstack/localstack-pro:latest

# Terraform commands
TERRAFORM_IMAGE := terraform-runner:latest
TERRAFORM_RUN := docker run --rm \
	--network host \
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

# Initialize Terraform
init: build-terraform
	@echo "Initializing Terraform..."
	$(TERRAFORM_RUN) init

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
	@docker run --rm -it \
		--network host \
		-v /var/run/docker.sock:/var/run/docker.sock:ro \
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

# Run full chaos demo
chaos-demo:
	@echo "Running Chaos Engineering Demo..."
	@echo "This will demonstrate various failure scenarios"
	@./chaos-tests/run-chaos-test.sh demo

# Run all chaos scenarios comprehensively
chaos-test-all:
	@echo "Running ALL Chaos Engineering Scenarios..."
	@echo "This will test all 7 chaos scenarios sequentially"
	@echo "Estimated time: 15-20 minutes"
	@echo ""
	@echo "TIP: Run 'make chaos-monitor-advanced' or 'make chaos-monitor-tui' in another terminal"
	@echo ""
	@./chaos-tests/run-all-scenarios.sh

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
	@echo "Test Execution Commands:"
	@echo "  make chaos-demo"
	@echo "    Run a quick demo of all 7 chaos scenarios"
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