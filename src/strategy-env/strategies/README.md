# Strategies Directory

Place your trading strategies here. Each subdirectory represents a strategy and will be deployed as a separate Docker container.

## Directory Structure

Each strategy must be in its own directory with the following structure:

```
strategies/
├── my_strategy/              # Strategy directory (one per strategy)
│   ├── strategy.py          # Required: Your Python strategy code
│   └── config.json          # Optional: Configuration and metadata
└── another_strategy/
    ├── strategy.py
    └── config.json
```

## Required Files

### `strategy.py` (Required)

Your trading strategy implementation. Must read market data from stdin.

**Example:**
```python
#!/usr/bin/env python3
import json
import sys
from desk_client import place_order

def main():
    for line in sys.stdin:
        market_data = json.loads(line.strip())
        # Your trading logic here

if __name__ == "__main__":
    main()
```

### `config.json` (Optional)

Configuration file containing user ID, metadata, and environment variables.

**Example:**
```json
{
  "user_id": "alice",
  "name": "Momentum Trading Strategy",
  "description": "Buys on upward momentum, sells on downward",
  "version": "1.0.0",
  "env": {
    "MOMENTUM_THRESHOLD": "0.05",
    "MAX_POSITION_SIZE": "1000"
  }
}
```

If no `config.json` is provided, the directory name will be used as the user ID.

## Deployment

### Using Bash Script

```bash
# Start all strategies
../deploy_strategies.sh start

# Stop all strategies
../deploy_strategies.sh stop

# Check status
../deploy_strategies.sh status

# Restart all strategies
../deploy_strategies.sh restart
```

### Using Python Manager

```bash
# Start all strategies
../strategy_manager.py start

# Start specific strategy
../strategy_manager.py start alice_momentum/

# Stop all strategies
../strategy_manager.py stop

# Check status
../strategy_manager.py status

# View logs
../strategy_manager.py logs alice_momentum/ --follow
```

## Environment Variables

Set these before running deployment scripts:

- `DESK_SERVER_URL` - Trading desk server URL (default: `http://go-server:8080`)
- `STRATEGIES_DIR` - Directory containing strategies (default: `./strategies`)
- `DOCKER_IMAGE` - Docker image to use (default: `trading-desk-strategy`)
- `NETWORK_NAME` - Docker network name (default: `trading-desk-network`)

Example:
```bash
DESK_SERVER_URL=http://localhost:8080 ../deploy_strategies.sh start
```
