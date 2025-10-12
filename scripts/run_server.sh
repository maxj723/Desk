#!/bin/bash
# Run the trading desk server with environment variables

set -e

cd "$(dirname "$0")/.."

# Check if binary exists
if [ ! -f "bin/trading-desk" ]; then
    echo "Server binary not found. Building..."
    ./scripts/build_server.sh
fi

# Set default environment variables if not set
export APCA_API_KEY_ID="${APCA_API_KEY_ID:-}"
export APCA_API_SECRET_KEY="${APCA_API_SECRET_KEY:-}"
export APCA_API_BASE_URL="${APCA_API_BASE_URL:-https://paper-api.alpaca.markets}"
export DB_PATH="${DB_PATH:-./trading_desk.db}"
export PORT="${PORT:-8080}"

# Check required variables
if [ -z "$APCA_API_KEY_ID" ] || [ -z "$APCA_API_SECRET_KEY" ]; then
    echo "Error: APCA_API_KEY_ID and APCA_API_SECRET_KEY must be set"
    echo ""
    echo "Usage:"
    echo "  APCA_API_KEY_ID=your_key APCA_API_SECRET_KEY=your_secret ./scripts/run_server.sh"
    echo ""
    echo "Or create a .env file and source it:"
    echo "  source .env && ./scripts/run_server.sh"
    exit 1
fi

echo "Starting Trading Desk server..."
echo "  Server URL: http://localhost:${PORT}"
echo "  Alpaca API: ${APCA_API_BASE_URL}"
echo "  Database: ${DB_PATH}"
echo ""

./bin/trading-desk
