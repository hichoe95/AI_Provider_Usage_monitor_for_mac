#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="UsageMonitor.app"
LOG_FILE="${TMPDIR:-/tmp}/usagemonitor-install.log"

IS_TTY=0
if [[ -t 1 ]]; then
    IS_TTY=1
fi

if [[ "$IS_TTY" -eq 1 ]]; then
    C_RESET=$'\033[0m'
    C_BOLD=$'\033[1m'
    C_RED=$'\033[31m'
    C_GREEN=$'\033[32m'
    C_YELLOW=$'\033[33m'
    C_BLUE=$'\033[34m'
    C_CYAN=$'\033[36m'
else
    C_RESET=""
    C_BOLD=""
    C_RED=""
    C_GREEN=""
    C_YELLOW=""
    C_BLUE=""
    C_CYAN=""
fi

STEP=0
TOTAL_STEPS=5

TARGET_DIR=""
TARGET_PATH=""

banner() {
    cat <<'EOF'
+-------------------------------------------------------------------+
|                      USAGEMONITOR INSTALLER                       |
+-------------------------------------------------------------------+
EOF
}

run_step() {
    local title="$1"
    shift

    STEP=$((STEP + 1))
    printf "%b[%d/%d]%b %s\n" "$C_CYAN" "$STEP" "$TOTAL_STEPS" "$C_RESET" "$title"

    if [[ "$IS_TTY" -eq 1 ]]; then
        "$@" >>"$LOG_FILE" 2>&1 &
        local pid=$!
        local spin='|/-\\'
        local i=0

        while kill -0 "$pid" 2>/dev/null; do
            local ch="${spin:i%4:1}"
            printf "\r    %b[%s]%b working..." "$C_YELLOW" "$ch" "$C_RESET"
            sleep 0.08
            i=$((i + 1))
        done

        local status
        set +e
        wait "$pid"
        status=$?
        set -e

        if [[ "$status" -eq 0 ]]; then
            printf "\r    %b[OK]%b %s\n" "$C_GREEN" "$C_RESET" "$title"
        else
            printf "\r    %b[FAIL]%b %s\n" "$C_RED" "$C_RESET" "$title"
            printf "    Log: %s\n" "$LOG_FILE"
            exit "$status"
        fi
    else
        if "$@" >>"$LOG_FILE" 2>&1; then
            printf "    [OK] %s\n" "$title"
        else
            printf "    [FAIL] %s\n" "$title"
            printf "    Log: %s\n" "$LOG_FILE"
            exit 1
        fi
    fi
}

resolve_target_dir() {
    if [[ -d "/Applications" && -w "/Applications" ]]; then
        TARGET_DIR="/Applications"
    else
        TARGET_DIR="$HOME/Applications"
    fi
    TARGET_PATH="$TARGET_DIR/$APP_NAME"
}

build_bundle() {
    "$ROOT_DIR/Scripts/package_app.sh"
}

ensure_target_dir() {
    mkdir -p "$TARGET_DIR"
}

install_bundle() {
    rm -rf "$TARGET_PATH"
    cp -R "$ROOT_DIR/$APP_NAME" "$TARGET_PATH"
}

clear_quarantine() {
    xattr -dr com.apple.quarantine "$TARGET_PATH" >/dev/null 2>&1 || true
}

launch_app() {
    open "$TARGET_PATH"
}

show_fireworks() {
    if [[ "$IS_TTY" -ne 1 ]]; then
        return
    fi

    local frames=(
        "      .        .        .        ."
        "    .''.    .''.    .''.    .''.'"
        "   :_\\/_:  :_\\/_:  :_\\/_:  :_\\/_:"
        "   : /\\ :  : /\\ :  : /\\ :  : /\\ :"
        "    '..'    '..'    '..'    '..'"
    )

    printf "\n"
    local round
    for round in 1 2; do
        local frame
        for frame in "${frames[@]}"; do
            printf "\r    %b%s%b" "$C_BLUE" "$frame" "$C_RESET"
            sleep 0.12
        done
    done
    printf "\r%80s\n" ""
}

show_final_message() {
    if [[ "$IS_TTY" -eq 1 ]]; then
        printf "%b" "$C_BOLD$C_GREEN"
    fi

    cat <<'EOF'

+--------------------------------------------------------------------------+
| __        _____  ____  _  __                                             |
| \ \      / / _ \|  _ \| |/ /                                             |
|  \ \ /\ / / | | | |_) | ' /                                              |
|   \ V  V /| |_| |  _ <| . \                                              |
|    \_/\_/  \___/|_| \_\_|\_\                                             |
|                                                                          |
| _   _ _   _ _____ ___ _                                                  |
| | | | | \ | |_   _|_ _| |                                                |
| | | | |  \| | | |  | || |                                                |
| | |_| | |\  | | |  | || |___                                             |
|  \___/|_| \_| |_| |___|_____|                                            |
|                                                                          |
| _   _ ____    _    ____ _____                                            |
| | | | / ___|  / \  / ___| ____|                                          |
| | | | \___ \ / _ \| |  _|  _|                                            |
| | |_| |___) / ___ \ |_| | |___                                           |
|  \___/|____/_/   \_\____|_____|                                          |
|                                                                          |
| _____  ____  _   _    _    _   _ ____ _____ _____ ____                   |
| | ____|/ ___|| | | |  / \  | | | / ___|_   _| ____|  _ \                 |
| |  _|  \___ \| |_| | / _ \ | | | \___ \ | | |  _| | | | |                |
| | |___  ___) |  _  |/ ___ \| |_| |___) || | | |___| |_| |                |
| |_____| |____/|_| |_/_/   \_\\___/|____/ |_| |_____|____/                |
|                                                                          |

EOF

    printf "| %-72s |\n" "WORK UNTIL USAGE IS EXHAUSTED."
    printf "+--------------------------------------------------------------------------+\n"

    if [[ "$IS_TTY" -eq 1 ]]; then
        printf "%b" "$C_RESET"
    fi
}

cd "$ROOT_DIR"

: >"$LOG_FILE"
resolve_target_dir

banner
printf "%bRoot:%b %s\n" "$C_BOLD" "$C_RESET" "$ROOT_DIR"
printf "%bTarget:%b %s\n" "$C_BOLD" "$C_RESET" "$TARGET_PATH"
printf "%bLog:%b %s\n\n" "$C_BOLD" "$C_RESET" "$LOG_FILE"

run_step "Build release app bundle" build_bundle
run_step "Ensure install directory exists" ensure_target_dir
run_step "Install app bundle" install_bundle
run_step "Remove quarantine attribute" clear_quarantine
run_step "Launch app" launch_app

show_fireworks
show_final_message

printf "%bInstalled:%b %s\n" "$C_GREEN" "$C_RESET" "$TARGET_PATH"
