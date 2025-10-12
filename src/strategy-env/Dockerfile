# Dockerfile for Python strategy environment
FROM python:3.13-slim

# Set working directory
WORKDIR /app

# Copy requirements and install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy the desk_client library
COPY desk_client/ /app/desk_client/

# Copy user strategy (will be overridden when mounting specific strategies)
COPY examples/ /app/examples/

# Set environment variables
ENV PYTHONUNBUFFERED=1
ENV DESK_SERVER_URL=http://go-server:8080
ENV USER_ID=default_user

# Default command (can be overridden)
CMD ["python", "-u", "examples/simple_strategy.py"]
