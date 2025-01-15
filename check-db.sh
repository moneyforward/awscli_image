#!/bin/sh
if [ $# -ne 5 ]; then
    echo "Usage: $0 <DB_NAME> <USER_NAME> <PASSWORD> <SOURCE_HOST_NAME> <TARGET_HOST_NAME>"
    exit 1
fi

DB_NAME=$1
USER_NAME=$2
PASSWORD=$3
SOURCE_HOST_NAME=$4
TARGET_HOST_NAME=$5

# Capture start time
START_TIME=$(date +%s)

# Check if the database exists on both hosts
DATABASE_1=$(mysql -u "$USER_NAME" -p"$PASSWORD" -h $SOURCE_HOST_NAME -P 3306 -e "SHOW DATABASES;" 2>/dev/null | grep "^$DB_NAME$")
DATABASE_2=$(mysql -u "$USER_NAME" -p"$PASSWORD" -h $TARGET_HOST_NAME -P 3306 -e "SHOW DATABASES;" 2>/dev/null | grep "^$DB_NAME$")

if [ -z "$DATABASE_1" ] || [ -z "$DATABASE_2" ]; then
    echo "Database not found on one or both hosts or unable to connect to the MySQL server."
    exit 1
fi

echo "====================================================================================================="
echo "Comparing databases: $DB_NAME"
echo "ORIGIN DB: $SOURCE_HOST_NAME"
echo "MIGRATED DB: $TARGET_HOST_NAME"
echo "====================================================================================================="
SOURCE_HOST_NAME_SHORT=$(echo $SOURCE_HOST_NAME | cut -d'.' -f1)
TARGET_HOST_NAME_SHORT=$(echo $TARGET_HOST_NAME | cut -d'.' -f1)

# Function to print text with word wrapping for multiple columns
print_wrapped() {
    local text="$1"
    local width1="$2"
    local width2="$3"
    local width3="$4"
    local wrapped_text=""
    local col1 col2 col3

    while [ ${#text} -gt $((width1 + width2 + width3 + 6)) ]; do
        col1="${text:0:$width1}"
        col2="${text:$width1:$width2}"
        col3="${text:$((width1 + width2)):$width3}"
        wrapped_text="$wrapped_text${col1}\n${col2}\n${col3}\n"
        text="${text:$((width1 + width2 + width3))}"
    done

    col1="${text:0:$width1}"
    col2="${text:$width1:$width2}"
    col3="${text:$((width1 + width2)):$width3}"
    wrapped_text="$wrapped_text${col1}\n${col2}\n${col3}"
    echo -e "$wrapped_text"
}

printf "%-30s | %-20s | %-20s | %-10s\n" "Table Name" "ORIGIN DB" "MIGRATED DB" "Status"
echo "-----------------------------------------------------------------------------------------------------"

# Get the list of tables in the base database on the first host
TABLES=$(mysql -N -B -u "$USER_NAME" -p"$PASSWORD" -h $SOURCE_HOST_NAME -P 3306 -e "SHOW TABLES IN $DB_NAME;" 2>/dev/null)

for TABLE in $TABLES; do
    HOST_1_ROWS=$(mysql -N -B -u "$USER_NAME" -p"$PASSWORD" -h $SOURCE_HOST_NAME -P 3306 -e "SELECT COUNT(*) FROM $DB_NAME.$TABLE;" 2>/dev/null)
    HOST_2_ROWS=$(mysql -N -B -u "$USER_NAME" -p"$PASSWORD" -h $TARGET_HOST_NAME -P 3306 -e "SELECT COUNT(*) FROM $DB_NAME.$TABLE;" 2>/dev/null)
    if [ "$HOST_1_ROWS" -eq "$HOST_2_ROWS" ]; then
        STATUS=$(tput setaf 2)"Consistent"$(tput sgr0)  # Green color
    else
        STATUS=$(tput setaf 1)"Inconsistent"$(tput sgr0)  # Red color
    fi
    TABLE_WRAPPED=$(print_wrapped "$TABLE" 30 20 20)
    while IFS= read -r line; do
        printf "%-30s | %-20s | %-20s | %-10s\n" "$line" "$HOST_1_ROWS rows" "$HOST_2_ROWS rows" "$STATUS"
    done <<< "$TABLE_WRAPPED"
done

# Capture end time
END_TIME=$(date +%s)

# Calculate duration
DURATION=$((END_TIME - START_TIME))
DURATION_MINUTES=$((DURATION / 60))
DURATION_SECONDS=$((DURATION % 60))
echo "Running completed in $DURATION_MINUTES minutes and $DURATION_SECONDS seconds."
