# TDD: Quant Club Trading Desk

---

# **1. Overview**

This document details the architecture for an automated trading desk that allows club members to develop, deploy, and run their own quantitative trading strategies in a paper trading environment. The system's core is a central server written in **Go**, which manages strategy execution and communicates with the **Alpaca API**. Club members will write their trading logic in **Python** scripts, which will be executed in a secure, isolated environment.

The primary goals are:

- To provide a realistic environment for members to apply quantitative finance concepts.
- To create a modular and extensible system.
- To ensure the system is secure, particularly in how it handles user-submitted code and API keys.

---

# **2. System Architecture**

The system is composed of four main components: the **Central Go Server (The Desk)**, the **Python Strategy Environment**, the **Data Streamer**, and a **Database**.

## **Component Breakdown**

- **Central Go Server ("The Desk")**
    - **Description:** This is the heart of the system. It's a long-running Go application that acts as the sole intermediary between the trading strategies and the Alpaca brokerage.
    - **Responsibilities:**
        - **API Endpoint:** Exposes a simple REST API for Python scripts to send trading orders (e.g., `POST /order`).
        - **Execution Engine:** Receives validated order requests from the API layer. It uses the Alpaca Go SDK (`alpaca-trade-api-go`) to place, monitor, and cancel orders with the Alpaca paper trading API. **Crucially, this server is the only component that holds the Alpaca API keys.**
        - **Strategy Manager:** Manages the lifecycle of user-submitted Python scripts. It will be responsible for starting, stopping, and monitoring these scripts within their secure containers.
        - **Logging:** Records every action, from incoming trade requests to Alpaca API responses and errors.
- **Python Strategy Environment**
    - **Description:** This is where the club member's code runs. To prevent security vulnerabilities from running untrusted code, each user-submitted `.py` file will be executed inside its own isolated **Docker container**.
    - **Interface:**
        - **Input (Market Data):** The strategy script will read market data line-by-line from **standard input (stdin)**. This keeps the script simple and focused on logic.
        - **Output (Trade Signals):** To place a trade, the Python script will make a simple HTTP POST request to the Central Go Server's API endpoint (e.g., `http://go-server:8080/order`). We will provide a small Python helper library to make this easy.
    - **Example `strategy.py` logic:**
    
    ```python
    import json
    import sys
    import requests # or a custom helper library
    
    # Helper function to send an order to the Go server
    def place_order(symbol, qty, side):
        payload = {'symbol': symbol, 'qty': qty, 'side': side}
        requests.post('http://go-server:8080/order', json=payload)
    
    # Main loop to read data from the data streamer
    for line in sys.stdin:
        market_data = json.loads(line) # e.g., {"symbol": "AAPL", "price": 150.25}
    
        # --- Your trading logic goes here ---
        if market_data['price'] < 150.0:
            place_order('AAPL', 10, 'buy')
    ```
    
- **Data Streamer**
    - **Description:** A separate lightweight service (can also be in Go) that connects to the Alpaca real-time data WebSocket.
    - **Responsibilities:**
        - Subscribes to the necessary stock symbols required by all active strategies.
        - Receives data from Alpaca.
        - Forwards the relevant data to the appropriate Python strategy container via its **standard input (stdin)**. This decouples the data feed from the main execution server.
- **Database**
    - **Description:** A simple database to persist important information. **SQLite** is a perfect choice to start with due to its simplicity (it's just a file, no separate server needed).
    - **Schema:**
        - `strategies`: Stores information about each script, like its file path and the user who owns it.
        - `trades`: A log of every trade placed, including symbol, quantity, price, timestamp, and which strategy initiated it.
        - `positions`: A table to keep track of current holdings for each strategy.

## Diagram

![Desk Architecture.png](TDD%20Quant%20Club%20Trading%20Desk%2027102634d41e804584b6ee37a1ee53ce/Desk_Architecture.png)

---

# **3. Networking and Data Flow**

The workflow from a trading decision to execution is as follows:

1. **Deployment:** A club member uploads their `strategy.py` file. The Strategy Manager launches this script inside a new, isolated Docker container.
2. **Data Streaming:** The Data Streamer connects to Alpaca's data feed. As it receives price updates for a stock (e.g., AAPL), it pipes this data as a JSON string into the standard input of every container running a strategy that needs AAPL data.
3. **Signal Generation:** Inside its container, the Python script reads the data from stdin, processes it, and decides to execute a trade.
4. **Internal API Call:** The Python script makes an HTTP POST request to the Central Go Server's `/order` endpoint over the internal Docker network. The request body contains the trade details (e.g., `{"symbol": "AAPL", "qty": 10, "side": "buy"}`).
5. **Secure Execution:** The Go server receives the request. It validates the payload and then uses its securely stored Alpaca API keys to place the paper trade via the Alpaca Go SDK.
6. **Logging:** The result of the trade (accepted, rejected, filled) is received from Alpaca and logged into the SQLite database.

### **Security Considerations**

- **Code Isolation:** Running user code in **Docker containers** is the most important security measure. The container will have a minimal environment and its networking will be restricted so it can *only* communicate with the Go server's API endpoint and nothing else.
- **API Key Management:** The Alpaca API keys will be stored **only** on the Central Go Server (e.g., as environment variables). They will never be exposed to the Python scripts or their containers. This prevents user code from performing unauthorized actions.
- **Resource Limits:** Containers will be configured with strict memory and CPU limits to prevent a poorly written script from crashing the entire system.

---

# **4. Technology Stack Summary**

| Component | Technology/Tool | Rationale |
| --- | --- | --- |
| **Central Server** | Go | Excellent for concurrent, high-performance networking. |
| **Trading Logic** | Python 3 | The standard for data science and quantitative finance. |
| **Brokerage & Data** | Alpaca API | Offers a free, robust paper trading and data API. |
| **Code Isolation** | Docker | The industry standard for secure application sandboxing. |
| **Internal Communication** | REST API (JSON/HTTP) | Simple, stateless, and easy to implement/debug. |
| **Database** | SQLite | Extremely simple to set up and perfect for this scale. |