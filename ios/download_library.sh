#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_FILE="$SCRIPT_DIR/libflutter_doclayout_kit.a"
VERSION="v1.0.0"
DOWNLOAD_URL="https://github.com/robert008/flutter_doclayout_kit/releases/download/${VERSION}/libflutter_doclayout_kit.a"

if [ -f "$LIB_FILE" ]; then
    echo "iOS library already exists: $LIB_FILE"
    exit 0
fi

echo "Downloading iOS native library..."
echo "URL: $DOWNLOAD_URL"

if command -v curl &> /dev/null; then
    curl -L -o "$LIB_FILE" "$DOWNLOAD_URL"
elif command -v wget &> /dev/null; then
    wget -O "$LIB_FILE" "$DOWNLOAD_URL"
else
    echo "Error: curl or wget is required to download the library"
    exit 1
fi

if [ -f "$LIB_FILE" ]; then
    FILE_SIZE=$(stat -f%z "$LIB_FILE" 2>/dev/null || stat -c%s "$LIB_FILE" 2>/dev/null)
    if [ "$FILE_SIZE" -gt 1000000 ]; then
        echo "iOS library downloaded successfully: $LIB_FILE ($FILE_SIZE bytes)"
    else
        echo "Error: Downloaded file is too small, may be corrupted"
        rm -f "$LIB_FILE"
        exit 1
    fi
else
    echo "Error: Failed to download iOS library"
    exit 1
fi
