#!/bin/bash

# Function to display the menu
show_menu() {
    echo "========================================"
    echo " SRE Migrate Utils Menu"
    echo "========================================"
    echo "1. Check Endpoints Status & S3 Bucket Permissions"
    echo "2. Check Environment Variables"
    echo "3. Check Database Connections"
    echo "4. Manage ECS Services"
    echo "5. Manage Lambda Functions"
    echo "6. Clone Database"
    echo "7. Exit"
    echo "========================================"
}

# Function to read the user's choice
read_choice() {
    read -p "Enter your choice [1-7]: " choice
    echo $choice
}

# Main script logic
while true; do
    show_menu
    choice=$(read_choice)

    case $choice in
        1)
            check-connections.sh $AWS_S3_BUCKET
            ;;
        2)
            read -p "Enter the SSM path: " ssm_path
            read -p "Do you want to redact the output? (yes/no): " redact
            if [ "$redact" == "yes" ]; then
                check-envs.sh $ssm_path --redact
            else
                check-envs.sh $ssm_path
            fi
            ;;
        3)
            echo "1. Check Process List"
            echo "2. Check Active Connections"
            echo "3. Compare Databases"
            read -p "Enter your choice [1-3]: " db_choice
            case $db_choice in
                1)
                    read -p "Enter DB name: " db_name
                    read -p "Enter username: " user_name
                    read -p "Enter password: " password
                    read -p "Enter DB host name: " db_host_name
                    check-db.sh --process $db_name $user_name $password $db_host_name
                    ;;
                2)
                    read -p "Enter DB name: " db_name
                    read -p "Enter username: " user_name
                    read -p "Enter password: " password
                    read -p "Enter DB host name: " db_host_name
                    check-db.sh --connection $db_name $user_name $password $db_host_name
                    ;;
                3)
                    read -p "Enter DB name: " db_name
                    read -p "Enter username: " user_name
                    read -p "Enter password: " password
                    read -p "Enter source DB host name: " source_host_name
                    read -p "Enter target DB host name: " target_host_name
                    check-db.sh --compare $db_name $user_name $password $source_host_name $target_host_name
                    ;;
                *)
                    echo "Invalid choice."
                    ;;
            esac
            ;;
        4)
            read -p "Enter the ECS cluster name: " cluster_name
            read -p "Enter the number of tasks: " num_tasks
            ecs-utils.sh $cluster_name $num_tasks
            ;;
        5)
            read -p "Enter product name: " product_name
            read -p "Enter concurrent executions (0 to stop, 1 to start): " concurrent_executions
            lambda-utils.sh $product_name $concurrent_executions
            ;;
        6)
            read -p "Enter source cluster name: " source_cluster_name
            read -p "Enter target cluster name: " target_cluster_name
            read -p "Enter target instance name: " target_instance_name
            read -p "Enter target region (default: ap-northeast-1): " target_region
            read -p "Enter DB subnet group name: " db_subnet_group_name
            read -p "Enter VPC security group IDs (space-separated): " vpc_security_group_ids
            db-cloning.sh $source_cluster_name $target_cluster_name $target_instance_name $target_region $db_subnet_group_name $vpc_security_group_ids
            ;;
        7)
            echo "Exiting..."
            exit 0
            ;;
        *)
            echo "Invalid choice. Please select a valid option."
            ;;
    esac
done
