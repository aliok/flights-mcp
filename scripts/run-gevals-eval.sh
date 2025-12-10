#!/bin/bash
# Run gevals evaluation

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GEVALS_DIR="$PROJECT_ROOT/.gevals"
EVAL_CONFIG="$PROJECT_ROOT/gevals/eval.yaml"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Find gevals binary (check PATH first, then local .gevals directory)
if [ -n "${GEVALS_BIN:-}" ]; then
    # Use explicitly set GEVALS_BIN environment variable
    GEVALS_BINARY="$GEVALS_BIN"
elif command -v gevals &> /dev/null; then
    # Use gevals from PATH
    GEVALS_BINARY="gevals"
elif [ -f "$GEVALS_DIR/gevals" ] && [ -x "$GEVALS_DIR/gevals" ]; then
    # Use local .gevals directory binary
    GEVALS_BINARY="$GEVALS_DIR/gevals"
else
    echo -e "${RED}Error: gevals binary not found.${NC}"
    echo ""
    echo "Please either:"
    echo "  1. Run 'make download-gevals-release' or 'make download-gevals-nightly'"
    echo "  2. Install gevals and add it to your PATH"
    echo "  3. Set GEVALS_BIN environment variable to path of gevals binary"
    exit 1
fi

echo -e "${GREEN}✓${NC} Using gevals: $GEVALS_BINARY"

# Check if eval config exists
if [ ! -f "$EVAL_CONFIG" ]; then
    echo -e "${RED}Error: Evaluation config not found: $EVAL_CONFIG${NC}"
    exit 1
fi

# Check if API server is running
echo "Checking API server..."
if ! curl -s http://localhost:8000/api/health > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Warning: API server not responding on http://localhost:8000${NC}"
    echo "   Start it with: python main.py"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} API server is running"
fi

# Check if MCP server is running
echo "Checking MCP server..."
if ! curl -s http://localhost:8080/mcp > /dev/null 2>&1; then
    echo -e "${YELLOW}⚠️  Warning: MCP server not responding on http://localhost:8080${NC}"
    echo "   Start it with: make start-mcp-server"
    echo ""
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} MCP server is running"
fi

# Check if LLM judge environment variables are set
echo "Checking LLM judge configuration..."
if [ -z "${JUDGE_BASE_URL:-}" ] || [ -z "${JUDGE_API_KEY:-}" ] || [ -z "${JUDGE_MODEL_NAME:-}" ]; then
    echo -e "${YELLOW}⚠️  Warning: LLM judge environment variables not set${NC}"
    echo "   Set them with: source scripts/setup-judge-env.sh"
    echo "   Or manually:"
    echo "     export JUDGE_BASE_URL=\"...\""
    echo "     export JUDGE_API_KEY=\"...\""
    echo "     export JUDGE_MODEL_NAME=\"...\""
    echo ""
    echo "   Without LLM judge, verification will use simple text matching."
    echo ""
    read -p "Continue without LLM judge? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
else
    echo -e "${GREEN}✓${NC} LLM judge configured"
    echo "   Model: ${JUDGE_MODEL_NAME}"
    echo "   Base URL: ${JUDGE_BASE_URL}"
fi

echo ""
echo -e "${GREEN}Running evaluation...${NC}"
echo ""

# Change to project root to run evaluation
cd "$PROJECT_ROOT"

# Run gevals with any additional arguments passed to this script
"$GEVALS_BINARY" eval "$EVAL_CONFIG" "$@"

EXIT_CODE=$?

echo ""
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✓ Evaluation completed successfully${NC}"
    
    # Find results file
    RESULTS_FILE=$(ls -t gevals-*-out.json 2>/dev/null | head -1 || echo "")
    if [ -n "$RESULTS_FILE" ]; then
        echo ""
        echo "Results saved to: $RESULTS_FILE"
        echo ""
        echo "View results:"
        echo "  cat $RESULTS_FILE | jq"
    fi
else
    echo -e "${RED}❌ Evaluation failed with exit code $EXIT_CODE${NC}"
fi

exit $EXIT_CODE

