#!/bin/bash
PREFIX=""

while getopts n:p: flag
do
    case "${flag}" in
        n) APP_NAME=${OPTARG};;
        p) PREFIX=${OPTARG};;
    esac
done

usage() {
  echo "Usage: $0 -n <APP_NAME> (-p <PREFIX>)"
  echo " <APP_NAME> must be inputed."
  echo " <PREFIX> is optional."
  exit 1;
}

if [ -z "$APP_NAME" ]; then
    usage
fi

################### FUNCTIONS ###################
function vault_get_keys() {
  # get keys from env of container
  env | grep "^${PREFIX}" | cut -d '=' -f 1 | sed 's/^/"/;s/$/"/'
}

function ssm_get_path() {
  AWS_REGION="ap-northeast-1" # Tokyo region
  params=$(aws ssm get-parameters-by-path --path /$APP_NAME --region $AWS_REGION --with-decryption | jq -r ".Parameters[] | select(.Name | startswith(\"/$APP_NAME/${PREFIX}\")) | .Name")
  echo "total:" $(wc -l <<< "$params")
  echo "$params" | tr ' ' '\n' | cut -d '/' -f 3 | sed 's/^/"/;s/$/"/'

  SSM_VARS=($(echo $params | tr ' ' '\n' | cut -d '/' -f 3 | sed 's/^/"/;s/$/"/'))

  VAULT_VARS=($(vault_get_keys))
  echo "compare ssm and vault..."
  for expected_var in "${SSM_VARS[@]}"; do
    found=false
    for vault_var in "${VAULT_VARS[@]}"; do
        if [[ "$expected_var" == "$vault_var" ]]; then
            found=true
            break
        fi
    done
    if [[ "$found" == false ]]; then
        echo "Missing: $expected_var"
    fi
  done
}

ssm_get_path
