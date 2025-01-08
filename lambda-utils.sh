#!/bin/bash

# Check if PRODUCT_NAME is provided as an argument
if [[ -z "$1" || -z "$2" ]]; then
    echo "Usage: $0 <PRODUCT_NAME> <CONCURRENT_EXECUTIONS>"
    echo "Examples:"
    echo "$0 <PRODUCT_NAME> 0 for stop lambda function of mfv-infra"
    echo "$0 <PRODUCT_NAME> 1 for start lambda function of mfv-infra "
    echo "$0 <PRODUCT_NAME>-sp 0 for stop lambda function of service-platform"
    echo "$0 <PRODUCT_NAME>-sp 1 for start lambda function of service-platform"
    exit 1
fi

# Configurable parameters
PRODUCT_NAME="$1"
CONCURRENT_EXECUTIONS=$2

# Determine if PRODUCT_NAME ends with -sp
if [[ $PRODUCT_NAME == *-sp ]]; then
    PRODUCT_NAME="${PRODUCT_NAME%-sp}"
fi

functions=$(aws lambda list-functions --query 'Functions[*].FunctionName' --output text)
for function in $functions; do
    if [[ $function == *$PRODUCT_NAME* ]]; then
        if [[ $1 == *-sp && $function == *-sp* ]] || [[ $1 != *-sp && $function != *-sp* ]]; then
            if [ "$CONCURRENT_EXECUTIONS" -eq 0 ]; then
                aws lambda put-function-concurrency --function-name $function --reserved-concurrent-executions $CONCURRENT_EXECUTIONS > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    echo "Successfully updated concurrency for function: $function to 0"
                else
                    echo "Failed to update concurrency for function: $function to 0"
                fi
            else
                aws lambda delete-function-concurrency --function-name $function > /dev/null 2>&1
                if [ $? -eq 0 ]; then
                    echo "Successfully reverted concurrency for function: $function to default"
                else
                    echo "Failed to revert concurrency for function: $function to default"
                fi
            fi
        fi
    fi
done
