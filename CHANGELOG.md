# Changelog

All notable changes to AIUsageMonitor will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-02-13

### Changed
- Unified app branding to `AIUsageMonitor` across product, bundle, scripts, and UI labels.
- Updated release packaging metadata and installer flow to match `AIUsageMonitor.app`.
- Improved build reliability by preferring Xcode toolchain when CLT is active and setting module cache overrides in packaging.
- Stabilized startup cache handling to reduce launch-time cache database errors.
- Increased app icon scale and regenerated `.icns` assets.
- Rounded status bar gauge corners for improved visual consistency.
- Refined README (KR/EN) setup and troubleshooting guides.

### Fixed
- Fixed executable/app bundle naming mismatch in packaging and install scripts.
- Hardened Codex usage parsing for split 5h/7d windows and false 100% readings.

## [1.0.1] - 2026-02-11

### Changed
- Introduced release packaging workflow and DMG/ZIP artifacts for tagged builds.
- Improved Swift 6 compatibility and actor-isolation handling.

## [1.0.0] - 2026-02-10

### Added
- Initial release of UsageMonitor.
- Claude Code, Codex, and OpenRouter providers.
- Native macOS menu bar UI with SwiftUI settings.
- Usage bars, polling, and secure keychain-backed credentials.

[Unreleased]: https://github.com/hichoe95/AI_Provider_Usage_monitor_for_mac/compare/v1.0.2...HEAD
[1.0.2]: https://github.com/hichoe95/AI_Provider_Usage_monitor_for_mac/releases/tag/v1.0.2
[1.0.1]: https://github.com/hichoe95/AI_Provider_Usage_monitor_for_mac/releases/tag/v1.0.1
[1.0.0]: https://github.com/hichoe95/AI_Provider_Usage_monitor_for_mac/releases/tag/v1.0.0
