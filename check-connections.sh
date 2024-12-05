#!/bin/bash

# Function to print a separator
print_separator() {
    echo "========================================"
}

# Function to print a timestamp
print_timestamp() {
    echo "$(date '+%Y-%m-%d %H:%M:%S')"
}

# Function to check specific S3 bucket permissions
check_s3_permissions() {
    local bucket_name=$1
    print_separator
    echo "$(print_timestamp) - Checking permissions for bucket: $bucket_name"

    # Print table header
    printf "%-30s %-10s\n" "Permission" "Result"
    printf "%-30s %-10s\n" "------------------------------" "------"

    # Check if the user has permission to list objects
    if aws s3 ls "s3://$bucket_name" >/dev/null 2>&1; then
        list_result="Yes"
    else
        list_result="No"
    fi
    printf "%-30s %-10s\n" "List objects" "$list_result"

    # Check if the user has permission to put objects
    if echo "test" | aws s3 cp - "s3://$bucket_name/test-file" >/dev/null 2>&1; then
        put_result="Yes"
        # Clean up the test file
        aws s3 rm "s3://$bucket_name/test-file" >/dev/null 2>&1
    else
        put_result="No"
    fi
    printf "%-30s %-10s\n" "Put objects" "$put_result"

    # Check if the user has permission to delete objects
    if aws s3 rm "s3://$bucket_name/non-existent-file" >/dev/null 2>&1; then
        delete_result="Yes"
    else
        delete_result="No"
    fi
    printf "%-30s %-10s\n" "Delete objects" "$delete_result"

    print_separator
}

get_envs_key_value() {
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
            port=${BASH_REMATCH[3]}
            if [[ -z $port ]]; then
                if [[ ${value} =~ ^https:// ]]; then
                    port=443
                elif [[ ${value} =~ ^http:// ]]; then
                    port=80
                fi
            fi

            # Skip if the value has already been processed
            if [[ -n "${seen_values[${host}:${port}]}" ]]; then
                continue
            fi

            # Mark as processed and output the value
            seen_values[${host}:${port}]=1
            echo "${host}:${port}"
        fi
    done
}

check_endpoints() {
    print_separator
    echo "$(print_timestamp) - Checking the connectivity of endpoints..."

    # Print table header
    printf "%-5s %-50s %-10s\n" "No" "Endpoint" "Result"
    printf "%-5s %-50s %-10s\n" "---" "----------------------------------------" "------"

    count=1
    while IFS= read -r endpoint; do
        host=$(echo "$endpoint" | cut -d':' -f1)
        port=$(echo "$endpoint" | cut -d':' -f2)

        if nc -zv "$host" "$port" >/dev/null 2>&1; then
            result="Pass"
        else
            result="Fail"
        fi

        # Split the endpoint into multiple lines if it's too long
        if [[ ${#endpoint} -gt 40 ]]; then
            split_endpoint=$(echo "$endpoint" | fold -s -w 40)
            printf "%-5s %-50s %-10s\n" "$count" "$(echo "$split_endpoint" | head -n 1)" "$result"
            echo "$split_endpoint" | tail -n +2 | while read -r line; do
                printf "%-5s %-50s %-10s\n" "" "$line" ""
            done
        else
            printf "%-5s %-50s %-10s\n" "$count" "$endpoint" "$result"
        fi
        count=$((count + 1))
    done < <(get_envs_key_value)

    print_separator
}

# Run the checks
check_endpoints
check_s3_permissions "$AWS_S3_BUCKET"
