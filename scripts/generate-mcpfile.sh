#!/bin/bash
# Generate mcpfile.yaml and mcpserver.yaml from OpenAPI spec

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENMCP_DIR="$PROJECT_ROOT/.genmcp"
GENMCP_BINARY="$GENMCP_DIR/genmcp"
OPENAPI_JSON="$PROJECT_ROOT/openapi.json"
MCPFILE="$PROJECT_ROOT/mcpfile.yaml"
MCPSERVERFILE="$PROJECT_ROOT/mcpserver.yaml"

# Check if genmcp binary exists
if [ ! -f "$GENMCP_BINARY" ]; then
    echo "Error: gen-mcp binary not found. Run 'make download-genmcp-release' or 'make download-genmcp-nightly' first."
    exit 1
fi

# Default API URL
API_URL="${API_URL:-http://localhost:8000}"

# Check if OpenAPI spec exists, try to fetch if not
if [ ! -f "$OPENAPI_JSON" ]; then
    echo "openapi.json not found. Attempting to fetch from API server..."
    if curl -f -s -o "$OPENAPI_JSON" "$API_URL/openapi.json"; then
        echo "Successfully fetched OpenAPI spec."
    else
        echo "Error: Could not fetch openapi.json. Make sure the API server is running at $API_URL"
        echo "You can fetch it manually with: curl $API_URL/openapi.json > openapi.json"
        exit 1
    fi
fi

echo "Converting OpenAPI spec to mcpfile.yaml and mcpserver.yaml..."
echo "Using base host: $API_URL"
"$GENMCP_BINARY" convert "$OPENAPI_JSON" -f "$MCPFILE" -s "$MCPSERVERFILE" --host "$API_URL"

if [ -f "$MCPFILE" ]; then
    echo "Successfully generated: $MCPFILE"
    echo "Base host URL: $API_URL"
else
    echo "Error: Failed to generate mcpfile.yaml"
    exit 1
fi

if [ -f "$MCPSERVERFILE" ]; then
    echo "Successfully generated: $MCPSERVERFILE"
else
    echo "Error: Failed to generate mcpserver.yaml"
    exit 1
fi

