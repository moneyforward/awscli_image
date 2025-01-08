#!/bin/bash

# Input base JSON file and output file
SSM_JSON_PATH="/tmp/ssm.json"
VAULT_JSON_PATH="/tmp/vault.json"
UPDATED_VAULT_JSON_PATH="/tmp/updated_vault.json"

# Check if vault.json exists
if [ ! -f "$VAULT_JSON_PATH" ]; then
    echo "Error: $VAULT_JSON_PATH does not exist. Please create this file by copying the content from Vault."
    exit 1
fi

# Check if SSM_PATH is provided as an argument
if [ -z "$1" ]; then
    echo "Usage: $0 <SSM_PATH>"
    exit 1
fi

# Configurable parameters
SSM_PATH="$1"

# Fetch and decrypt SSM parameters
echo "Fetching and decrypting SSM parameters..."
SSM_PARAMS=$(aws ssm get-parameters-by-path \
    --path "$SSM_PATH" \
    --recursive \
    --with-decryption \
    --query 'Parameters[*].[Name,Value]' \
    --output json)

if [ $? -ne 0 ]; then
    echo "Failed to fetch SSM parameters. Please check your permissions."
    exit 1
fi

# Convert SSM parameters into key-value format using only the last part of the SSM key
echo "Processing SSM parameters..."
SSM_JSON=$(echo "$SSM_PARAMS" | jq -r '
    map({(.[0] | split("/") | last): .[1]}) | add
')

# Save processed SSM JSON to a temporary file
echo "$SSM_JSON" > "$SSM_JSON_PATH"

# Compare the original and updated JSON files to find differences
echo "Comparing SSM and Vault JSON files..."
jq --slurpfile a "$VAULT_JSON_PATH" --slurpfile b "$SSM_JSON_PATH" -n '
    $a[0] as $a | $b[0] as $b |
    reduce ($b | to_entries[]) as $item ($a;
        if $a[$item.key] == null then .[$item.key] = $item.value else . end
    )
' > "$UPDATED_VAULT_JSON_PATH"

echo "Outputting differences..."
jq --slurpfile a "$VAULT_JSON_PATH" --slurpfile b "$SSM_JSON_PATH" -n '
    $a[0] as $a | $b[0] as $b |
    reduce ($b | to_entries[]) as $item ({};
        if $a[$item.key] == null then .[$item.key] = $item.value else . end
    )
'

# Inform the user about the updated vault JSON file
echo "You can view the revised version of the vault JSON by running: cat $UPDATED_VAULT_JSON_PATH"

# Cleanup temporary files
rm -f "$SSM_JSON_PATH"
