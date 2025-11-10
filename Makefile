# Go-Trust Containerized Deployment Makefile

.PHONY: help build run stop logs clean test

# Default target
help: ## Show this help message
	@echo "Go-Trust Containerized Deployment Commands:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

build: ## Build the Docker image
	@echo "Building go-trust-service containerized image with custom LOTL..."
	docker build -f Dockerfile -t docker-go-trust-service:latest .

run: build ## Build and run go-trust-service with docker-compose
	@echo "Starting containerized go-trust-service with custom LOTL..."
	docker-compose up -d

stop: ## Stop the running service
	@echo "Stopping containerized go-trust..."
	docker-compose down

logs: ## View service logs
	docker-compose logs -f go-trust-service

restart: stop run ## Restart the service

rebuild: ## Clean rebuild - removes old images before building new ones
	@echo "Performing clean rebuild..."
	docker-compose down -v
	docker rmi docker-go-trust-service-go-trust-service:latest || true
	docker image prune -f
	docker-compose up --build -d
	@echo "Clean rebuild completed"

status: ## Check service status
	@echo "Service Status:"
	docker-compose ps
	@echo ""
	@echo "Health Check:"
	@curl -s http://localhost:6001/health | jq . || echo "Service not responding"

test-api: ## Test the AuthZEN API endpoint
	@echo "Testing AuthZEN API..."
	@curl -X POST http://localhost:6001/api/v1/authzen/access/v1/evaluation \
		-H "Content-Type: application/json" \
		-d '{"subject":{"identity":{"x5c":["test"]}},"action":{"name":"verify"},"resource":{"type":"certificate"}}' \
		| jq . || echo "API test failed"

clean: ## Clean up containers, images, and volumes
	@echo "Cleaning up..."
	docker-compose down -v
	# Remove specific images (both naming conventions)
	docker rmi docker-go-trust-service-go-trust-service:latest || true
	docker rmi go-trust-service:latest || true
	# Remove dangling images
	docker image prune -f
	# Remove dangling volumes
	docker volume prune -f
	@echo "Cleanup completed"

clean-all: ## Aggressive cleanup - removes all dangling images and volumes
	@echo "Performing aggressive cleanup..."
	docker-compose down -v
	# Remove all dangling images
	docker image prune -a -f
	# Remove all dangling volumes
	docker volume prune -f
	# Remove unused networks
	docker network prune -f
	@echo "Aggressive cleanup completed"

dev: ## Start development environment with debug logging
	LOG_LEVEL=debug docker-compose up --build

shell: ## Get shell access to running container
	docker-compose exec go-trust-service /bin/sh

config: ## Validate configuration
	@echo "Validating configuration..."
	@if [ -f config/config.example.json ]; then \
		echo "✓ Config file exists"; \
		cat config/config.example.json | jq . > /dev/null && echo "✓ Config is valid JSON" || echo "✗ Invalid JSON"; \
	else \
		echo "✗ Config file missing"; \
	fi
	@if [ -f pipeline.yaml ]; then \
		echo "✓ Pipeline file exists"; \
	else \
		echo "✗ Pipeline file missing"; \
	fi

# Quick start for new developers
quick-start: ## Quick start guide for new developers
	@echo "=== Go-Trust Containerized Quick Start ==="
	@echo ""
	@echo "1. Build and run:"
	@echo "   make run"
	@echo ""
	@echo "2. Check status:"
	@echo "   make status"
	@echo ""
	@echo "3. View logs:"
	@echo "   make logs"
	@echo ""
	@echo "4. Test API:"
	@echo "   make test-api"
	@echo ""
	@echo "5. Stop service:"
	@echo "   make stop"
