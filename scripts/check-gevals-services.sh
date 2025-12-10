#!/bin/bash
# Check if required services are running for gevals

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "Checking services required for gevals evaluation..."
echo ""

# Check API server
echo -n "API server (http://localhost:8000): "
if curl -s http://localhost:8000/api/health > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
    echo "  Start with: python main.py"
fi

# Check MCP server
echo -n "MCP server (http://localhost:8080): "
if curl -s http://localhost:8080/mcp > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Running${NC}"
else
    echo -e "${RED}✗ Not running${NC}"
    echo "  Start with: make start-mcp-server"
fi

# Check gevals binary
GEVALS_DIR="$PROJECT_ROOT/.gevals"
GEVALS_BINARY=""
if [ -n "${GEVALS_BIN:-}" ]; then
    GEVALS_BINARY="$GEVALS_BIN"
elif command -v gevals &> /dev/null; then
    GEVALS_BINARY="gevals (in PATH)"
elif [ -f "$GEVALS_DIR/gevals" ] && [ -x "$GEVALS_DIR/gevals" ]; then
    GEVALS_BINARY="$GEVALS_DIR/gevals"
fi

echo -n "gevals binary: "
if [ -n "$GEVALS_BINARY" ]; then
    echo -e "${GREEN}✓ Found${NC}"
    echo "  Location: $GEVALS_BINARY"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Download with: make download-gevals-release"
fi

# Check eval config
EVAL_CONFIG="$PROJECT_ROOT/gevals/eval.yaml"
echo -n "Evaluation config: "
if [ -f "$EVAL_CONFIG" ]; then
    echo -e "${GREEN}✓ Found${NC}"
    echo "  Location: $EVAL_CONFIG"
else
    echo -e "${RED}✗ Not found${NC}"
    echo "  Expected: $EVAL_CONFIG"
fi

# Check LLM judge environment variables
echo -n "LLM judge config: "
if [ -n "${JUDGE_BASE_URL:-}" ] && [ -n "${JUDGE_API_KEY:-}" ] && [ -n "${JUDGE_MODEL_NAME:-}" ]; then
    echo -e "${GREEN}✓ Configured${NC}"
    echo "  Model: ${JUDGE_MODEL_NAME}"
    echo "  Base URL: ${JUDGE_BASE_URL}"
else
    echo -e "${YELLOW}⚠ Not configured${NC}"
    echo "  Setup with: source scripts/setup-judge-env.sh"
    echo "  Or: make setup-judge-env"
fi

echo ""

