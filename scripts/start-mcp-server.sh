#!/bin/bash
# Start the MCP server

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENMCP_DIR="$PROJECT_ROOT/.genmcp"
GENMCP_BINARY="$GENMCP_DIR/genmcp"
MCPFILE="$PROJECT_ROOT/mcpfile.yaml"
PID_FILE="$PROJECT_ROOT/.genmcp/mcp-server.pid"
LOG_FILE="$PROJECT_ROOT/.genmcp/mcp-server.log"

# Check if genmcp binary exists
if [ ! -f "$GENMCP_BINARY" ]; then
    echo "Error: gen-mcp binary not found. Run 'make download-genmcp-release' or 'make download-genmcp-nightly' first."
    exit 1
fi

# Check if mcpfile exists
if [ ! -f "$MCPFILE" ]; then
    echo "Error: mcpfile.yaml not found. Run 'make generate-mcpfile' first."
    exit 1
fi

# Check if server is already running
if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if ps -p "$PID" > /dev/null 2>&1; then
        echo "MCP server is already running (PID: $PID)"
        exit 0
    else
        # Stale PID file
        rm -f "$PID_FILE"
    fi
fi

# Create .genmcp directory if it doesn't exist
mkdir -p "$GENMCP_DIR"

echo "Starting MCP server..."
echo "Using mcpfile: $MCPFILE"
echo "Binary: $GENMCP_BINARY"
cd "$PROJECT_ROOT"

# Verify gen-mcp binary works
echo "Verifying gen-mcp binary..."
if ! "$GENMCP_BINARY" version > /dev/null 2>&1; then
    echo "Warning: gen-mcp version check failed, but continuing..."
fi
echo ""

# Clear old log file
> "$LOG_FILE"

# Start server in background with logging
echo "Launching gen-mcp server..."
# Enable verbose logging by setting log level environment variable
LOG_LEVEL="${LOG_LEVEL:-info}"
export LOG_LEVEL

# Start with both stdout and stderr going to log file
"$GENMCP_BINARY" run -f "$MCPFILE" >> "$LOG_FILE" 2>&1 &
SERVER_PID=$!

# Save PID
echo "$SERVER_PID" > "$PID_FILE"

echo "Server process started (PID: $SERVER_PID)"
echo "Waiting for server to initialize..."

# Wait a moment to check if it started successfully
sleep 3

if ps -p "$SERVER_PID" > /dev/null 2>&1; then
    echo ""
    echo "✓ MCP server started successfully (PID: $SERVER_PID)"
    echo ""
    echo "Log file: $LOG_FILE"
    echo ""
    
    # Check for log output
    if [ -f "$LOG_FILE" ] && [ -s "$LOG_FILE" ]; then
        echo "Recent log output:"
        echo "----------------------------------------"
        tail -n 20 "$LOG_FILE"
        echo "----------------------------------------"
        echo ""
    else
        echo "Note: MCP servers typically communicate via stdio, so there may be"
        echo "      minimal log output. The server is running and ready to accept"
        echo "      MCP protocol connections."
        echo ""
    fi
    
    echo "To view logs in real-time (if any), run:"
    echo "  tail -f $LOG_FILE"
    echo ""
    echo "To check server status, run:"
    echo "  bash scripts/status-mcp-server.sh"
    echo ""
    echo "To stop the server, run:"
    echo "  make stop-mcp-server"
else
    echo ""
    echo "✗ Error: MCP server failed to start"
    echo ""
    echo "Last 30 lines of log:"
    echo "----------------------------------------"
    if [ -f "$LOG_FILE" ]; then
        tail -n 30 "$LOG_FILE"
    else
        echo "(No log file created)"
    fi
    echo "----------------------------------------"
    rm -f "$PID_FILE"
    exit 1
fi

