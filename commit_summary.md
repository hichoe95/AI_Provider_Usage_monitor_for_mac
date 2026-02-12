# Commit Summary

Date: 2026-02-13
Branch: `main`

## Session Summary (Deduplicated)

### 1) Dropdown/Parsing Fixes
- Removed `Sonnet Only` badge from dropdown provider rows.
- Improved remaining-time display fallback so providers without split reset fields can still render per-row remaining time.
- Hardened Claude reset date parsing to support:
  - epoch seconds
  - epoch milliseconds
  - ISO8601
  - ISO8601 with fractional seconds

Files:
- `Sources/UsageMonitor/UI/MenuBuilder.swift`
- `Sources/UsageMonitorCore/Providers/Claude/ClaudeProvider.swift`

### 2) Notification Diagnostics UX
- Added visible notification permission status in Settings.
- Added `Re-check` button to refresh current authorization status.
- Added `Request permission` button to trigger authorization flow.
- Added `Send test alert` button for immediate delivery verification.
- Added `sendTestNotification()` helper in notification manager.

Files:
- `Sources/UsageMonitor/UI/SettingsView.swift`
- `Sources/UsageMonitor/Store/NotificationManager.swift`

### 3) Documentation + README UX Refresh
- Rewrote KR/EN README into quick-start focused format.
- Added dated changelog sections with latest date first.
- Older date entries are collapsed using `<details>` blocks.
- Synced KR/EN README structure.
- Replaced top README visuals with latest app screenshots.
- Added mandatory notification setup steps in KR/EN README.

Files:
- `README.md`
- `README_EN.md`
- `commit_summary.md`

### 4) App Icon Transparency
- Removed unintended opaque background from app icon source PNG.
- Regenerated `UsageMonitor.icns` from transparent source.
- Updated documentation app icon image to match transparent asset.

Files:
- `Assets/usage-monitor-icon.png`
- `Assets/UsageMonitor.icns`
- `docs/images/app-icon.png`
- `docs/images/screenshot-menu-2026-02-13.png`
- `docs/images/screenshot-settings-2026-02-13.png`

### 5) Installer UX Upgrade
- Added root `./install.sh` entry point for one-command installation.
- Upgraded installer output with step-based progress, spinner animation, log file path, fireworks effect, and final large ASCII banner.

Files:
- `install.sh`
- `Scripts/install_app.sh`
- `README.md`
- `README_EN.md`

### 6) README Readability Refresh
- Added centered hero statement: `WORK UNTIL USAGE IS EXHAUSTED.`
- Added top app icon preview in README hero area.
- Reorganized docs into Quick Start -> Features -> Update/Uninstall -> Troubleshooting flow.
- Added explicit uninstall docs and install failure log troubleshooting.
- Collapsed full changelog with `<details>` for better scanability.
- Switched visuals to a single primary menu screenshot.

Files:
- `README.md`
- `README_EN.md`

### 7) Icon Final Replacement
- Replaced application icon assets with user-provided `docs/images/logo.png`.
- Regenerated `UsageMonitor.icns` from the new 1024x1024 source.

Files:
- `docs/images/logo.png`
- `Assets/usage-monitor-icon.png`
- `Assets/UsageMonitor.icns`
- `docs/images/app-icon.png`

### 8) Gemini Icon Tooling
- Added a direct Gemini API icon generation script using `GOOGLE_GENERATIVE_AI_API_KEY`.
- Included model fallback handling and PNG output support.

Files:
- `Scripts/generate_icon_with_gemini.py`

## Planned Commit Units

1. `feat(installer): add root install/uninstall flow and polish banner output`
2. `docs(readme): add hero title and reorganize setup documentation`
3. `feat(tooling): add gemini icon generation utility script`
4. `fix(assets): replace app icon assets with final logo and regenerate icns`
