#!/bin/bash

# Define your RDS and Redis endpoint details
# RDS_ENDPOINT="your-rds-endpoint.rds.amazonaws.com"
RDS_PORT=3306  # Change this to your RDS port, e.g., 5432 for PostgreSQL or 3306 for MySQL

# REDIS_ENDPOINT="your-redis-endpoint.cache.amazonaws.com"
REDIS_PORT=6379  # Default Redis port

# Function to print a separator
print_separator() {
    echo "========================================"
}

# Function to print a timestamp
print_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

# Function to check RDS network connectivity
check_rds_connection() {
    print_separator
    echo "$(print_timestamp) - Checking RDS network connectivity..."
    if nc -zv "$RDS_ENDPOINT" "$RDS_PORT" >/dev/null 2>&1; then
        echo "$(print_timestamp) - Successfully connected to RDS at $RDS_ENDPOINT on port $RDS_PORT."
    else
        echo "$(print_timestamp) - Failed to connect to RDS at $RDS_ENDPOINT on port $RDS_PORT."
    fi
    print_separator
}

# Function to check Redis network connectivity
check_redis_connection() {
    print_separator
    echo "$(print_timestamp) - Checking Redis network connectivity..."
    if nc -zv "$REDIS_ENDPOINT" "$REDIS_PORT" >/dev/null 2>&1; then
        echo "$(print_timestamp) - Successfully connected to Redis at $REDIS_ENDPOINT on port $REDIS_PORT."
    else
        echo "$(print_timestamp) - Failed to connect to Redis at $REDIS_ENDPOINT on port $REDIS_PORT."
    fi
    print_separator
}

# Function to check specific S3 bucket permissions
check_s3_permissions() {
    print_separator
    echo "$(print_timestamp) - Checking specific permissions for bucket: $AWS_S3_BUCKET"

    # Check if the user has permission to list objects
    if aws s3 ls "s3://$AWS_S3_BUCKET" >/dev/null 2>&1; then
        echo "List objects permission: Yes"
    else
        echo "List objects permission: No"
    fi

    # Check if the user has permission to put objects
    if echo "test" | aws s3 cp - "s3://$AWS_S3_BUCKET/test-file" >/dev/null 2>&1; then
        echo "Put objects permission: Yes"
        # Clean up the test file
        aws s3 rm "s3://$AWS_S3_BUCKET/test-file" >/dev/null 2>&1
    else
        echo "Put objects permission: No"
    fi

    # Check if the user has permission to delete objects
    if aws s3 rm "s3://$AWS_S3_BUCKET/non-existent-file" >/dev/null 2>&1; then
        echo "Delete objects permission: Yes"
    else
        echo "Delete objects permission: No"
    fi

    print_separator
}

list_key_value() {

    print_separator
    
    port_custom=$1
    declare -A seen_values  # Associative array to store already processed values

    for url in $(printenv); do
        # Check for key-value pairs from environment variables
        if [[ $url =~ ^([^=]+)=(.*) ]]; then
            key=${BASH_REMATCH[1]}  
            value=${BASH_REMATCH[2]} 
        else
            continue
        fi

        # Case: URL contains amazonaws.com
        if [[ $value =~ amazonaws\.com ]] && [[ ! $value =~ [^/]+/amazonaws\.com ]] && [[ ! $value =~ amazonaws\.com/[^/]+ ]]; then
            
            # If the value contains @, only take the part after @
            if [[ $value =~ @ ]]; then
                # Ensure the string after @ contains amazonaws.com
                tmp_value=${value##*@}
                if [[ $tmp_value =~ amazonaws\.com ]]; then
                    value=$tmp_value
                else
                    continue  # Skip if the part after @ is invalid
                fi
            fi

            # Skip if the value is too long
            if [[ ${#value} -gt 1000 ]]; then
                continue
            fi

            # Handle adding default ports for specific domains
            if [[ $value =~ rds\.amazonaws\.com$ ]] && [[ ! $value =~ :[0-9]+$ ]]; then
                value="${value}:3306"
            elif [[ $value =~ cache\.amazonaws\.com$ ]] && [[ ! $value =~ :[0-9]+$ ]]; then
                value="${value}:6379"
            fi

            # Skip if the value has already been processed
            if [[ -n "${seen_values[$value]}" ]]; then
                continue
            fi

            # Mark as processed and output the value
            seen_values[$value]=1
            echo "$value"
            continue
        fi

        # Handle URLs that do not contain amazonaws.com
        if [[ $value =~ ^https?://([^:/]+)(:([0-9]+))?(/.*)?$ ]]; then
            host=${BASH_REMATCH[1]}
            if [[ ${value} =~ ^https:// ]]; then
                port=${BASH_REMATCH[3]:-443}  
            elif [[ ${value} =~ ^http:// ]]; then
                port=${BASH_REMATCH[3]:-80}   
            fi 
            echo "${host}:${port}"

        elif [[ $value =~ ^([a-zA-Z0-9.-]+):([0-9]+)$ ]]; then
            host=${BASH_REMATCH[1]}
            port=${BASH_REMATCH[2]:-${port_custom:-0}}
            echo "${host}:${port}"
        fi
    done

    print_separator
}

# Run the checks
list_key_value
check_s3_permissions
check_rds_connection
check_redis_connection
