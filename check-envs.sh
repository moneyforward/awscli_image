#!/bin/bash

# Input base JSON file and output file
SSM_JSON_PATH="/tmp/ssm.json"
VAULT_JSON_PATH="/tmp/vault.json"
UPDATED_VAULT_JSON_PATH="/tmp/updated_vault.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if vault.json exists
if [ ! -f "$VAULT_JSON_PATH" ]; then
    echo -e "${RED}Error: $VAULT_JSON_PATH does not exist. Please create this file by copying the content from Vault.${NC}"
    exit 1
fi

# Check if SSM_PATH is provided as an argument
if [ -z "$1" ]; then
    echo -e "${YELLOW}Usage: $0 <SSM_PATH> [--redact]${NC}"
    exit 1
fi

# Configurable parameters
SSM_PATH="$1"
REDACT=false

# Check for --redact option
if [ "$2" == "--redact" ]; then
    REDACT=true
fi

# Fetch and decrypt SSM parameters
echo -e "${GREEN}Fetching and decrypting SSM parameters...${NC}"
SSM_PARAMS=$(aws ssm get-parameters-by-path \
    --path "$SSM_PATH" \
    --recursive \
    --with-decryption \
    --query 'Parameters[*].[Name,Value]' \
    --output json)

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to fetch SSM parameters. Please check your permissions.${NC}"
    exit 1
fi

# Convert SSM parameters into key-value format using only the last part of the SSM key
echo -e "${GREEN}Processing SSM parameters...${NC}"
SSM_JSON=$(echo "$SSM_PARAMS" | jq -r '
    map({(.[0] | split("/") | last): .[1]}) | add
')

# Save processed SSM JSON to a temporary file
echo "$SSM_JSON" > "$SSM_JSON_PATH"

# Compare the original and updated JSON files to find differences
echo -e "${GREEN}Comparing SSM and Vault JSON files...${NC}"
jq --slurpfile a "$VAULT_JSON_PATH" --slurpfile b "$SSM_JSON_PATH" -n '
    $a[0] as $a | $b[0] as $b |
    reduce ($b | to_entries[]) as $item ($a;
        if $a[$item.key] == null then .[$item.key] = $item.value else . end
    )
' > "$UPDATED_VAULT_JSON_PATH"

# Output differences with optional redaction
echo -e "${YELLOW}Missing ENV KEY in Vault...${NC}"
if [ "$REDACT" = true ]; then
    jq --slurpfile a "$VAULT_JSON_PATH" --slurpfile b "$SSM_JSON_PATH" -n '
        $a[0] as $a | $b[0] as $b |
        reduce ($b | to_entries[]) as $item ({};
            if $a[$item.key] == null then .[$item.key] = ($item.value | sub("(?<=.{3}).(?=.{3})"; "*"; "g")) else . end
        )
    '
else
    jq --slurpfile a "$VAULT_JSON_PATH" --slurpfile b "$SSM_JSON_PATH" -n '
        $a[0] as $a | $b[0] as $b |
        reduce ($b | to_entries[]) as $item ({};
            if $a[$item.key] == null then .[$item.key] = $item.value else . end
        )
    '
fi

# Add boundary line
echo -e "${YELLOW}----------------------------------------${NC}"

# Output keys with different values between SSM and Vault
echo -e "${YELLOW}ENV KEY with different values between SSM and Vault...${NC}"
jq --slurpfile a "$VAULT_JSON_PATH" --slurpfile b "$SSM_JSON_PATH" -n '
    $a[0] as $a | $b[0] as $b |
    reduce ($b | to_entries[]) as $item ({};
        if $a[$item.key] != null and $a[$item.key] != $item.value then .[$item.key] = {vault: $a[$item.key], ssm: $item.value} else . end
    )
'

# Inform the user about the updated vault JSON file
echo -e "${GREEN}You can view the revised version of the vault JSON by running: cat $UPDATED_VAULT_JSON_PATH${NC}"

# Cleanup temporary files
rm -f "$SSM_JSON_PATH"
