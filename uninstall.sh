#!/bin/bash
set -euo pipefail

APP_NAME="AIUsageMonitor.app"
PRIMARY="/Applications/$APP_NAME"
FALLBACK="$HOME/Applications/$APP_NAME"

remove_app() {
    local path="$1"
    if [[ -d "$path" ]]; then
        rm -rf "$path"
        printf "Removed: %s\n" "$path"
    fi
}

remove_app "$PRIMARY"
remove_app "$FALLBACK"

defaults delete com.choihwanil.usagemonitor >/dev/null 2>&1 || true
rm -rf "$HOME/Library/Application Support/UsageMonitor"

printf "Uninstall complete.\n"
