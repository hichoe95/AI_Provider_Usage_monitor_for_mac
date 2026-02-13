#!/bin/bash
set -e

APP_NAME="AIUsageMonitor"
EXECUTABLE_NAME="AIUsageMonitor"
BUILD_DIR=".build/release"
APP_BUNDLE="${APP_NAME}.app"
ICON_FILE="Assets/UsageMonitor.icns"

setup_build_env() {
    local tmp_root="${TMPDIR:-/tmp}"
    tmp_root="${tmp_root%/}"

    # Avoid permission issues in restricted environments by keeping module caches in tmp.
    export CLANG_MODULE_CACHE_PATH="${CLANG_MODULE_CACHE_PATH:-${tmp_root}/clang-module-cache}"
    export SWIFTPM_MODULECACHE_OVERRIDE="${SWIFTPM_MODULECACHE_OVERRIDE:-${tmp_root}/swiftpm-module-cache}"
    mkdir -p "${CLANG_MODULE_CACHE_PATH}" "${SWIFTPM_MODULECACHE_OVERRIDE}"

    # Prefer full Xcode toolchain when CLT is selected to reduce SDK/toolchain mismatch issues.
    if [ -z "${DEVELOPER_DIR:-}" ] && [ -d "/Applications/Xcode.app/Contents/Developer" ]; then
        local active_dev_dir
        active_dev_dir="$(/usr/bin/xcode-select -p 2>/dev/null || true)"
        if [ "${active_dev_dir}" = "/Library/Developer/CommandLineTools" ]; then
            export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
            echo "Using Xcode toolchain: ${DEVELOPER_DIR}"
        fi
    fi
}

echo "Building..."
setup_build_env
swift build -c release

echo "Creating app bundle..."
rm -rf "${APP_BUNDLE}"
mkdir -p "${APP_BUNDLE}/Contents/MacOS"
mkdir -p "${APP_BUNDLE}/Contents/Resources"

# Copy binary
cp "${BUILD_DIR}/${EXECUTABLE_NAME}" "${APP_BUNDLE}/Contents/MacOS/"

# Copy SwiftPM resource bundle(s)
for resource_bundle in "${BUILD_DIR}"/*.bundle; do
    if [ -d "${resource_bundle}" ]; then
        cp -R "${resource_bundle}" "${APP_BUNDLE}/Contents/Resources/"
    fi
done

# Copy app icon if available
if [ -f "${ICON_FILE}" ]; then
    cp "${ICON_FILE}" "${APP_BUNDLE}/Contents/Resources/AIUsageMonitor.icns"
fi

# Info.plist
cat > "${APP_BUNDLE}/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>AIUsageMonitor</string>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>CFBundleIdentifier</key>
    <string>com.choihwanil.usagemonitor</string>
    <key>CFBundleName</key>
    <string>AIUsageMonitor</string>
    <key>CFBundleDisplayName</key>
    <string>AIUsageMonitor</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>CFBundleIconFile</key>
    <string>AIUsageMonitor.icns</string>
    <key>LSUIElement</key>
    <true/>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
</dict>
</plist>
EOF

echo "Signing..."
codesign --force --deep --sign - "${APP_BUNDLE}"

echo "Done: ${APP_BUNDLE}"
