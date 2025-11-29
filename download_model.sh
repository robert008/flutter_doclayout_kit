#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VERSION="v1.0.0"
BASE_URL="https://github.com/robert008/flutter_doclayout_kit/releases/download/${VERSION}"

OUTPUT_DIR="${1:-$SCRIPT_DIR/example/assets}"

mkdir -p "$OUTPUT_DIR"

echo "Downloading AI models to: $OUTPUT_DIR"
echo ""

download_model() {
    local model_name=$1
    local model_file="$OUTPUT_DIR/$model_name"
    local download_url="$BASE_URL/$model_name"

    if [ -f "$model_file" ]; then
        echo "[$model_name] Already exists, skipping..."
        return 0
    fi

    echo "[$model_name] Downloading..."
    echo "URL: $download_url"

    if command -v curl &> /dev/null; then
        curl -L -o "$model_file" "$download_url"
    elif command -v wget &> /dev/null; then
        wget -O "$model_file" "$download_url"
    else
        echo "Error: curl or wget is required"
        return 1
    fi

    if [ -f "$model_file" ]; then
        FILE_SIZE=$(stat -f%z "$model_file" 2>/dev/null || stat -c%s "$model_file" 2>/dev/null)
        echo "[$model_name] Downloaded successfully ($FILE_SIZE bytes)"
    else
        echo "[$model_name] Download failed"
        return 1
    fi
}

echo "=== Downloading PP-DocLayout Models ==="
echo ""

download_model "pp_doclayout_m.onnx"
echo ""
download_model "pp_doclayout_l.onnx"

echo ""
echo "=== Download Complete ==="
echo "Models saved to: $OUTPUT_DIR"
echo ""
echo "Usage: Add to your app's assets in pubspec.yaml"
