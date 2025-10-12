.PHONY: help setup build clean test run deploy stop status proto server strategy-image all

# Default target
help:
	@echo "Quant Club Trading Desk - Available Commands"
	@echo ""
	@echo "Setup & Build:"
	@echo "  make setup          - Complete initial setup (install deps, build everything)"
	@echo "  make build          - Build server and strategy image"
	@echo "  make proto          - Generate protobuf code"
	@echo "  make server         - Build Go server"
	@echo "  make strategy-image - Build strategy Docker image"
	@echo ""
	@echo "Run:"
	@echo "  make run            - Start the trading desk server"
	@echo "  make deploy         - Deploy all strategies"
	@echo "  make stop           - Stop all strategies"
	@echo "  make status         - Check strategy status"
	@echo ""
	@echo "Cleanup:"
	@echo "  make clean          - Remove all built artifacts"
	@echo "  make clean-docker   - Clean + remove Docker containers/images"
	@echo ""
	@echo "Development:"
	@echo "  make rebuild        - Clean, regenerate protos, and rebuild everything"
	@echo "  make test           - Run tests (coming soon)"
	@echo ""
	@echo "Environment variables:"
	@echo "  APCA_API_KEY_ID     - Alpaca API key (required)"
	@echo "  APCA_API_SECRET_KEY - Alpaca API secret (required)"
	@echo "  PORT                - Server port (default: 8080)"
	@echo "  DB_PATH             - Database path (default: ./trading_desk.db)"

# Setup - Complete initial setup
setup:
	@echo "Running complete setup..."
	./scripts/setup.sh

# Build everything
build: server strategy-image

# Build Go server
server:
	@echo "Building Go server..."
	./scripts/build_server.sh

# Build strategy Docker image
strategy-image:
	@echo "Building strategy Docker image..."
	./scripts/build_strategy_image.sh

# Generate protobuf code
proto:
	@echo "Generating protobuf code..."
	./scripts/generate_protos.sh

# Run the server
run:
	@echo "Starting server..."
	@if [ -z "$$APCA_API_KEY_ID" ] || [ -z "$$APCA_API_SECRET_KEY" ]; then \
		echo "Error: APCA_API_KEY_ID and APCA_API_SECRET_KEY must be set"; \
		echo "Run: source .env && make run"; \
		exit 1; \
	fi
	./scripts/run_server.sh

# Deploy strategies
deploy:
	@echo "Deploying strategies..."
	./scripts/deploy_strategies.sh start

# Stop strategies
stop:
	@echo "Stopping strategies..."
	./scripts/deploy_strategies.sh stop

# Check strategy status
status:
	@echo "Checking strategy status..."
	./scripts/deploy_strategies.sh status

# Clean built artifacts
clean:
	@echo "Cleaning built artifacts..."
	./scripts/clean.sh

# Clean including Docker
clean-docker: clean
	@echo "Removing Docker containers and images..."
	@docker ps -a --filter "name=strategy-" --format "{{.Names}}" | xargs -r docker rm -f 2>/dev/null || true
	@docker rmi -f trading-desk-strategy 2>/dev/null || true
	@echo "✓ Docker cleanup complete"

# Rebuild everything from scratch
rebuild: clean proto build
	@echo "✓ Rebuild complete"

# Run tests (placeholder for future implementation)
test:
	@echo "Running tests..."
	@echo "Tests not yet implemented"

# Build everything (alias for convenience)
all: build
