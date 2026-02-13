# AIUsageMonitor

<!-- MIRROR: keep section order aligned with README.md -->

<div align="center">
  <img src="docs/images/app-icon.png" alt="AIUsageMonitor App Icon" width="256" height="256" />
</div>

<div align="center">
  <h1>WORK UNTIL USAGE IS EXHAUSTED.</h1>
</div>

AIUsageMonitor is a native macOS menu bar app that shows Claude, Codex, Copilot, Gemini, and OpenRouter usage at a glance.

[한국어 README](README.md)

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

![UsageMonitor Menu Screenshot](docs/images/screenshot-menu-2026-02-13.png)

## Quick Start

### 1) Install

```bash
git clone https://github.com/hichoe95/AI_Provider_Usage_monitor_for_mac.git
cd AI_Provider_Usage_monitor_for_mac
./install.sh
```

`install.sh` handles everything automatically:
- release build -> app install -> launch
- step-by-step spinner/animated progress output
- install log file: `${TMPDIR:-/tmp}/usagemonitor-install.log`
- install target: `/Applications` (falls back to `~/Applications` without permission)

### 2) First Setup

1. Run provider login in terminal on the same local Mac
2. Open menu bar icon -> `Settings...` and enable providers you use
3. Click `Refresh Now` (`⌘R`)

CLI login commands differ by version, so check `--help`:

```bash
claude --help
codex --help
gh --help
gemini --help
```

### 3) Enable Notifications (Required)

1. Open `Settings...` -> `Notifications`
2. Turn ON `Enable usage alerts`
3. Click `Request permission`
4. Confirm status shows `Notifications: Allowed`
5. Click `Send test alert` and verify a banner appears

If status is `Denied`, allow notifications in macOS `System Settings -> Notifications -> AIUsageMonitor`.

## Features

- per-provider usage bars: `5h`, `7d` (Claude also shows `sn`)
- per-bar remaining time: `2h 15m`, `3d 4h`
- health dot, trend arrows (`↑`/`↓`), `Open Dashboard ↗`, `Updated ... ago`

## Shortcuts

- `⌘R`: Refresh Now
- `⌘,`: Settings
- `⌘D`: Claude Dashboard
- `⌘Q`: Quit

## Update / Uninstall

**Update**

```bash
cd AI_Provider_Usage_monitor_for_mac
git pull
./install.sh
```

**Uninstall**

```bash
cd AI_Provider_Usage_monitor_for_mac
./uninstall.sh
```

<details>
<summary>Manual uninstall</summary>

```bash
rm -rf /Applications/AIUsageMonitor.app
# or if installed in ~/Applications
rm -rf ~/Applications/AIUsageMonitor.app
defaults delete com.choihwanil.usagemonitor 2>/dev/null || true
rm -rf ~/Library/Application\ Support/UsageMonitor
rm -rf ~/Library/Caches/com.choihwanil.usagemonitor ~/Library/Caches/UsageMonitor
```

</details>

## Troubleshooting

### 1) Only `No data`

- make sure provider login exists on local Mac
- make sure app and terminal use the same macOS user account
- click `Refresh Now`

### 2) Repeated Keychain prompts

- choose `Always Allow` when prompted
- if you already chose `Allow`, update permissions in Keychain Access

### 3) OpenRouter not showing

- enable OpenRouter in Settings
- save API key
- click `Refresh Now`

### 4) `swift` not found

```bash
xcode-select --install
```

### 5) Install fails

- check log: `cat ${TMPDIR:-/tmp}/usagemonitor-install.log`
- inspect the last error lines first
- if it keeps failing, attach full log in an issue

### 6) Swift/SDK version mismatch

```bash
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch
```

- Typical error: `SDK is built with ... while this compiler is ...`
- Re-run `./install.sh` after the commands above

### 7) App does not launch or install path is mixed

```bash
rm -rf /Applications/AIUsageMonitor.app ~/Applications/AIUsageMonitor.app
./install.sh
```

- Keep only one install location to avoid path confusion

### 8) App icon does not refresh immediately

- Quit the app and reinstall
- Finder/Dock icon cache delay can temporarily show the previous icon

## Requirements

| Item | Minimum |
|---|---|
| OS | macOS 14 or later |
| Xcode | 16 or later (includes Swift 6) |
| Git | Required |
| Network | Required for provider API requests |

Check environment:

```bash
swift --version
git --version
```

## Development

```bash
swift build
swift test
./Scripts/package_app.sh
GOOGLE_GENERATIVE_AI_API_KEY=... python3 Scripts/generate_icon_with_gemini.py --output Assets/icon-gemini-raw.png
```

## FAQ

### Why source install instead of DMG?

Downloaded DMG apps can be blocked by macOS Gatekeeper.
Local source build/install is the most reliable path for now.

## Changelog

### 2026-02-13 (Latest)

- Unified app branding to `AIUsageMonitor` (product/bundle/scripts/UI strings)
- Fixed packaging/installer mismatch between executable name and app bundle name
- Added automatic Xcode toolchain selection + module cache path override in packaging script
- Stabilized startup cache-directory handling (reduces launch/network cache errors)
- Improved Codex dropdown to keep 5h and 7d remaining-time displays independent
- Added Codex parser support for `rate_limit.primary_window`/`secondary_window` + `reset_at`/`reset_after_seconds`
- Added guard logic to prevent false-positive Codex usage parsing (100% lock issue)
- Increased app icon scale and regenerated `.icns` assets
- Rounded status bar gauge corners
- Synced KR/EN README updates and increased top icon size to 256x256

<details>
<summary>Previous changes</summary>

### 2026-02-12

- release packaging updates
- fixed Swift 6 actor-isolation build errors
- fixed Codex auth error
- adjusted status bar length
- README updates

</details>

## License

MIT License
