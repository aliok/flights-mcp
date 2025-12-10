#!/usr/bin/env bash
set -euo pipefail

# Script to run gevals evaluation with proper setup checks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}✈️  Flights MCP Evaluation Runner${NC}"
echo ""

# Check if gevals binary exists
GEVALS_BIN="${GEVALS_BIN:-gevals}"
if ! command -v "$GEVALS_BIN" &> /dev/null; then
    echo -e "${RED}❌ Error: gevals binary not found${NC}"
    echo ""
    echo "Please either:"
    echo "  1. Download gevals from: https://github.com/genmcp/gevals/releases"
    echo "  2. Set GEVALS_BIN environment variable to path of gevals binary"
    echo "  3. Add gevals to your PATH"
    exit 1
fi

echo -e "${GREEN}✓${NC} Found gevals: $GEVALS_BIN"
echo ""

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

echo ""
echo -e "${GREEN}Running evaluation...${NC}"
echo ""

# Change to project root to run evaluation
cd "$PROJECT_ROOT"

# Run gevals
"$GEVALS_BIN" eval gevals/eval.yaml "$@"

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

