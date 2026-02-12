# UsageMonitor

<!-- MIRROR: keep section order aligned with README.md -->

<div align="center">
  <img src="docs/images/app-icon.png" alt="UsageMonitor App Icon" width="128" height="128" />
</div>

<div align="center">
  <h1>WORK UNTIL USAGE IS EXHAUSTED.</h1>
</div>

UsageMonitor is a native macOS menu bar app that shows Claude, Codex, Copilot, Gemini, and OpenRouter usage at a glance.

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

If status is `Denied`, allow notifications in macOS `System Settings -> Notifications -> UsageMonitor`.

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
rm -rf /Applications/UsageMonitor.app
# or if installed in ~/Applications
rm -rf ~/Applications/UsageMonitor.app
defaults delete com.choihwanil.usagemonitor 2>/dev/null || true
rm -rf ~/Library/Application\ Support/UsageMonitor
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

<details>
<summary><strong>Changelog</strong></summary>

### 2026-02-13 (Latest)

- Dropdown: removed `Sonnet Only` badge
- Dropdown: improved per-row remaining-time fallback for Codex/other providers
- Claude reset-time parsing hardened
- Added notification diagnostics in Settings (`Re-check`, `Request permission`, `Send test alert`)
- README: added required notification setup section
- README: added hero statement + reorganized docs around Quick Start
- README: added top app icon preview in hero section
- README: kept a single primary menu screenshot
- Install: added root `./install.sh` + `./uninstall.sh` scripts
- Installer banner: fixed `EXHAUSTED` line alignment/output
- Icon: fully replaced from `docs/images/logo.png` and regenerated `UsageMonitor.icns`
- Tooling: added `Scripts/generate_icon_with_gemini.py`

### 2026-02-12

- release packaging updates
- fixed Swift 6 actor-isolation build errors
- fixed Codex auth error
- adjusted status bar length
- README updates

</details>

## License

MIT License
