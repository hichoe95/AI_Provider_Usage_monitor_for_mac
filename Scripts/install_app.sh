#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="UsageMonitor.app"

cd "$ROOT_DIR"

"$ROOT_DIR/Scripts/package_app.sh"

if [ -d "/Applications" ] && [ -w "/Applications" ]; then
    TARGET_DIR="/Applications"
else
    TARGET_DIR="$HOME/Applications"
    mkdir -p "$TARGET_DIR"
fi

TARGET_PATH="$TARGET_DIR/$APP_NAME"

rm -rf "$TARGET_PATH"
cp -R "$ROOT_DIR/$APP_NAME" "$TARGET_PATH"

# Safe no-op when quarantine attribute does not exist.
xattr -dr com.apple.quarantine "$TARGET_PATH" >/dev/null 2>&1 || true

open "$TARGET_PATH"

echo "Installed: $TARGET_PATH"
