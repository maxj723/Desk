#!/bin/bash
# Complete setup script for the Trading Desk

set -e

cd "$(dirname "$0")/.."

echo "======================================"
echo "Trading Desk Setup"
echo "======================================"
echo ""

# Check dependencies
echo "→ Checking dependencies..."

if ! command -v go &> /dev/null; then
    echo "✗ Go not found. Please install Go 1.23 or later"
    exit 1
fi
echo "✓ Go found: $(go version)"

if ! command -v docker &> /dev/null; then
    echo "✗ Docker not found. Please install Docker"
    exit 1
fi
echo "✓ Docker found"

if ! command -v protoc &> /dev/null; then
    echo "⚠ protoc not found. Installing via Homebrew..."
    brew install protobuf
fi
echo "✓ protoc found"

if ! command -v python3 &> /dev/null; then
    echo "✗ Python 3 not found. Please install Python 3.8+"
    exit 1
fi
echo "✓ Python 3 found: $(python3 --version)"

echo ""
echo "→ Generating protobuf code..."
./scripts/generate_protos.sh

echo ""
echo "→ Installing Go dependencies..."
cd src/server
go mod download
cd ../..

echo ""
echo "→ Building Go server..."
./scripts/build_server.sh

echo ""
echo "→ Building strategy Docker image..."
./scripts/build_strategy_image.sh

echo ""
echo "======================================"
echo "✓ Setup complete!"
echo "======================================"
echo ""
echo "Next steps:"
echo "  1. Set your Alpaca API credentials:"
echo "     export APCA_API_KEY_ID=your_key"
echo "     export APCA_API_SECRET_KEY=your_secret"
echo ""
echo "  2. Start the server:"
echo "     ./scripts/run_server.sh"
echo ""
echo "  3. Deploy strategies:"
echo "     ./scripts/deploy_strategies.sh start"
echo ""
