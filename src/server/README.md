# Trading Desk Server

Go-based central server for the Quant Club Trading Desk. Acts as the sole intermediary between trading strategies and the Alpaca brokerage API.

## Architecture

The server is built with a clean, modular architecture:

```
server/
├── cmd/
│   └── server/
│       └── main.go              # Application entry point
├── internal/
│   ├── alpaca/
│   │   ├── trade_client.go     # Alpaca API client wrapper
│   │   └── data_client.go      # Data streaming (future)
│   ├── database/
│   │   ├── database.go         # Database operations
│   │   └── schema.sql          # SQLite schema
│   └── protos/
│       └── orders/
│           └── order.pb.go     # Generated protobuf code
├── go.mod                       # Go module dependencies
└── go.sum
```

## Core Components

### 1. HTTP Server (`cmd/server/main.go`)

The main application that:
- Exposes REST API endpoints for strategies
- Handles protobuf-encoded order requests
- Manages database connections
- Validates and logs all operations

**Key Endpoint:**
- `POST /order` - Place a trading order (accepts protobuf `OrderRequest`, returns protobuf `OrderResponse`)

### 2. Alpaca Client (`internal/alpaca/trade_client.go`)

Wrapper around the Alpaca Go SDK that:
- Initializes and validates Alpaca API connection
- Converts protobuf `OrderRequest` to Alpaca `PlaceOrderRequest`
- Handles market, limit, stop, and stop-limit orders
- Manages API credentials securely (never exposed to strategies)

**Key Function:**
```go
func (c *Client) PlaceOrder(orderReq *orderprotos.OrderRequest) (*alpaca.Order, error)
```

### 3. Database Layer (`internal/database/`)

SQLite-based persistence that tracks:
- **Strategies** - User strategies with metadata (name, file path, status)
- **Trades** - Complete trade history with user attribution, order details, prices, and timestamps
- **Positions** - Current holdings per strategy (for future use)

**Key Functions:**
```go
func NewDB(dbPath string) (*DB, error)
func (db *DB) LogTrade(trade *Trade) (int64, error)
func (db *DB) GetTradesByUser(userID string, limit int) ([]Trade, error)
```

### 4. Protocol Buffers (`internal/protos/orders/`)

Generated code from `src/protos/order.proto` defining:
- `OrderRequest` - Incoming order from strategies
- `OrderResponse` - Response with order status and details

## Request Flow

```
1. Python Strategy → HTTP POST (protobuf) → Server
2. Server → Unmarshal protobuf → OrderRequest
3. Server → Extract X-User-ID header
4. Server → Validate request
5. Server → Alpaca Client → Place order with Alpaca API
6. Server → Log trade to database
7. Server → Marshal OrderResponse (protobuf) → Return to strategy
```

## Configuration

The server is configured via environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `APCA_API_KEY_ID` | Alpaca API key | **(required)** |
| `APCA_API_SECRET_KEY` | Alpaca API secret | **(required)** |
| `APCA_API_BASE_URL` | Alpaca API endpoint | `https://paper-api.alpaca.markets` |
| `DB_PATH` | SQLite database path | `./trading_desk.db` |
| `PORT` | Server port | `8080` |

## Building

### Using Scripts (Recommended)

```bash
# From project root
./scripts/build_server.sh
```

### Manual Build

```bash
cd src/server
go build -o ../../bin/trading-desk ./cmd/server
```

## Running

### Using Scripts (Recommended)

```bash
# From project root, with environment variables set
source .env && ./scripts/run_server.sh
```

### Manual Run

```bash
# Set required environment variables
export APCA_API_KEY_ID="your_key"
export APCA_API_SECRET_KEY="your_secret"

# Run the binary
./bin/trading-desk
```

The server will output:
```
Starting Quant Club Trading Desk on http://localhost:8080
Connected to Alpaca API at https://paper-api.alpaca.markets
Database: ./trading_desk.db
Endpoints:
   POST /order - Place a trading order (protobuf)
```

## Development

### Adding a New Endpoint

1. Add handler function in `cmd/server/main.go`:
```go
func (app *Application) handleNewEndpoint(w http.ResponseWriter, r *http.Request) {
    // Implementation
}
```

2. Register in `main()`:
```go
http.HandleFunc("/new-endpoint", app.handleNewEndpoint)
```

### Modifying Protocol Buffers

1. Edit `src/protos/order.proto`
2. Regenerate code:
```bash
./scripts/generate_protos.sh
```
3. Rebuild server:
```bash
./scripts/build_server.sh
```

### Database Schema Changes

1. Update `internal/database/schema.sql`
2. Update `internal/database/database.go` structs and functions
3. Delete existing database or handle migration
4. Rebuild and restart server

## Testing

### Manual Testing with curl

```bash
# Create a protobuf message (requires protoc)
echo '
  symbol: "AAPL"
  qty: "10"
  side: "buy"
  order_type: "market"
  time_in_force: "day"
' | protoc --encode=orders.OrderRequest src/protos/order.proto > request.bin

# Send to server
curl -X POST http://localhost:8080/order \
  -H "Content-Type: application/x-protobuf" \
  -H "X-User-ID: test_user" \
  --data-binary @request.bin \
  --output response.bin

# Decode response
protoc --decode=orders.OrderResponse src/protos/order.proto < response.bin
```

### Testing with Python Client

```bash
# From src/strategy-env/
export DESK_SERVER_URL="http://localhost:8080"
export USER_ID="test_user"

# Send test order
python3 -c "
from desk_client import place_order
response = place_order('AAPL', '10', 'buy', 'market', 'day')
print(f'Status: {response.status}')
print(f'Order ID: {response.order_id}')
"
```

## Security

### API Key Protection
- Alpaca API keys are stored **only** in server environment variables
- Keys are **never** exposed to strategy containers
- Strategies can only place orders through the server

### User Attribution
- Every request requires `X-User-ID` header
- All trades are logged with user ID for audit trails
- Database tracks which user initiated each trade

### Input Validation
- Protobuf enforces type safety
- Server validates all order parameters
- Errors are logged and returned to caller

## Dependencies

- **Go 1.23+** - Programming language
- **alpaca-trade-api-go/v3** - Alpaca API client
- **shopspring/decimal** - Precise decimal arithmetic for prices
- **google.golang.org/protobuf** - Protocol buffers support
- **mattn/go-sqlite3** - SQLite database driver

## Troubleshooting

### Server won't start

**Error: API keys not set**
```bash
# Make sure environment variables are set
echo $APCA_API_KEY_ID
echo $APCA_API_SECRET_KEY
```

**Error: Failed to initialize Alpaca client**
- Check API key validity
- Verify network connectivity
- Check Alpaca API status

### Database errors

**Error: Database locked**
- Close any other processes accessing the database
- Check file permissions

**Error: Failed to initialize schema**
- Delete database file and restart
- Check disk space

### Order placement fails

**Error: Invalid order**
- Check order parameters (qty, side, order_type)
- Verify symbol is valid
- Check market hours for day orders

**Error: Insufficient buying power**
- Check Alpaca account balance
- Reduce order quantity

## Future Enhancements

Planned features:
- [ ] Data streaming component (`internal/alpaca/data_client.go`)
- [ ] WebSocket API for real-time updates
- [ ] Position tracking and P&L calculations
- [ ] Rate limiting per user
- [ ] Strategy lifecycle management API
- [ ] Historical trade analytics
- [ ] Multi-broker support

## References

- [Alpaca API Documentation](https://alpaca.markets/docs/)
- [Protocol Buffers Guide](https://protobuf.dev/)
- [Go SQLite Tutorial](https://github.com/mattn/go-sqlite3)
