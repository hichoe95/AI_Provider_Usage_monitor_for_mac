#!/bin/bash
set -e

APP_NAME="AIUsageMonitor"
BUILD_DIR=".build/debug"

echo "Building..."
swift build

echo "Running..."
"${BUILD_DIR}/${APP_NAME}"
