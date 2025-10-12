#!/bin/bash

# Deploy and manage multiple trading strategies
# Usage: ./deploy_strategies.sh [start|stop|restart|status] [strategies_dir]

set -e

# Configuration
STRATEGIES_DIR="${2:-./strategies}"
DESK_SERVER_URL="${DESK_SERVER_URL:-http://go-server:8080}"
DOCKER_IMAGE="${DOCKER_IMAGE:-trading-desk-strategy}"
NETWORK_NAME="${NETWORK_NAME:-trading-desk-network}"
DATA_STREAMER_URL="${DATA_STREAMER_URL:-tcp://data-streamer:5555}"

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if Docker network exists, create if not
ensure_network() {
    if ! docker network inspect "$NETWORK_NAME" >/dev/null 2>&1; then
        log_info "Creating Docker network: $NETWORK_NAME"
        docker network create "$NETWORK_NAME"
    fi
}

# Get container name for a strategy directory
get_container_name() {
    local strategy_dir="$1"
    local basename=$(basename "$strategy_dir")
    echo "strategy-${basename}"
}

# Get user ID from config.json
get_user_id() {
    local strategy_dir="$1"
    local config_file="${strategy_dir}/config.json"

    if [ -f "$config_file" ]; then
        # Extract user_id from JSON using basic grep/sed
        local user_id=$(grep -o '"user_id"[[:space:]]*:[[:space:]]*"[^"]*"' "$config_file" | sed 's/.*"user_id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/')
        if [ -n "$user_id" ]; then
            echo "$user_id"
            return
        fi
    fi

    # Default to directory name
    basename "$strategy_dir"
}

# Get environment variables from config.json
get_env_vars() {
    local strategy_dir="$1"
    local config_file="${strategy_dir}/config.json"

    if [ -f "$config_file" ] && command -v jq >/dev/null 2>&1; then
        # Use jq if available to extract env vars
        jq -r '.env // {} | to_entries[] | "-e \(.key)=\(.value)"' "$config_file" 2>/dev/null || echo ""
    fi
}

# Start a single strategy
start_strategy() {
    local strategy_dir="$1"
    local container_name=$(get_container_name "$strategy_dir")
    local user_id=$(get_user_id "$strategy_dir")
    local strategy_file="${strategy_dir}/strategy.py"

    # Check if strategy.py exists
    if [ ! -f "$strategy_file" ]; then
        log_error "No strategy.py found in $strategy_dir"
        return 1
    fi

    # Check if already running
    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_warn "Strategy $container_name is already running"
        return 0
    fi

    log_info "Starting strategy: $container_name (user: $user_id)"

    # Build docker command with base options
    local docker_cmd="docker run -d \
        --name $container_name \
        --network $NETWORK_NAME \
        --restart unless-stopped \
        -e DESK_SERVER_URL=$DESK_SERVER_URL \
        -e USER_ID=$user_id \
        -e DATA_STREAMER_URL=$DATA_STREAMER_URL"

    # Add environment variables from config.json
    local env_vars=$(get_env_vars "$strategy_dir")
    if [ -n "$env_vars" ]; then
        docker_cmd="$docker_cmd $env_vars"
    fi

    # Mount the entire strategy directory (for potential additional files)
    docker_cmd="$docker_cmd \
        -v $(realpath "$strategy_dir"):/app/strategy:ro \
        $DOCKER_IMAGE \
        python -u /app/strategy/strategy.py"

    # Execute the command
    eval $docker_cmd

    log_info "Started $container_name"
}

# Stop a single strategy
stop_strategy() {
    local strategy_dir="$1"
    local container_name=$(get_container_name "$strategy_dir")

    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        log_info "Stopping strategy: $container_name"
        docker stop "$container_name" >/dev/null
        docker rm "$container_name" >/dev/null
        log_info "Stopped $container_name"
    else
        log_warn "Strategy $container_name is not running"
    fi
}

# Get status of a single strategy
status_strategy() {
    local strategy_dir="$1"
    local container_name=$(get_container_name "$strategy_dir")

    if docker ps --format '{{.Names}}' | grep -q "^${container_name}$"; then
        local status=$(docker inspect -f '{{.State.Status}}' "$container_name")
        echo -e "${GREEN}●${NC} $container_name - $status"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${container_name}$"; then
        echo -e "${RED}●${NC} $container_name - stopped"
    else
        echo -e "${YELLOW}●${NC} $container_name - not deployed"
    fi
}

# Process all strategies in directory
process_all_strategies() {
    local action="$1"

    if [ ! -d "$STRATEGIES_DIR" ]; then
        log_error "Strategies directory not found: $STRATEGIES_DIR"
        exit 1
    fi

    # Find all directories containing strategy.py
    local strategies=()
    for dir in "$STRATEGIES_DIR"/*; do
        if [ -d "$dir" ] && [ -f "$dir/strategy.py" ]; then
            strategies+=("$dir")
        fi
    done

    if [ ${#strategies[@]} -eq 0 ]; then
        log_warn "No strategy directories with strategy.py found in $STRATEGIES_DIR"
        exit 0
    fi

    log_info "Found ${#strategies[@]} strategy directory(s) in $STRATEGIES_DIR"

    for strategy in "${strategies[@]}"; do
        case "$action" in
            start)
                start_strategy "$strategy"
                ;;
            stop)
                stop_strategy "$strategy"
                ;;
            restart)
                stop_strategy "$strategy"
                sleep 1
                start_strategy "$strategy"
                ;;
            status)
                status_strategy "$strategy"
                ;;
        esac
    done
}

# Show usage
usage() {
    cat <<EOF
Usage: $0 [COMMAND] [STRATEGIES_DIR]

Commands:
    start       Start all strategies in the directory
    stop        Stop all running strategies
    restart     Restart all strategies
    status      Show status of all strategies

Arguments:
    STRATEGIES_DIR    Directory containing strategy subdirectories (default: ./strategies)
                      Each subdirectory should contain a strategy.py file

Environment Variables:
    DESK_SERVER_URL   URL of the trading desk server (default: http://go-server:8080)
    DOCKER_IMAGE      Docker image to use (default: trading-desk-strategy)
    NETWORK_NAME      Docker network name (default: trading-desk-network)

Examples:
    $0 start ./my-strategies
    $0 status
    DESK_SERVER_URL=http://localhost:8080 $0 start
EOF
}

# Main
main() {
    local command="${1:-status}"

    case "$command" in
        start|stop|restart|status)
            ensure_network
            process_all_strategies "$command"
            ;;
        help|--help|-h)
            usage
            ;;
        *)
            log_error "Unknown command: $command"
            usage
            exit 1
            ;;
    esac
}

main "$@"
