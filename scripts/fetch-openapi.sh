#!/bin/bash
# Fetch OpenAPI spec from running API server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OPENAPI_JSON="$PROJECT_ROOT/openapi.json"
API_URL="${API_URL:-http://localhost:8000}"

echo "Fetching OpenAPI spec from $API_URL/openapi.json..."

if curl -f -s -o "$OPENAPI_JSON" "$API_URL/openapi.json"; then
    echo "Successfully fetched OpenAPI spec to: $OPENAPI_JSON"
else
    echo "Error: Failed to fetch OpenAPI spec. Is the API server running at $API_URL?"
    exit 1
fi

