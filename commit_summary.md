# Commit Summary

Date: 2026-02-15
Branch: `main`

## Session Work (Deduplicated)

### 1) fix(claude): reset keychain lookup flag on OAuth retry

OAuth 토큰 만료 후 refresh 실패 시 `cachedOAuth = nil`만 하고
`didAttemptInteractiveKeychainLookup`을 리셋하지 않아 키체인 재읽기가
영구 차단되던 버그 수정. `resetCachedState()` 메서드로 통합.

Files:
- `Sources/UsageMonitorCore/Providers/Claude/ClaudeProvider.swift`

### 2) fix(store): clear stale data on error and preserve trend history

provider fetch 에러 시 기존 데이터가 남아 10분 후 `isStale` 블랙 오버레이가
표시되던 문제 수정. `clearStaleData(for:)` 추가로 에러 시 해당 provider 데이터 nil 처리.
`updateStore(with:)`에서 현재 데이터가 nil일 때 `previousData`를 보존하여
에러→복구 전환 시 trend 화살표가 소실되지 않도록 보호.

Files:
- `Sources/UsageMonitor/Store/UsageStore.swift`

### 3) fix(statusbar): sync icon update on provider error changes

`$providerErrors` Combine 구독에 `updateIcon()` 누락으로 에러 발생 시
메뉴는 갱신되지만 status bar 아이콘은 갱신되지 않던 불일치 수정.

Files:
- `Sources/UsageMonitor/UI/StatusItemController.swift`

## Planned Commit Units

1. `fix(claude): reset keychain lookup flag on OAuth retry`
2. `fix(store): clear stale data on error and preserve trend history`
3. `fix(statusbar): sync icon update on provider error changes`
4. `docs: update changelog for 2026-02-15 session fixes`
