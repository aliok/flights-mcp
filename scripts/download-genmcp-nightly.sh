#!/bin/bash
# Download nightly snapshot version of gen-mcp

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GENMCP_DIR="$PROJECT_ROOT/.genmcp"
BINARY_NAME="genmcp"

# Detect OS and architecture
OS=$(uname -s | tr '[:upper:]' '[:lower:]')
ARCH=$(uname -m)

case "$ARCH" in
    x86_64) ARCH="amd64" ;;
    arm64|aarch64) ARCH="arm64" ;;
    *) echo "Unsupported architecture: $ARCH"; exit 1 ;;
esac

case "$OS" in
    linux) PLATFORM="linux-${ARCH}" ;;
    darwin) PLATFORM="darwin-${ARCH}" ;;
    *) echo "Unsupported OS: $OS"; exit 1 ;;
esac

# Create .genmcp directory if it doesn't exist
mkdir -p "$GENMCP_DIR"

# Get latest nightly release
echo "Fetching nightly release..."
# Use the nightly tag
NIGHTLY_TAG="nightly"

# Download URL for nightly
ZIP_FILE="${BINARY_NAME}-${PLATFORM}.zip"
DOWNLOAD_URL="https://github.com/genmcp/gen-mcp/releases/download/${NIGHTLY_TAG}/${ZIP_FILE}"

echo "Downloading nightly from: $DOWNLOAD_URL"
curl -L -o "$GENMCP_DIR/${ZIP_FILE}" "$DOWNLOAD_URL"

# Extract
echo "Extracting..."
cd "$GENMCP_DIR"
unzip -q -o "${ZIP_FILE}"

# Find and rename the binary (could be genmcp-platform or just genmcp)
if [ -f "${BINARY_NAME}-${PLATFORM}" ]; then
    mv "${BINARY_NAME}-${PLATFORM}" "${BINARY_NAME}"
elif [ -f "${BINARY_NAME}" ]; then
    # Already extracted with correct name
    true
else
    # Try to find any executable file
    EXECUTABLE=$(find . -maxdepth 1 -type f -executable ! -name "*.sh" ! -name "*.zip" | head -1)
    if [ -n "$EXECUTABLE" ]; then
        mv "$EXECUTABLE" "${BINARY_NAME}"
    else
        echo "Error: Binary not found after extraction"
        exit 1
    fi
fi

chmod +x "${BINARY_NAME}"

# Clean up zip file
rm -f "${ZIP_FILE}"

echo "gen-mcp nightly downloaded successfully to: $GENMCP_DIR/${BINARY_NAME}"
echo "Tag: $NIGHTLY_TAG"

