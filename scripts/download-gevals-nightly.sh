#!/bin/bash
# Download nightly snapshot version of gevals

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
GEVALS_DIR="$PROJECT_ROOT/.gevals"
BINARY_NAME="gevals"

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

# Create .gevals directory if it doesn't exist
mkdir -p "$GEVALS_DIR"

# Use nightly tag
VERSION="nightly"
echo "Downloading nightly version..."

# Download URL
ZIP_FILE="${BINARY_NAME}-${PLATFORM}.zip"
DOWNLOAD_URL="https://github.com/genmcp/gevals/releases/download/${VERSION}/${ZIP_FILE}"

echo "Downloading from: $DOWNLOAD_URL"
curl -L -o "$GEVALS_DIR/${ZIP_FILE}" "$DOWNLOAD_URL"

# Extract
echo "Extracting..."
cd "$GEVALS_DIR"
unzip -q -o "${ZIP_FILE}"

# Find and rename the binary
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

echo "gevals downloaded successfully to: $GEVALS_DIR/${BINARY_NAME}"
echo "Version: ${VERSION} (nightly)"

