#!/bin/bash

# Check if PRODUCT_NAME is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <PRODUCT_NAME>"
    exit 1
fi

# Configurable parameters
PRODUCT_NAME="$1"

functions=$(aws lambda list-functions --query 'Functions[*].FunctionName' --output text)
for function in $functions; do
    if [[ $function == *$PRODUCT_NAME* && $function != *-sp* ]]; then
        aws lambda put-function-concurrency --function-name $function --reserved-concurrent-executions 0  > /dev/null 2>&1
        if [ $? -eq 0 ]; then
            echo "Successfully updated concurrency for function: $function to 0"
        else
            echo "Failed to update concurrency for function: $function to 0"
        fi
    fi
done
