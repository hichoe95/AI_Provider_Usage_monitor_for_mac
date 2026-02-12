# Commit Summary

Date: 2026-02-13
Branch: `main`

## Session Work (Deduplicated)

### 1) App Rename to AIUsageMonitor
- Renamed executable product from `UsageMonitor` to `AIUsageMonitor`.
- Updated install/package/run/uninstall scripts for the new app bundle and executable names.
- Updated user-facing titles in Settings window and test notification message.

Files:
- `Package.swift`
- `Scripts/compile_and_run.sh`
- `Scripts/install_app.sh`
- `Scripts/package_app.sh`
- `uninstall.sh`
- `Sources/UsageMonitor/UI/StatusItemController.swift`
- `Sources/UsageMonitor/Store/NotificationManager.swift`

### 2) Codex Dropdown Remaining-Time Fix
- Split Codex reset handling into `sessionResetDate` and `weeklyResetDate` so 5h and 7d rows use independent reset targets.
- Extended Codex parsing for `rate_limit.primary_window` / `secondary_window` payloads.
- Added support for `reset_at` and `reset_after_seconds` window reset fields.
- Hardened usage parsing to avoid false-positive 100% lock-in from malformed/non-percent fields.
- Improved header reset parsing to handle both epoch and duration formats (e.g. `7m12s`, `90ms`).

Files:
- `Sources/UsageMonitorCore/Providers/Codex/CodexProvider.swift`

### 3) README Sync + Changelog Cleanup (KR/EN)
- Updated README branding text from `UsageMonitor` to `AIUsageMonitor`.
- Increased top hero icon from 128x128 to 256x256.
- Updated uninstall and notification app-name references.
- Reorganized README changelog so latest date stays visible at top and older dates are collapsed.
- Kept KR/EN README changelog structure mirrored.

Files:
- `README.md`
- `README_EN.md`

## Planned Commit Units

1. `refactor(app): rename product and scripts to AIUsageMonitor`
2. `fix(codex): separate reset windows and harden usage parsing`
3. `docs(readme): sync AIUsageMonitor branding and changelog layout`
