#!/usr/bin/env python3
"""
Example strategy for Alice - Momentum Trading
"""

import json
import sys
from desk_client import place_order


def main():
    print("Alice's momentum strategy started")

    for line in sys.stdin:
        try:
            market_data = json.loads(line.strip())
            symbol = market_data.get("symbol")
            price = market_data.get("price")

            if not symbol or price is None:
                continue

            print(f"Received: {symbol} @ ${price}")

            # Simple momentum logic
            if symbol == "AAPL" and price < 145.0:
                print(f"Price ${price} looks good, placing buy order...")
                response = place_order(
                    symbol="AAPL",
                    qty="5",
                    side="buy",
                    order_type="market",
                    time_in_force="day"
                )

                if response.status == "success":
                    print(f"✓ Order placed: {response.order_id}")
                else:
                    print(f"✗ Order failed: {response.message}")

        except json.JSONDecodeError as e:
            print(f"Failed to parse JSON: {e}", file=sys.stderr)
        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
