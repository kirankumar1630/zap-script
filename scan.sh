#!/bin/bash

# Check if SWAGGER_DOC_URL is set
if [[ -z "$SWAGGER_DOC_URL" ]]; then
  echo "Error: SWAGGER_DOC_URL is not defined. Please set it before running the script."
  exit 1
fi

# Configuration
ZAP_API_KEY="1234"
ZAP_HOST="http://zap-service.zap.svc.cluster.local:8080"
OPENAPI_URL="$SWAGGER_DOC_URL"

# Import OpenAPI definition
import_response=$(curl -s -G "${ZAP_HOST}/JSON/openapi/action/importUrl/" \
  --data-urlencode "url=${OPENAPI_URL}" \
  --data-urlencode "apikey=${ZAP_API_KEY}")

# Log the response from the import action
echo "Import Response: $import_response"  # Added log for debugging

# Check for error in the import response
if [[ $(echo "$import_response" | jq -r '.error') != "null" ]]; then
  echo "Error: Failed to import OpenAPI definition. Response: $import_response"
  exit 1
fi

# Generate JSON report
report=$(curl -s -G "${ZAP_HOST}/OTHER/core/other/jsonreport/" \
  --data-urlencode "apikey=${ZAP_API_KEY}")

# Check if the report is valid JSON
if ! echo "$report" | jq empty >/dev/null 2>&1; then
  echo "Error: Invalid JSON received from ZAP report."
  exit 1
fi

# Modify field names in the report (remove leading '@' from keys)
formatted_report=$(echo "$report" | jq 'with_entries(if .key[0:1] == "@" then .key |= .[1:] else . end)')

# Rename the "generated" field to "createdAt"
formatted_report=$(echo "$formatted_report" | jq 'if has("generated") then .createdAt = .generated | del(.generated) else . end')

# Function to add a random "id" field to JSON
add_id_to_json() {
  local input_json="$1"
  
  # Generate a random alphanumeric ID
  random_id=$(uuidgen | tr -d '-' | head -c 9)

  # Add the "id" field to the JSON using jq
  updated_json=$(echo "$input_json" | jq --arg id "$random_id" '. + {id: $id}')
  
  echo "$updated_json"
}

# Add random ID to the formatted report
updated_json=$(add_id_to_json "$formatted_report")

# Output the final JSON with the added ID
echo "$updated_json"
