#!/usr/bin/env python3
"""
Example strategy for Bob - Mean Reversion
"""

import json
import sys
from desk_client import place_order


def main():
    print("Bob's mean reversion strategy started")

    prices = {}  # Track price history

    for line in sys.stdin:
        try:
            market_data = json.loads(line.strip())
            symbol = market_data.get("symbol")
            price = market_data.get("price")

            if not symbol or price is None:
                continue

            # Track prices
            if symbol not in prices:
                prices[symbol] = []
            prices[symbol].append(price)

            # Keep last 10 prices
            if len(prices[symbol]) > 10:
                prices[symbol].pop(0)

            print(f"Received: {symbol} @ ${price}")

            # Simple mean reversion: buy if price is below recent average
            if len(prices[symbol]) >= 5:
                avg = sum(prices[symbol]) / len(prices[symbol])
                if price < avg * 0.98:  # 2% below average
                    print(f"Price ${price} is below average ${avg:.2f}, buying...")
                    response = place_order(
                        symbol=symbol,
                        qty="3",
                        side="buy",
                        order_type="limit",
                        time_in_force="day",
                        limit_price=str(price + 0.10)
                    )

                    if response.status == "success":
                        print(f"✓ Limit order placed: {response.order_id}")

        except Exception as e:
            print(f"Error: {e}", file=sys.stderr)


if __name__ == "__main__":
    main()
