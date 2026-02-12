# Changelog

All notable changes to UsageMonitor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-02-10

### Added
- Initial release of UsageMonitor
- **Claude Code Provider**: OAuth authentication with Keychain and file fallback support
- **Codex Provider**: OAuth authentication via `~/.codex/auth.json`
- **OpenRouter Provider**: REST API integration with Keychain-stored API keys
- **Menu Bar UI**: Native macOS menu bar app with LSUIElement (no Dock icon)
- **Usage Visualization**: Color-coded bars showing session (blue) and weekly (green) usage
- **Settings Window**: SwiftUI-based settings with provider toggles and refresh interval configuration
- **Automatic Polling**: Configurable refresh intervals (1, 5, or 15 minutes)
- **Secure Storage**: OAuth tokens and API keys stored in macOS Keychain
- **Stale Data Indicator**: Dimmed icon appearance when data is older than 10 minutes
- **Build Scripts**: Automated packaging and code signing scripts
- **Swift 6 Concurrency**: Full Swift 6 strict concurrency compliance with @MainActor and Sendable

### Technical Details
- Built with Swift 6.0 and SwiftUI
- Minimum macOS version: 14.0 (Sonoma)
- Swift Package Manager for dependency management
- Ad-hoc code signing for development distribution
- Native AppKit integration for menu bar functionality

### Known Limitations
- macOS 14+ required (Swift 6 and modern SwiftUI features)
- Keychain access prompts on first launch
- Gatekeeper warning for unsigned apps (right-click → Open required)
- Codex JSON-RPC not implemented (OAuth only in V1)

## [Unreleased]

### Planned for V2.0
- WidgetKit extension for home screen widgets
- Sparkle framework for automatic updates
- Codex JSON-RPC support for enhanced functionality
- Additional providers (Cursor, GitHub Copilot)
- PTY fallback for CLI-based providers
- Homebrew formula for easier installation
- App notarization for seamless distribution

---

[1.0.0]: https://github.com/yourusername/usage_monitor/releases/tag/v1.0.0
