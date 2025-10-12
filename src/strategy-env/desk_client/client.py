"""
Client library for communicating with the Trading Desk server.
Handles protobuf serialization and HTTP requests.
"""

import os
import requests
from typing import Optional

from .order_pb2 import OrderRequest, OrderResponse


# Global configuration
_server_url = os.getenv("DESK_SERVER_URL", "http://localhost:8080")
_user_id = os.getenv("USER_ID", "default_user")


def set_user_id(user_id: str) -> None:
    """Set the user ID for all subsequent requests."""
    global _user_id
    _user_id = user_id


def get_server_url() -> str:
    """Get the current server URL."""
    return _server_url


def place_order(
    symbol: str,
    qty: str,
    side: str,
    order_type: str = "market",
    time_in_force: str = "day",
    limit_price: Optional[str] = None,
    stop_price: Optional[str] = None,
    timeout: int = 10
) -> OrderResponse:
    """
    Place a trading order with the Desk server.

    Args:
        symbol: Stock symbol (e.g., "AAPL")
        qty: Quantity as string (e.g., "10" or "10.5")
        side: "buy" or "sell"
        order_type: "market", "limit", "stop", or "stop_limit"
        time_in_force: "day", "gtc", "ioc", or "fok"
        limit_price: Optional limit price for limit orders
        stop_price: Optional stop price for stop orders
        timeout: Request timeout in seconds

    Returns:
        OrderResponse: Protobuf response from the server

    Raises:
        requests.exceptions.RequestException: If the request fails
        ValueError: If the response cannot be parsed
    """
    # Create protobuf request
    order_req = OrderRequest(
        symbol=symbol,
        qty=qty,
        side=side,
        order_type=order_type,
        time_in_force=time_in_force
    )

    if limit_price:
        order_req.limit_price = limit_price
    if stop_price:
        order_req.stop_price = stop_price

    # Serialize to protobuf
    request_data = order_req.SerializeToString()

    # Make HTTP POST request
    headers = {
        "Content-Type": "application/x-protobuf",
        "X-User-ID": _user_id
    }

    response = requests.post(
        f"{_server_url}/order",
        data=request_data,
        headers=headers,
        timeout=timeout
    )

    # Parse protobuf response
    order_resp = OrderResponse()
    order_resp.ParseFromString(response.content)

    # Log the response
    if order_resp.status == "success":
        print(f"✓ Order placed: {order_resp.order_id} - {order_resp.symbol} {order_resp.qty} {order_resp.side}")
    else:
        print(f"✗ Order failed: {order_resp.message}")

    return order_resp
