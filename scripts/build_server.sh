#!/bin/bash
# Build the Go trading desk server

set -e

cd "$(dirname "$0")/.."

echo "Building Trading Desk server..."
cd src/server
go build -o ../../bin/trading-desk ./cmd/server

echo "✓ Server built successfully at bin/trading-desk"
