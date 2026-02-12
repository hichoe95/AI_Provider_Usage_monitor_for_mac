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

## Planned Commit Units

1. `docs(readme): replace screenshots and add required notification setup`
2. `fix(assets): remove app icon background and refresh icon resources`
