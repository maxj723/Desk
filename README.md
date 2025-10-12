# Quant Club Trading Desk

Automated paper trading desk for quantitative trading strategies. Allows club members to develop, deploy, and run their own trading strategies in an isolated environment.

## Architecture

- **Go Server** - Central trading desk that communicates with Alpaca API
- **Python Strategies** - User trading strategies running in isolated Docker containers
- **Protocol Buffers** - Efficient communication between strategies and server
- **SQLite Database** - Trade history and strategy management

## Quick Start

### 1. Setup

**Using Makefile (recommended):**
```bash
make setup
```

**Or using scripts directly:**
```bash
./scripts/setup.sh
```

This will:
- Check dependencies (Go, Docker, Python, protoc)
- Generate protobuf code
- Build the Go server
- Build the strategy Docker image

### 2. Configure API Credentials

```bash
# Copy example environment file
cp .env.example .env

# Edit .env with your Alpaca API credentials
```

### 3. Start the Server

**Using Makefile:**
```bash
source .env && make run
```

**Or using scripts:**
```bash
source .env && ./scripts/run_server.sh
```

The server will start on `http://localhost:8080`

### 4. Deploy Strategies

**Using Makefile:**
```bash
make deploy    # Deploy all strategies
make status    # Check status
make stop      # Stop all strategies
```

**Or using scripts:**
```bash
./scripts/deploy_strategies.sh start
./scripts/deploy_strategies.sh status
./scripts/deploy_strategies.sh stop
```

## Project Structure

```
Desk/
├── src/
│   ├── server/              # Go trading desk server
│   │   ├── cmd/server/      # Main server entry point
│   │   ├── internal/        # Server implementation
│   │   ├── go.mod
│   │   └── README.md
│   ├── strategy-env/        # Python strategy environment
│   │   ├── desk_client/     # Python client library
│   │   ├── examples/        # Example strategies
│   │   ├── strategies/      # User strategies go here
│   │   ├── Dockerfile       # Strategy container image
│   │   ├── deploy_strategies.sh
│   │   ├── strategy_manager.py
│   │   └── README.md
│   └── protos/              # Protocol buffer definitions
│       └── order.proto
├── scripts/                 # Build and deployment scripts
│   ├── setup.sh            # Complete setup
│   ├── build_server.sh     # Build Go server
│   ├── build_strategy_image.sh
│   ├── generate_protos.sh  # Generate protobuf code
│   ├── run_server.sh       # Run server
│   ├── deploy_strategies.sh
│   └── clean.sh            # Clean artifacts
├── bin/                     # Compiled binaries (gitignored)
├── docs/                    # Documentation
├── Makefile                # Build automation
├── .env.example            # Example environment variables
├── .gitignore              # Git ignore rules
└── README.md
```

## Writing a Strategy

### 1. Create Strategy Directory

```bash
mkdir -p src/strategy-env/strategies/my_strategy
cd src/strategy-env/strategies/my_strategy
```

### 2. Create `strategy.py`

```python
#!/usr/bin/env python3
import json
import sys
from desk_client import place_order

def main():
    for line in sys.stdin:
        market_data = json.loads(line.strip())
        symbol = market_data.get("symbol")
        price = market_data.get("price")

        # Your trading logic here
        if price < 150.0:
            response = place_order(
                symbol=symbol,
                qty="10",
                side="buy",
                order_type="market",
                time_in_force="day"
            )

if __name__ == "__main__":
    main()
```

### 3. Create `config.json`

```json
{
  "user_id": "your_username",
  "name": "My Trading Strategy",
  "description": "Strategy description",
  "version": "1.0.0",
  "env": {
    "CUSTOM_VAR": "value"
  }
}
```

### 4. Deploy

```bash
./scripts/deploy_strategies.sh start
```

## Available Commands

### Makefile Commands

| Command | Description |
|---------|-------------|
| `make setup` | Complete initial setup |
| `make build` | Build server and strategy image |
| `make server` | Build Go server only |
| `make strategy-image` | Build strategy Docker image only |
| `make proto` | Generate protobuf code |
| `make run` | Start the trading desk server |
| `make deploy` | Deploy all strategies |
| `make stop` | Stop all strategies |
| `make status` | Check strategy status |
| `make clean` | Remove all built artifacts |
| `make clean-docker` | Clean + remove Docker containers/images |
| `make rebuild` | Clean, regenerate protos, and rebuild |
| `make help` | Show all available commands |

### Scripts (Direct Access)

| Script | Description |
|--------|-------------|
| `scripts/setup.sh` | Complete initial setup |
| `scripts/build_server.sh` | Build Go server binary |
| `scripts/build_strategy_image.sh` | Build Docker image for strategies |
| `scripts/generate_protos.sh` | Generate protobuf code |
| `scripts/run_server.sh` | Run the trading desk server |
| `scripts/deploy_strategies.sh` | Deploy/manage strategies |
| `scripts/clean.sh` | Clean built artifacts |

## Documentation

- **[Technical Design Document](docs/TDD%20Quant%20Club%20Trading%20Desk.md)** - Complete architecture documentation
- **[Strategy Environment README](src/strategy-env/README.md)** - Strategy development and deployment guide

## Development

### Rebuild After Changes

**Using Makefile:**
```bash
# Rebuild server after Go code changes
make server

# Regenerate protobufs and rebuild everything after .proto changes
make rebuild

# Rebuild strategy image after Python library changes
make strategy-image
```

**Or using scripts:**
```bash
# Rebuild server after Go code changes
./scripts/build_server.sh

# Regenerate protobufs after .proto changes
./scripts/generate_protos.sh
./scripts/build_server.sh
./scripts/build_strategy_image.sh

# Rebuild strategy image after Python library changes
./scripts/build_strategy_image.sh
```

### Manual Commands

```bash
# Build server manually
cd src/server
go build -o ../../bin/trading-desk ./cmd/server

# Build strategy image manually
docker build -t trading-desk-strategy src/strategy-env/

# Run server with custom config
DB_PATH=./custom.db PORT=3000 ./bin/trading-desk
```

## Requirements

- Go 1.23+
- Docker
- Python 3.8+
- Protocol Buffers compiler (protoc)
