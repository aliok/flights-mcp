#!/bin/bash
# Setup environment variables for LLM judge
# This script sets up the environment variables needed for gevals LLM judge
#
# Usage:
#   source scripts/setup-judge-env.sh    # To export to current shell
#   make setup-judge-env                  # To see the values (won't export)

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Check if .env file exists and source it
if [ -f "$PROJECT_ROOT/.env" ]; then
    # Source .env file, but don't export yet (we'll check if vars are set)
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

# Check if environment variables are set (either from .env or already exported)
if [ -z "${JUDGE_BASE_URL:-}" ] || [ -z "${JUDGE_API_KEY:-}" ] || [ -z "${JUDGE_MODEL_NAME:-}" ]; then
    echo "Error: LLM judge environment variables are not set"
    echo ""
    echo "Please set the following environment variables:"
    echo "  JUDGE_BASE_URL - The base URL for the judge API"
    echo "  JUDGE_API_KEY - Your API key for authentication"
    echo "  JUDGE_MODEL_NAME - The model name to use for judging"
    echo ""
    echo "You can either:"
    echo "  1. Create a .env file in the project root (see .env.example)"
    echo "  2. Export them manually:"
    echo "     export JUDGE_BASE_URL=\"your-judge-api-url\""
    echo "     export JUDGE_API_KEY=\"your-api-key\""
    echo "     export JUDGE_MODEL_NAME=\"your-model-name\""
    echo ""
    echo "Note: Judge credentials are sensitive and should never be committed to the repository."
    
    # If script is being sourced, don't exit (just warn)
    if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
        return 1
    else
        exit 1
    fi
fi

# Check if script is being sourced (for exporting) or executed (for displaying)
if [[ "${BASH_SOURCE[0]}" != "${0}" ]]; then
    # Script is being sourced - export variables
    export JUDGE_BASE_URL
    export JUDGE_API_KEY
    export JUDGE_MODEL_NAME
    echo "✓ LLM judge environment variables exported to current shell"
    echo ""
    echo "JUDGE_BASE_URL=$JUDGE_BASE_URL"
    echo "JUDGE_API_KEY=${JUDGE_API_KEY:0:10}..."
    echo "JUDGE_MODEL_NAME=$JUDGE_MODEL_NAME"
else
    # Script is being executed - just display values
    echo "LLM judge environment variables:"
    echo ""
    echo "JUDGE_BASE_URL=$JUDGE_BASE_URL"
    echo "JUDGE_API_KEY=${JUDGE_API_KEY:0:10}..."
    echo "JUDGE_MODEL_NAME=$JUDGE_MODEL_NAME"
    echo ""
    echo "To export these to your current shell, run:"
    echo "  source scripts/setup-judge-env.sh"
    echo ""
    echo "Or set them manually:"
    echo "  export JUDGE_BASE_URL=\"$JUDGE_BASE_URL\""
    echo "  export JUDGE_API_KEY=\"$JUDGE_API_KEY\""
    echo "  export JUDGE_MODEL_NAME=\"$JUDGE_MODEL_NAME\""
fi
