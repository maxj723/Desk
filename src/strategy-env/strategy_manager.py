#!/usr/bin/env python3
"""
Strategy Manager - Python-based management tool for trading strategies

Provides a more flexible alternative to the bash script with better
logging, error handling, and integration with the database.
"""

import argparse
import json
import os
import subprocess
import sys
from pathlib import Path
from typing import List, Dict, Optional


class StrategyManager:
    def __init__(
        self,
        strategies_dir: str = "./strategies",
        server_url: str = "http://go-server:8080",
        docker_image: str = "trading-desk-strategy",
        network_name: str = "trading-desk-network"
    ):
        self.strategies_dir = Path(strategies_dir)
        self.server_url = server_url
        self.docker_image = docker_image
        self.network_name = network_name

    def _run_command(self, cmd: List[str], capture_output=True) -> subprocess.CompletedProcess:
        """Run a shell command and return the result."""
        return subprocess.run(
            cmd,
            capture_output=capture_output,
            text=True,
            check=False
        )

    def ensure_network(self) -> None:
        """Ensure Docker network exists."""
        result = self._run_command(["docker", "network", "inspect", self.network_name])
        if result.returncode != 0:
            print(f"Creating Docker network: {self.network_name}")
            self._run_command(["docker", "network", "create", self.network_name])

    def get_container_name(self, strategy_dir: Path) -> str:
        """Generate container name from strategy directory name."""
        return f"strategy-{strategy_dir.name}"

    def get_config(self, strategy_dir: Path) -> Dict[str, any]:
        """Get config from config.json file."""
        config_file = strategy_dir / "config.json"
        if config_file.exists():
            return json.loads(config_file.read_text())
        return {}

    def get_user_id(self, strategy_dir: Path) -> str:
        """Get user ID for a strategy from config.json or directory name."""
        config = self.get_config(strategy_dir)
        return config.get("user_id", strategy_dir.name)

    def is_running(self, container_name: str) -> bool:
        """Check if a container is running."""
        result = self._run_command(["docker", "ps", "--format", "{{.Names}}"])
        return container_name in result.stdout.split("\n")

    def start_strategy(self, strategy_dir: Path) -> bool:
        """Start a single strategy container."""
        container_name = self.get_container_name(strategy_dir)
        user_id = self.get_user_id(strategy_dir)
        config = self.get_config(strategy_dir)
        strategy_file = strategy_dir / "strategy.py"

        # Check if strategy.py exists
        if not strategy_file.exists():
            print(f"✗ No strategy.py found in {strategy_dir}")
            return False

        if self.is_running(container_name):
            print(f"⚠ Strategy {container_name} is already running")
            return False

        print(f"▶ Starting strategy: {container_name} (user: {user_id})")

        # Build docker run command
        cmd = [
            "docker", "run", "-d",
            "--name", container_name,
            "--network", self.network_name,
            "--restart", "unless-stopped",
            "-e", f"DESK_SERVER_URL={self.server_url}",
            "-e", f"USER_ID={user_id}",
            "-v", f"{strategy_dir.absolute()}:/app/strategy:ro",
        ]

        # Add any additional environment variables from config
        for key, value in config.get("env", {}).items():
            cmd.extend(["-e", f"{key}={value}"])

        # Add image and command
        cmd.extend([self.docker_image, "python", "-u", "/app/strategy/strategy.py"])

        result = self._run_command(cmd)
        if result.returncode == 0:
            print(f"✓ Started {container_name}")
            return True
        else:
            print(f"✗ Failed to start {container_name}: {result.stderr}")
            return False

    def stop_strategy(self, strategy_dir: Path) -> bool:
        """Stop a single strategy container."""
        container_name = self.get_container_name(strategy_dir)

        if not self.is_running(container_name):
            print(f"⚠ Strategy {container_name} is not running")
            return False

        print(f"■ Stopping strategy: {container_name}")

        # Stop and remove container
        self._run_command(["docker", "stop", container_name])
        self._run_command(["docker", "rm", container_name])

        print(f"✓ Stopped {container_name}")
        return True

    def restart_strategy(self, strategy_dir: Path) -> bool:
        """Restart a single strategy container."""
        self.stop_strategy(strategy_dir)
        import time
        time.sleep(1)
        return self.start_strategy(strategy_dir)

    def status_strategy(self, strategy_dir: Path) -> Dict[str, str]:
        """Get status of a single strategy."""
        container_name = self.get_container_name(strategy_dir)

        if self.is_running(container_name):
            # Get detailed status
            result = self._run_command([
                "docker", "inspect", "-f",
                "{{.State.Status}}|{{.State.Running}}|{{.State.StartedAt}}",
                container_name
            ])
            status, running, started = result.stdout.strip().split("|")
            return {
                "name": container_name,
                "status": "running",
                "details": status,
                "started_at": started
            }
        else:
            # Check if container exists but stopped
            result = self._run_command(["docker", "ps", "-a", "--format", "{{.Names}}"])
            if container_name in result.stdout:
                return {"name": container_name, "status": "stopped"}
            else:
                return {"name": container_name, "status": "not_deployed"}

    def print_status(self, status: Dict[str, str]) -> None:
        """Pretty print strategy status."""
        name = status["name"]
        state = status["status"]

        if state == "running":
            print(f"● {name} - {status['details']} (started: {status['started_at'][:19]})")
        elif state == "stopped":
            print(f"○ {name} - stopped")
        else:
            print(f"◌ {name} - not deployed")

    def logs_strategy(self, strategy_dir: Path, follow: bool = False, tail: int = 100) -> None:
        """Show logs for a strategy."""
        container_name = self.get_container_name(strategy_dir)

        cmd = ["docker", "logs"]
        if follow:
            cmd.append("-f")
        cmd.extend(["--tail", str(tail), container_name])

        subprocess.run(cmd)

    def get_all_strategies(self) -> List[Path]:
        """Get all strategy directories in the strategies directory."""
        if not self.strategies_dir.exists():
            print(f"Error: Strategies directory not found: {self.strategies_dir}")
            return []

        # Find all directories containing strategy.py
        strategies = []
        for item in self.strategies_dir.iterdir():
            if item.is_dir() and (item / "strategy.py").exists():
                strategies.append(item)

        return sorted(strategies)

    def process_all(self, action: str) -> None:
        """Process all strategies in the directory."""
        strategies = self.get_all_strategies()

        if not strategies:
            print(f"⚠ No strategy directories with strategy.py found in {self.strategies_dir}")
            return

        print(f"Found {len(strategies)} strategy directory(s) in {self.strategies_dir}")
        print()

        for strategy in strategies:
            if action == "start":
                self.start_strategy(strategy)
            elif action == "stop":
                self.stop_strategy(strategy)
            elif action == "restart":
                self.restart_strategy(strategy)
            elif action == "status":
                status = self.status_strategy(strategy)
                self.print_status(status)


def main():
    parser = argparse.ArgumentParser(
        description="Manage trading strategy deployments"
    )
    parser.add_argument(
        "command",
        choices=["start", "stop", "restart", "status", "logs"],
        help="Command to execute"
    )
    parser.add_argument(
        "strategy",
        nargs="?",
        help="Specific strategy directory to operate on (optional, operates on all if not specified)"
    )
    parser.add_argument(
        "--strategies-dir",
        default=os.getenv("STRATEGIES_DIR", "./strategies"),
        help="Directory containing strategy files"
    )
    parser.add_argument(
        "--server-url",
        default=os.getenv("DESK_SERVER_URL", "http://go-server:8080"),
        help="Trading desk server URL"
    )
    parser.add_argument(
        "--follow", "-f",
        action="store_true",
        help="Follow logs (for logs command)"
    )
    parser.add_argument(
        "--tail",
        type=int,
        default=100,
        help="Number of log lines to show (for logs command)"
    )

    args = parser.parse_args()

    manager = StrategyManager(
        strategies_dir=args.strategies_dir,
        server_url=args.server_url
    )

    manager.ensure_network()

    # Handle specific strategy or all strategies
    if args.strategy:
        strategy_path = Path(args.strategy)
        if not strategy_path.exists():
            print(f"Error: Strategy directory not found: {strategy_path}")
            sys.exit(1)

        if not strategy_path.is_dir():
            print(f"Error: {strategy_path} is not a directory")
            sys.exit(1)

        if not (strategy_path / "strategy.py").exists():
            print(f"Error: No strategy.py found in {strategy_path}")
            sys.exit(1)

        if args.command == "logs":
            manager.logs_strategy(strategy_path, follow=args.follow, tail=args.tail)
        elif args.command == "start":
            manager.start_strategy(strategy_path)
        elif args.command == "stop":
            manager.stop_strategy(strategy_path)
        elif args.command == "restart":
            manager.restart_strategy(strategy_path)
        elif args.command == "status":
            status = manager.status_strategy(strategy_path)
            manager.print_status(status)
    else:
        if args.command == "logs":
            print("Error: Please specify a strategy directory for logs command")
            sys.exit(1)

        manager.process_all(args.command)


if __name__ == "__main__":
    main()
