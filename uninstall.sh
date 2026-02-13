#!/bin/bash
set -euo pipefail

APP_NAME="AIUsageMonitor.app"
BUNDLE_ID="com.choihwanil.usagemonitor"

DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run|-n)
            DRY_RUN=true
            ;;
        --force|-y)
            FORCE=true
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: ./uninstall.sh [--dry-run|-n] [--force|-y]"
            exit 1
            ;;
    esac
    shift
done

APP_PATHS=(
    "/Applications/$APP_NAME"
    "$HOME/Applications/$APP_NAME"
)

DIR_PATHS=(
    "$HOME/Library/Application Support/UsageMonitor"
    "$HOME/Library/Caches/$BUNDLE_ID"
    "$HOME/Library/Caches/UsageMonitor"
    "$HOME/Library/HTTPStorages/$BUNDLE_ID"
    "$HOME/Library/Saved Application State/$BUNDLE_ID.savedState"
    "$HOME/Library/WebKit/$BUNDLE_ID"
)

FILE_PATHS=(
    "$HOME/Library/Preferences/$BUNDLE_ID.plist"
)

GLOB_PATHS=(
    "$HOME/Library/Logs/DiagnosticReports/AIUsageMonitor-*.ips"
    "$HOME/Library/Logs/DiagnosticReports/UsageMonitor-*.ips"
)

remove_path() {
    local path="$1"
    if [[ -e "$path" ]]; then
        rm -rf "$path"
        printf "Removed: %s\n" "$path"
    fi
}

echo "AIUsageMonitor uninstall targets:"
for path in "${APP_PATHS[@]}"; do
    printf "  - %s\n" "$path"
done
for path in "${DIR_PATHS[@]}"; do
    printf "  - %s\n" "$path"
done
for path in "${FILE_PATHS[@]}"; do
    printf "  - %s\n" "$path"
done
echo "  - defaults domain: $BUNDLE_ID"
for pattern in "${GLOB_PATHS[@]}"; do
    printf "  - %s\n" "$pattern"
done

if [[ "$DRY_RUN" == true ]]; then
    echo "Dry run complete. No files were deleted."
    exit 0
fi

if [[ "$FORCE" != true ]]; then
    read -r -p "Proceed with uninstall? [y/N] " answer
    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
        echo "Canceled."
        exit 0
    fi
fi

pkill -x "AIUsageMonitor" >/dev/null 2>&1 || true

for path in "${APP_PATHS[@]}"; do
    remove_path "$path"
done
for path in "${DIR_PATHS[@]}"; do
    remove_path "$path"
done
for path in "${FILE_PATHS[@]}"; do
    remove_path "$path"
done

defaults delete "$BUNDLE_ID" >/dev/null 2>&1 || true

shopt -s nullglob
for pattern in "${GLOB_PATHS[@]}"; do
    for path in $pattern; do
        remove_path "$path"
    done
done
shopt -u nullglob

printf "Uninstall complete.\n"
