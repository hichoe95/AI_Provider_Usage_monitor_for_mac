#!/bin/bash
set -e

APP_NAME="UsageMonitor"
BUILD_DIR=".build/debug"

echo "Building..."
swift build

echo "Running..."
"${BUILD_DIR}/${APP_NAME}"
