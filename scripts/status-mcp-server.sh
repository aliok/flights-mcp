#!/bin/bash
# Check status of the MCP server

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
PID_FILE="$PROJECT_ROOT/.genmcp/mcp-server.pid"

if [ ! -f "$PID_FILE" ]; then
    echo "MCP server is not running (no PID file found)"
    exit 1
fi

PID=$(cat "$PID_FILE")

if ps -p "$PID" > /dev/null 2>&1; then
    echo "MCP server is running (PID: $PID)"
    exit 0
else
    echo "MCP server is not running (stale PID file)"
    rm -f "$PID_FILE"
    exit 1
fi

