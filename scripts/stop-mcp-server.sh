#!/bin/bash
# Stop the MCP server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENMCP_DIR="$PROJECT_ROOT/.genmcp"
GENMCP_BINARY="$GENMCP_DIR/genmcp"
PID_FILE="$PROJECT_ROOT/.genmcp/mcp-server.pid"

# Check if PID file exists
if [ ! -f "$PID_FILE" ]; then
    echo "MCP server is not running (no PID file found)"
    exit 0
fi

PID=$(cat "$PID_FILE")

# Check if process is still running
if ! ps -p "$PID" > /dev/null 2>&1; then
    echo "MCP server is not running (stale PID file)"
    rm -f "$PID_FILE"
    exit 0
fi

echo "Stopping MCP server (PID: $PID)..."

# Try to stop gracefully using genmcp stop
if [ -f "$GENMCP_BINARY" ] && [ -f "$PROJECT_ROOT/mcpfile.yaml" ]; then
    echo "Attempting graceful shutdown..."
    "$GENMCP_BINARY" stop -f "$PROJECT_ROOT/mcpfile.yaml" 2>&1 || echo "  (genmcp stop command failed, will force kill)"
fi

# Wait a bit for graceful shutdown
sleep 2

# Force kill if still running
if ps -p "$PID" > /dev/null 2>&1; then
    echo "Force killing MCP server..."
    kill -9 "$PID" 2>/dev/null || true
    sleep 1
fi

# Remove PID file
rm -f "$PID_FILE"

if ps -p "$PID" > /dev/null 2>&1; then
    echo "✗ Warning: Process may still be running (PID: $PID)"
    exit 1
else
    echo "✓ MCP server stopped successfully"
fi

