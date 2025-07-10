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

.PHONY: start stop restart build init plan apply destroy

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