#!/bin/bash
# Wrapper script to deploy strategies from the root directory

set -e

cd "$(dirname "$0")/.."

# Forward all arguments to the actual deployment script
exec src/strategy-env/deploy_strategies.sh "$@" src/strategy-env/strategies
