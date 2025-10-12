#!/bin/bash
# Clean up all built artifacts and temporary files

set -e

cd "$(dirname "$0")/.."

echo "Cleaning Trading Desk project..."
echo ""

# Remove binaries
if [ -d "bin" ]; then
    echo "→ Removing binaries (bin/)"
    rm -rf bin/
    echo "  ✓ Removed bin/"
fi

# Remove database files
if ls *.db >/dev/null 2>&1; then
    echo "→ Removing database files (*.db)"
    rm -f *.db *.db-journal
    echo "  ✓ Removed database files"
fi

# Remove Go build cache
echo "→ Cleaning Go build cache"
cd src/server
go clean -cache -testcache -modcache 2>/dev/null || true
cd ../..
echo "  ✓ Cleaned Go cache"

# Remove Python artifacts
echo "→ Removing Python artifacts"
find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
find . -type f -name "*.pyc" -delete 2>/dev/null || true
find . -type f -name "*.pyo" -delete 2>/dev/null || true
find . -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
echo "  ✓ Removed Python artifacts"

# Remove Python virtual environments
if [ -d "src/strategy-env/venv" ]; then
    echo "→ Removing Python virtual environment"
    rm -rf src/strategy-env/venv
    echo "  ✓ Removed venv"
fi

# Remove Docker containers (optional, commented out by default)
# Uncomment to stop and remove all strategy containers
# echo "→ Stopping and removing strategy containers"
# docker ps -a --filter "name=strategy-" --format "{{.Names}}" | xargs -r docker rm -f
# echo "  ✓ Removed strategy containers"

# Remove Docker images (optional, commented out by default)
# Uncomment to remove strategy Docker image
# echo "→ Removing Docker images"
# docker rmi -f trading-desk-strategy 2>/dev/null || true
# echo "  ✓ Removed Docker images"

# Remove OS-specific files
echo "→ Removing OS files"
find . -name ".DS_Store" -delete 2>/dev/null || true
echo "  ✓ Removed .DS_Store files"

echo ""
echo "✓ Cleanup complete!"
echo ""
echo "Note: Docker containers and images were not removed."
echo "To remove them, edit scripts/clean.sh and uncomment the Docker cleanup sections."
