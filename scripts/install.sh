#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Avro Silicon"
INPUT_METHODS_DIR="$HOME/Library/Input Methods"
BUILD_DIR="$(cd "$(dirname "$0")/.." && pwd)/build"

# Find the built app
APP_PATH=""
for config in Release Debug; do
    candidate="$BUILD_DIR/$config/$APP_NAME.app"
    if [ -d "$candidate" ]; then
        APP_PATH="$candidate"
        break
    fi
done

if [ -z "$APP_PATH" ]; then
    echo "Error: $APP_NAME.app not found in build/Release or build/Debug."
    echo "Run 'xcodebuild' first to build the app."
    exit 1
fi

echo "Installing $APP_NAME from: $APP_PATH"

# Remove old installation if present
if [ -d "$INPUT_METHODS_DIR/$APP_NAME.app" ]; then
    echo "Removing previous installation..."
    rm -rf "$INPUT_METHODS_DIR/$APP_NAME.app"
fi

# Copy to Input Methods
cp -R "$APP_PATH" "$INPUT_METHODS_DIR/"
echo "Copied to $INPUT_METHODS_DIR/"

# Register with LaunchServices
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister \
    -f "$INPUT_METHODS_DIR/$APP_NAME.app"
echo "Registered with LaunchServices."

# Restart TextInputMenuAgent
killall TextInputMenuAgent 2>/dev/null || true
echo "Restarted TextInputMenuAgent."

echo ""
echo "Done! Open System Settings > Keyboard > Input Sources and add '$APP_NAME' under Bangla."
