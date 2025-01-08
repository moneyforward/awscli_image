#!/bin/bash

# Check if CLUSTER_NAME and NUMBER_OF_TASK are provided as arguments
if [ -z "$1" ]; then
    echo "Usage: $0 <CLUSTER_NAME> <NUMBER_OF_TASK>"
    exit 1
fi

# Configurable parameters
CLUSTER_NAME="$1"
NUMBER_OF_TASK="$2"

echo "Retrieving services in cluster $CLUSTER_NAME..."
SERVICES=$(aws ecs list-services --cluster "$CLUSTER_NAME" --query "serviceArns[]" --output text)

for SERVICE_ARN in $SERVICES;
do
    SERVICE_NAME=$(echo $SERVICE_ARN | awk -F/ '{print $NF}')
    echo "Scaling ECS service $SERVICE_NAME in cluster $CLUSTER_NAME to $NUMBER_OF_TASK..."
    aws ecs update-service --cluster "$CLUSTER_NAME" --service "$SERVICE_NAME" --desired-count $NUMBER_OF_TASK > /dev/null 2>&1

    if [ $? -eq 0 ]; then
        echo "Successfully scaled ECS service $SERVICE_NAME to $NUMBER_OF_TASK tasks."
    else
        echo "Failed to scale ECS service $SERVICE_NAME."
    fi
done
