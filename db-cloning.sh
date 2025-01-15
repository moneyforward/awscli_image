#!/bin/bash

# Assign parameters to variables
SOURCE_CLUSTER_NAME=$1
TARGET_CLUSTER_NAME=$2
TARGET_INSTANCE_NAME=$3
TARGET_REGION=${4:-ap-northeast-1}  # Default region if not provided
DB_SUBNET_GROUP_NAME=$5
shift 5
VPC_SECURITY_GROUP_IDS=("$@")

# Check if all required parameters are provided
if [ -z "$SOURCE_CLUSTER_NAME" ] || [ -z "$TARGET_CLUSTER_NAME" ] || [ -z "$TARGET_INSTANCE_NAME" ] || [ -z "$DB_SUBNET_GROUP_NAME" ] || [ ${#VPC_SECURITY_GROUP_IDS[@]} -eq 0 ]; then
    echo "Usage: $0 <source-cluster-name> <target-cluster-name> <target-instance-name> [<target-region>] <db-subnet-group-name> <vpc-security-group-ids...>"
    exit 1
fi

# Helper function for error handling
function error_exit {
    echo "$1" >&2
    exit 1
}

# Capture start time
START_TIME=$(date +%s)

# Step 1: Clone the primary Aurora cluster
echo "Cloning Aurora cluster from $SOURCE_CLUSTER_NAME to $TARGET_CLUSTER_NAME..."
CLONE_STATUS=$(aws rds restore-db-cluster-to-point-in-time \
    --source-db-cluster-identifier "$SOURCE_CLUSTER_NAME" \
    --db-cluster-identifier "$TARGET_CLUSTER_NAME" \
    --restore-type copy-on-write \
    --deletion-protection \
    --use-latest-restorable-time \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --vpc-security-group-ids "${VPC_SECURITY_GROUP_IDS[@]}" \
    --region "$TARGET_REGION" 2>&1)

if [ $? -ne 0 ]; then
    error_exit "Failed to initiate the cloning process: $CLONE_STATUS"
fi

echo "Aurora cluster cloning initiated successfully."

# Step 2: Wait for the cloned cluster to become available
echo "Waiting for the new Aurora cluster to become available..."
aws rds wait db-cluster-available --db-cluster-identifier "$TARGET_CLUSTER_NAME" --region "$TARGET_REGION"

if [ $? -ne 0 ]; then
    error_exit "The new Aurora cluster did not become available in time."
fi

echo "The new Aurora cluster $TARGET_CLUSTER_NAME is available."

# Step 3: Retrieve the number of replicas and instance class from the source cluster
echo "Retrieving replica count and instance class for source cluster $SOURCE_CLUSTER_NAME..."
REPLICA_INFO=$(aws rds describe-db-instances \
    --region "$TARGET_REGION" \
    --query "DBInstances[?DBClusterIdentifier=='$SOURCE_CLUSTER_NAME'].[DBInstanceIdentifier,DBInstanceClass]" \
    --output text)

if [ $? -ne 0 ] || [ -z "$REPLICA_INFO" ]; then
    error_exit "Failed to retrieve replica information or no replicas found."
fi

REPLICA_COUNT=$(echo "$REPLICA_INFO" | wc -l)
INSTANCE_CLASS=$(echo "$REPLICA_INFO" | head -n 1 | awk '{print $2}')

echo "Source cluster has $REPLICA_COUNT replicas with instance class $INSTANCE_CLASS."

# Step 4: Create replicas for the cloned cluster
for i in $(seq 1 "$REPLICA_COUNT"); do
    REPLICA_NAME="${TARGET_INSTANCE_NAME}-$i"
    echo "Creating replica $i: $REPLICA_NAME..."

    aws rds create-db-instance \
        --db-instance-identifier "$REPLICA_NAME" \
        --db-instance-class "$INSTANCE_CLASS" \
        --engine aurora-mysql \
        --db-cluster-identifier "$TARGET_CLUSTER_NAME" \
        --region "$TARGET_REGION" \
        --no-cli-pager 2>&1

    if [ $? -ne 0 ]; then
        error_exit "Failed to create replica $REPLICA_NAME."
    fi

    echo "Waiting for replica $REPLICA_NAME to become available..."
    aws rds wait db-instance-available --db-instance-identifier "$REPLICA_NAME" --region "$TARGET_REGION"

    if [ $? -ne 0 ]; then
        error_exit "Replica $REPLICA_NAME did not become available in time."
    fi
done

echo "All replicas have been created and are available."

# Capture end time
END_TIME=$(date +%s)

# Calculate duration
DURATION=$((END_TIME - START_TIME))
DURATION_MINUTES=$((DURATION / 60))
DURATION_SECONDS=$((DURATION % 60))
echo "Cloning process completed in $DURATION_MINUTES minutes and $DURATION_SECONDS seconds."
