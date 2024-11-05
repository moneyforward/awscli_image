#!/bin/bash

# Define your RDS and Redis endpoint details
# RDS_ENDPOINT="your-rds-endpoint.rds.amazonaws.com"
RDS_PORT=3306  # Change this to your RDS port, e.g., 5432 for PostgreSQL or 3306 for MySQL

# REDIS_ENDPOINT="your-redis-endpoint.cache.amazonaws.com"
REDIS_PORT=6379  # Default Redis port

# Function to check RDS network connectivity
check_rds_connection() {
    echo "Checking RDS network connectivity..."
    if nc -zv "$RDS_ENDPOINT" "$RDS_PORT" 2>/dev/null; then
        echo "Successfully connected to RDS at $RDS_ENDPOINT on port $RDS_PORT."
    else
        echo "Failed to connect to RDS at $RDS_ENDPOINT on port $RDS_PORT."
    fi
}

# Function to check Redis network connectivity
check_redis_connection() {
    echo "Checking Redis network connectivity..."
    if nc -zv "$REDIS_ENDPOINT" "$REDIS_PORT" 2>/dev/null; then
        echo "Successfully connected to Redis at $REDIS_ENDPOINT on port $REDIS_PORT."
    else
        echo "Failed to connect to Redis at $REDIS_ENDPOINT on port $REDIS_PORT."
    fi
}

# Run the checks
check_rds_connection
check_redis_connection
