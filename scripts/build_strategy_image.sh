#!/bin/bash
# Build the Docker image for strategy environment

set -e

cd "$(dirname "$0")/.."

IMAGE_NAME="${1:-trading-desk-strategy}"
IMAGE_TAG="${2:-latest}"

echo "Building strategy environment Docker image: ${IMAGE_NAME}:${IMAGE_TAG}"
docker build -t "${IMAGE_NAME}:${IMAGE_TAG}" src/strategy-env/

echo "✓ Docker image built successfully: ${IMAGE_NAME}:${IMAGE_TAG}"
