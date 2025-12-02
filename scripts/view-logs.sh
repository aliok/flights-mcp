#!/bin/bash
# View logs from API server and MCP server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
API_LOG="$PROJECT_ROOT/api-server.log"
MCP_LOG="$PROJECT_ROOT/.genmcp/mcp-server.log"

echo "=== API Server Logs ==="
if [ -f "$API_LOG" ]; then
    tail -n 50 "$API_LOG"
else
    echo "No API server log file found"
fi

echo ""
echo "=== MCP Server Logs ==="
if [ -f "$MCP_LOG" ]; then
    tail -n 50 "$MCP_LOG"
else
    echo "No MCP server log file found"
fi

echo ""
echo "To follow logs in real-time:"
echo "  tail -f $API_LOG"
echo "  tail -f $MCP_LOG"

