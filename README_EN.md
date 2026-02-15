# AIUsageMonitor

<!-- MIRROR: keep section order aligned with README.md -->

<div align="center">
  <img src="docs/images/app-icon.png" alt="AIUsageMonitor" width="180" />

  <h1>AIUsageMonitor</h1>

  <p><strong>WORK UNTIL USAGE IS EXHAUSTED.</strong></p>

  <p>Monitor Claude, Codex, Copilot, Gemini & OpenRouter usage<br/>right from your macOS menu bar.</p>

  <p>
    English&nbsp;&nbsp;|&nbsp;&nbsp;<a href="README.md">한국어</a>
  </p>

  <p>
    <img src="https://img.shields.io/badge/macOS-14%2B-0078D4?style=flat-square&logo=apple&logoColor=white" alt="macOS 14+" />
    <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.0" />
    <img src="https://img.shields.io/badge/license-MIT-97CA00?style=flat-square" alt="MIT License" />
  </p>

  <img src="docs/images/screenshot-menu-2026-02-15.png" alt="AIUsageMonitor Screenshot" width="420" />
</div>

---

## Why?

When using AI coding tools (Claude Code, Codex, Copilot, etc.), **you will eventually hit your usage limit mid-task**.
By the time you check the dashboard, it's already too late.

AIUsageMonitor shows each provider's usage **in real time from your menu bar**.
Get notified before hitting limits so your workflow never gets interrupted.

---

## Features

| Feature | Description |
|---|---|
| **Real-time usage bars** | 5-hour / 7-day usage gauge per provider |
| **Time remaining** | Countdown to each reset window (`2h 15m`, `3d 4h`) |
| **Codex Spark usage** | Separate tracking for Codex Spark model |
| **Trend indicators** | Usage trend arrows (`↑` / `↓`) |
| **Usage alerts** | macOS notifications at configurable thresholds |
| **OpenRouter balance** | Remaining credits in dollars |
| **Dashboard shortcuts** | One-click jump to each provider's dashboard |

**Supported Providers:**

| Provider | Auth Method | Displayed Info |
|---|---|---|
| Claude Code | OAuth (Keychain) | 5h, 7d, Sonnet usage |
| Codex (OpenAI) | OAuth (`~/.codex/auth.json`) | 5h, 7d, Spark usage |
| Copilot | GitHub CLI (`gh`) | Usage |
| Gemini | Google OAuth / API Key | Usage |
| OpenRouter | API Key | Balance ($) |

---

## Install

```bash
git clone https://github.com/hichoe95/AI_Provider_Usage_monitor_for_mac.git
cd AI_Provider_Usage_monitor_for_mac
./install.sh
```

`install.sh` handles the entire build → install → launch process automatically.

> **Requirements:** macOS 14+, Xcode 16+ (Swift 6), Git

<details>
<summary>Install troubleshooting</summary>

```bash
# Missing Xcode CLI tools
xcode-select --install

# Swift/SDK version mismatch
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# Check install log
cat ${TMPDIR:-/tmp}/usagemonitor-install.log
```

</details>

---

## Initial Setup (Required)

### 1. Provider Login

Log in to each provider from the terminal **on the same Mac** where the app runs.

```bash
claude login        # Claude Code
codex login         # Codex (OpenAI)
gh auth login       # Copilot (GitHub)
gemini auth         # Gemini
```

> CLI commands may vary by version. Check `--help` for details.

### 2. Enable Providers

Menu bar icon → `Settings...` → Turn ON your providers → `Refresh Now` (`⌘R`)

### 3. Enable Notifications

1. `Settings...` → `Notifications` → `Enable usage alerts` ON
2. Click `Request permission` → Confirm `Notifications: Allowed`
3. Click `Send test alert` to verify

> If status shows `Denied`, allow it in macOS **System Settings → Notifications → AIUsageMonitor**.

---

## Token Lifecycle

Each provider has a different login session duration.

| Provider | Login Duration | Notes |
|---|---|---|
| **Claude Code** | **8–12 hours** | May require re-login 1–2 times a day |
| Codex (OpenAI) | ~10 days | Auto-refresh |
| Copilot | GitHub session | `gh auth login` |
| Gemini | Google session | `gemini auth` |

### ⚠️ Claude Code: Fix Daily Re-login (Must Read)

Claude Code's auth token **expires every 8–12 hours**, and auto-renewal often fails on macOS.
([Related issue](https://github.com/anthropics/claude-code/issues/19456))

**Generate a long-lived token to fix this:**

```bash
# 1. Generate a long-lived token (opens browser for auth)
claude setup-token

# 2. Add the token to your shell config
#    zsh (default on macOS):
echo 'export CLAUDE_CODE_OAUTH_TOKEN="your_token_here"' >> ~/.zshrc && source ~/.zshrc

#    bash:
echo 'export CLAUDE_CODE_OAUTH_TOKEN="your_token_here"' >> ~/.bashrc && source ~/.bashrc
```

> Only available for Pro/Max subscribers.

---

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| `⌘R` | Refresh Now |
| `⌘,` | Settings |
| `⌘D` | Claude Dashboard |
| `⌘Q` | Quit |

---

## Update / Uninstall

```bash
# Update
cd AI_Provider_Usage_monitor_for_mac
git pull && ./install.sh

# Uninstall
cd AI_Provider_Usage_monitor_for_mac
./uninstall.sh
```

<details>
<summary>Manual uninstall</summary>

```bash
rm -rf /Applications/AIUsageMonitor.app ~/Applications/AIUsageMonitor.app
defaults delete com.choihwanil.usagemonitor 2>/dev/null || true
rm -rf ~/Library/Application\ Support/UsageMonitor
rm -rf ~/Library/Caches/com.choihwanil.usagemonitor ~/Library/Caches/UsageMonitor
```

</details>

---

## Troubleshooting

| Symptom | Fix |
|---|---|
| Only `No data` | Re-login to provider in terminal, then `⌘R` |
| Repeated Keychain prompts | Choose `Always Allow` in the dialog |
| OpenRouter not showing | Enable in Settings + save API key |
| Icon not updating | Quit and reinstall (Finder cache delay) |
| Install path conflict | `rm -rf /Applications/AIUsageMonitor.app ~/Applications/AIUsageMonitor.app` then reinstall |

---

## FAQ

**Q. Why source install instead of DMG?**

Downloaded DMG apps can be blocked by macOS Gatekeeper.
Building locally avoids this issue entirely.

---

## Development

```bash
swift build
swift test
./Scripts/package_app.sh
```

---

## Changelog

### 2026-02-15 (Latest)

- Added Codex Spark model usage tracking (separate 5h/7d display)
- Fixed Claude OAuth token refresh permanently blocking Keychain re-read
- Clear stale provider data on fetch error (prevents status bar overlay)
- Preserve trend arrows across error-to-recovery transitions
- Fixed status bar icon not syncing when provider errors change
- Added token lifecycle guide (Claude `setup-token` fix)

<details>
<summary>Previous changes</summary>

### 2026-02-13

- Unified app branding to `AIUsageMonitor`
- Fixed packaging/installer executable vs bundle name mismatch
- Added automatic Xcode toolchain selection + module cache path override
- Stabilized startup cache-directory handling
- Improved Codex 5h/7d remaining-time display separation
- Added Codex parser support for `primary_window`/`secondary_window` + `reset_at`/`reset_after_seconds`
- Added guard against false-positive Codex usage parsing (100% lock)
- Increased app icon scale, regenerated `.icns` assets
- Rounded status bar gauge corners

### 2026-02-12

- Release packaging cleanup
- Fixed Swift 6 actor-isolation build errors
- Fixed Codex auth error
- Adjusted status bar length

</details>

---

## License

[MIT License](LICENSE)
