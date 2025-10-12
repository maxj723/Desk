#!/bin/bash
# Generate protobuf code for Go and Python

set -e

cd "$(dirname "$0")/.."

echo "Generating protobuf code..."

# Check if protoc is installed
if ! command -v protoc &> /dev/null; then
    echo "Error: protoc not found. Install with: brew install protobuf"
    exit 1
fi

# Check if protoc-gen-go is installed
if ! command -v protoc-gen-go &> /dev/null; then
    echo "Installing protoc-gen-go..."
    go install google.golang.org/protobuf/cmd/protoc-gen-go@latest
fi

# Generate Go protobuf code
echo "→ Generating Go protobuf code..."
mkdir -p src/server/internal/protos/orders
protoc --go_out=src/server/internal/protos/orders \
    --go_opt=paths=source_relative \
    --proto_path=src/protos \
    src/protos/order.proto

echo "✓ Go protobuf code generated"

# Generate Python protobuf code
echo "→ Generating Python protobuf code..."
mkdir -p src/strategy-env/desk_client
protoc --python_out=src/strategy-env/desk_client \
    --proto_path=src/protos \
    src/protos/order.proto

echo "✓ Python protobuf code generated"
echo "✓ All protobuf code generated successfully"
