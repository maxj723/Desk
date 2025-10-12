# Strategy Environment

Python environment for running trading strategies on the Quant Club Trading Desk.

## Structure

```
strategy-env/
├── desk_client/              # Helper library for communicating with the server
│   ├── __init__.py
│   ├── client.py            # Main client functions
│   └── order_pb2.py         # Generated protobuf code
├── examples/                # Example strategies
│   ├── simple_strategy.py
│   └── limit_order_strategy.py
├── strategies/              # User strategies (each in its own directory)
│   ├── example_alice/
│   │   ├── strategy.py
│   │   └── config.json
│   └── example_bob/
│       ├── strategy.py
│       └── config.json
├── deploy_strategies.sh    # Bash deployment script
├── strategy_manager.py     # Python deployment manager
├── requirements.txt        # Python dependencies
├── Dockerfile             # Container image for strategies
└── README.md             # This file
```

## Local Development

### Setup

1. Create and activate virtual environment:
```bash
python3 -m venv venv
source venv/bin/activate
```

2. Install dependencies:
```bash
pip install -r requirements.txt
```

3. Install the desk_client library in development mode:
```bash
pip install -e .
```

### Running a Strategy Locally

Start the Go server first, then run a strategy:

```bash
# Set environment variables
export DESK_SERVER_URL="http://localhost:8080"
export USER_ID="your_username"

# Run a strategy with simulated market data
echo '{"symbol": "AAPL", "price": 145.50}' | python examples/simple_strategy.py
```

## Docker Usage

### Build the Image

```bash
docker build -t trading-desk-strategy .
```

### Run a Strategy Container

```bash
docker run -e DESK_SERVER_URL=http://go-server:8080 -e USER_ID=trader1 trading-desk-strategy
```

### Run with Custom Strategy

Mount your strategy file:

```bash
docker run -v /path/to/your_strategy.py:/app/strategy.py \
  -e DESK_SERVER_URL=http://go-server:8080 \
  -e USER_ID=your_username \
  trading-desk-strategy python strategy.py
```

## Writing a Strategy

### Basic Template

```python
#!/usr/bin/env python3
import json
import sys
from desk_client import place_order, set_user_id

def main():
    set_user_id("your_username")

    for line in sys.stdin:
        market_data = json.loads(line)
        symbol = market_data["symbol"]
        price = market_data["price"]

        # Your trading logic here
        if should_buy(symbol, price):
            response = place_order(
                symbol=symbol,
                qty="10",
                side="buy",
                order_type="market",
                time_in_force="day"
            )

            if response.status == "success":
                print(f"Order placed: {response.order_id}")

if __name__ == "__main__":
    main()
```

### API Reference

#### `place_order()`

```python
place_order(
    symbol: str,              # Stock symbol (e.g., "AAPL")
    qty: str,                 # Quantity (e.g., "10")
    side: str,                # "buy" or "sell"
    order_type: str,          # "market", "limit", "stop", "stop_limit"
    time_in_force: str,       # "day", "gtc", "ioc", "fok"
    limit_price: str = None,  # For limit orders
    stop_price: str = None,   # For stop orders
    timeout: int = 10         # Request timeout in seconds
) -> OrderResponse
```

#### `set_user_id()`

```python
set_user_id(user_id: str)
```

Sets the user ID for all subsequent order requests.

## Environment Variables

- `DESK_SERVER_URL`: URL of the trading desk server (default: `http://localhost:8080`)
- `USER_ID`: Your user identifier (default: `default_user`)

## Deployment

### Quick Start

From the project root:

```bash
# Build the strategy Docker image
./scripts/build_strategy_image.sh

# Deploy all strategies
./scripts/deploy_strategies.sh start

# Check status
./scripts/deploy_strategies.sh status

# Stop all strategies
./scripts/deploy_strategies.sh stop
```

### Deployment Tools

You have two options for deploying strategies:

#### Option 1: Bash Script (Simple)

```bash
# From project root
./scripts/deploy_strategies.sh start    # Start all strategies
./scripts/deploy_strategies.sh stop     # Stop all strategies
./scripts/deploy_strategies.sh restart  # Restart all strategies
./scripts/deploy_strategies.sh status   # Check status
```

**Pros:** No dependencies, simple, works anywhere
**Cons:** All-or-nothing (operates on all strategies at once)

#### Option 2: Python Manager (Advanced)

```bash
# From src/strategy-env/
./strategy_manager.py start                              # Start all
./strategy_manager.py start strategies/example_alice/    # Start specific
./strategy_manager.py stop                               # Stop all
./strategy_manager.py status                             # Check status
./strategy_manager.py logs strategies/example_alice/ -f  # View logs
```

**Pros:** Per-strategy control, log viewing, detailed status
**Cons:** Requires Python 3

### Strategy Directory Structure

Each strategy must be in its own directory:

```
strategies/
├── my_strategy/              # Strategy directory
│   ├── strategy.py          # Required: Your strategy code
│   └── config.json          # Optional: Configuration
└── another_strategy/
    ├── strategy.py
    └── config.json
```

#### Example `strategy.py`

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

        # Your trading logic
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

#### Example `config.json`

```json
{
  "user_id": "alice",
  "name": "My Trading Strategy",
  "description": "Buys when price drops below threshold",
  "version": "1.0.0",
  "env": {
    "THRESHOLD": "150.0",
    "MAX_POSITION": "1000"
  }
}
```

If no `config.json` is provided, the directory name is used as the user ID.

### Configuration

Set environment variables to customize deployment:

```bash
# Server URL (for local testing)
export DESK_SERVER_URL="http://localhost:8080"

# Custom strategies directory
export STRATEGIES_DIR="./my-strategies"

# Custom Docker image
export DOCKER_IMAGE="my-strategy-image"

# Deploy
./scripts/deploy_strategies.sh start
```

### Container Naming

Containers are named based on the directory name:
- `strategies/example_alice/` → `strategy-example_alice`
- `strategies/my_momentum/` → `strategy-my_momentum`

### Viewing Logs

**Using bash script:**
```bash
docker logs -f strategy-example_alice
```

**Using Python manager:**
```bash
./strategy_manager.py logs strategies/example_alice/ --follow
./strategy_manager.py logs strategies/example_alice/ --tail 50
```

### Troubleshooting

#### Strategy won't start

1. Check if container already exists:
```bash
docker ps -a | grep strategy-
```

2. Remove old container:
```bash
docker rm -f strategy-example_alice
```

3. Check logs:
```bash
docker logs strategy-example_alice
```

#### Can't connect to server

1. Verify Docker network:
```bash
docker network inspect trading-desk-network
```

2. Check server is on same network:
```bash
docker ps --filter network=trading-desk-network
```

3. Test connectivity:
```bash
docker run --network trading-desk-network alpine ping go-server
```

### Best Practices

1. **Test locally first** - Run strategy outside Docker before deploying
2. **Use meaningful names** - Name directories descriptively (e.g., `alice_momentum`)
3. **Always add config.json** - Explicitly specify user IDs and metadata
4. **Version your strategies** - Use git or include version in config
5. **Monitor logs** - Regularly check strategy logs for errors
6. **Gradual deployment** - Test with one strategy before deploying many

### Production Considerations

For production deployments, consider:

**Resource limits:**
```bash
# Add to docker run command
--memory="512m" --cpus="0.5"
```

**Logging driver:**
```bash
--log-driver json-file --log-opt max-size=10m --log-opt max-file=3
```

**Health checks** in Dockerfile:
```dockerfile
HEALTHCHECK --interval=30s --timeout=3s \
  CMD python -c "import sys; sys.exit(0)"
```

## Security Notes

- Strategies run in isolated Docker containers
- No direct access to Alpaca API keys
- Network access limited to the Desk server
- Resource limits enforced by Docker
- Each strategy runs with its own user attribution
