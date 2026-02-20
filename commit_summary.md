# Commit Summary

## 2026-02-20

Branch: `main`

### Session Work

#### 1) feat(icons): replace Codex status bar icon with ChatGPT blossom logo

사용자가 제공한 ChatGPT 블로섬(꽃잎 매듭) 로고로 Codex status bar 아이콘 교체.
드롭다운 메뉴에서는 기존 OpenAI 로고를 유지하기 위해 `codex_statusbar_logo.png`을
별도 파일로 분리하고 `StatusBarIcon.codex`만 새 파일을 로드하도록 변경.

Files:
- `Sources/UsageMonitor/Resources/codex_statusbar_logo.png` (new)
- `Sources/UsageMonitor/UI/IconRenderer.swift`

#### 2) feat(icons): update OpenRouter logo to lobehub avatar style

`@lobehub/icons`의 `OpenRouter.Avatar` 스타일로 로고 교체.
보라색(#6566F1) 라운드 사각형 배경 + 흰색 포크 아이콘, 640x640.

Files:
- `Sources/UsageMonitor/Resources/openrouter_logo.png`

#### 3) style(statusbar): reduce provider icon size in status bar

status bar의 provider 아이콘 크기를 17pt → 15pt로 축소 (~12%).
`drawProviderSegment`, `drawOpenRouterSegment` 모두 적용.

Files:
- `Sources/UsageMonitor/UI/IconRenderer.swift`

### Planned Commit Units

1. `feat(icons): replace Codex status bar icon with ChatGPT blossom logo`
2. `feat(icons): update OpenRouter logo to lobehub avatar style`
3. `chore(build): update app bundle with new icon assets`
4. `docs: update changelog for 2026-02-20 icon updates`
5. `style(statusbar): reduce provider icon size in status bar`

---

## 2026-02-15

Branch: `main`

### Session Work (Deduplicated)

#### 1) fix(claude): reset keychain lookup flag on OAuth retry

OAuth 토큰 만료 후 refresh 실패 시 `cachedOAuth = nil`만 하고
`didAttemptInteractiveKeychainLookup`을 리셋하지 않아 키체인 재읽기가
영구 차단되던 버그 수정. `resetCachedState()` 메서드로 통합.

Files:
- `Sources/UsageMonitorCore/Providers/Claude/ClaudeProvider.swift`

#### 2) fix(store): clear stale data on error and preserve trend history

provider fetch 에러 시 기존 데이터가 남아 10분 후 `isStale` 블랙 오버레이가
표시되던 문제 수정. `clearStaleData(for:)` 추가로 에러 시 해당 provider 데이터 nil 처리.
`updateStore(with:)`에서 현재 데이터가 nil일 때 `previousData`를 보존하여
에러→복구 전환 시 trend 화살표가 소실되지 않도록 보호.

Files:
- `Sources/UsageMonitor/Store/UsageStore.swift`

#### 3) fix(statusbar): sync icon update on provider error changes

`$providerErrors` Combine 구독에 `updateIcon()` 누락으로 에러 발생 시
메뉴는 갱신되지만 status bar 아이콘은 갱신되지 않던 불일치 수정.

Files:
- `Sources/UsageMonitor/UI/StatusItemController.swift`

### Planned Commit Units

1. `fix(claude): reset keychain lookup flag on OAuth retry`
2. `fix(store): clear stale data on error and preserve trend history`
3. `fix(statusbar): sync icon update on provider error changes`
4. `docs: update changelog for 2026-02-15 session fixes`
