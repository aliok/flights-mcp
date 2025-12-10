#!/bin/bash
# Download latest release version of gevals

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

# Get latest release version
echo "Fetching latest release version..."
LATEST_VERSION=$(curl -s https://api.github.com/repos/genmcp/gevals/releases/latest | grep '"tag_name":' | sed -E 's/.*"tag_name": "([^"]+)".*/\1/')

if [ -z "$LATEST_VERSION" ]; then
    echo "Error: Could not fetch latest version"
    exit 1
fi

echo "Latest version: $LATEST_VERSION"

# Download URL
ZIP_FILE="${BINARY_NAME}-${PLATFORM}.zip"
DOWNLOAD_URL="https://github.com/genmcp/gevals/releases/download/${LATEST_VERSION}/${ZIP_FILE}"

echo "Downloading from: $DOWNLOAD_URL"
curl -L -o "$GEVALS_DIR/${ZIP_FILE}" "$DOWNLOAD_URL"

# Extract
echo "Extracting..."
cd "$GEVALS_DIR"
unzip -q -o "${ZIP_FILE}"

# Find and rename the binary (could be gevals-platform or just gevals)
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
echo "Version: $LATEST_VERSION"

