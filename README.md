# AIUsageMonitor

<!-- MIRROR: keep section order aligned with README_EN.md -->

<div align="center">
  <img src="docs/images/app-icon.png" alt="AIUsageMonitor" width="180" />

  <h1>AIUsageMonitor</h1>

  <p><strong>WORK UNTIL USAGE IS EXHAUSTED.</strong></p>

  <p>Claude, Kimi, Codex, Copilot, Gemini, OpenRouter 사용량을<br/>macOS 메뉴바에서 한눈에 확인하세요.</p>

  <p>
    <img src="Sources/UsageMonitor/Resources/claude_logo.png" alt="Claude" width="24" />
    <img src="Sources/UsageMonitor/Resources/kimi_logo.png" alt="Kimi" width="24" />
    <img src="Sources/UsageMonitor/Resources/codex_logo.png" alt="Codex" width="24" />
    <img src="Sources/UsageMonitor/Resources/copilot_logo.png" alt="Copilot" width="24" />
    <img src="Sources/UsageMonitor/Resources/gemini_logo.png" alt="Gemini" width="24" />
    <img src="Sources/UsageMonitor/Resources/openrouter_logo.png" alt="OpenRouter" width="24" />
  </p>

  <p><strong>지원 Provider:</strong> Claude Code · Kimi · Codex · Copilot · Gemini · OpenRouter</p>

  <p>
    <a href="README_EN.md">English</a>&nbsp;&nbsp;|&nbsp;&nbsp;한국어
  </p>

  <p>
    <img src="https://img.shields.io/badge/macOS-14%2B-0078D4?style=flat-square&logo=apple&logoColor=white" alt="macOS 14+" />
    <img src="https://img.shields.io/badge/Swift-6.0-F05138?style=flat-square&logo=swift&logoColor=white" alt="Swift 6.0" />
    <img src="https://img.shields.io/badge/license-MIT-97CA00?style=flat-square" alt="MIT License" />
  </p>

  <img src="docs/images/screenshot-menu-2026-02-15.png" alt="AIUsageMonitor Screenshot" width="420" />
</div>

---

## 왜 필요한가요?

AI 코딩 도구(Claude Code, Codex, Copilot 등)를 쓰다 보면 **사용량 한도에 걸려서 작업이 멈추는 순간**이 옵니다.
그때서야 대시보드를 열어보면 이미 늦습니다.

AIUsageMonitor는 **메뉴바에서 실시간으로** 각 provider의 사용량을 보여줍니다.
한도에 가까워지면 알림을 보내, 작업 흐름이 끊기기 전에 대비할 수 있습니다.

---

## 주요 기능

| 기능 | 설명 |
|---|---|
| **실시간 사용량 바** | provider별 5시간/7일 사용량을 게이지 바로 표시 |
| **남은 시간 표시** | 각 구간의 리셋까지 남은 시간 (`2h 15m`, `3d 4h`) |
| **Codex Spark 사용량** | Codex의 Spark 모델 별도 사용량 추적 |
| **상태 트렌드** | 사용량 증감 트렌드 화살표 (`↑` / `↓`) |
| **사용량 알림** | 설정한 임계치 도달 시 macOS 알림 |
| **OpenRouter 잔액** | 남은 크레딧을 달러 단위로 표시 |
| **Kimi 사용량** | Kimi Code OAuth 세션 기반 5시간/7일 게이지 표시 |
| **대시보드 바로가기** | 메뉴에서 클릭 한 번으로 각 provider 대시보드 이동 |

**지원 Provider:**

| Provider | 인증 방식 | 표시 정보 |
|---|---|---|
| Claude Code | OAuth (Keychain + `~/.claude/auth.<label>.json`) | 5h, 7d, Sonnet 사용량 — **다중 계정 지원** |
| Kimi (Moonshot) | Kimi Code OAuth (`~/.kimi`) | 5h, 7d 사용량 |
| Codex (OpenAI) | OAuth (`~/.codex/auth.<label>.json`) | 5h, 7d, Spark 사용량 — 다중 계정 지원 |
| Copilot | GitHub CLI (`gh`) | 사용량 |
| Gemini | Google OAuth / API Key | 사용량 |
| OpenRouter | API Key | 잔액 ($) |

---

## 설치

```bash
git clone https://github.com/hichoe95/AI_Provider_Usage_monitor_for_mac.git
cd AI_Provider_Usage_monitor_for_mac
./install.sh
```

`install.sh`가 빌드부터 설치, 실행까지 자동으로 처리합니다.

> **요구사항:** macOS 14+, Xcode 16+ (Swift 6), Git

<details>
<summary>설치가 안 될 때</summary>

```bash
# Xcode CLI 도구 없을 때
xcode-select --install

# Swift/SDK 버전 불일치 시
sudo xcode-select -s /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -runFirstLaunch

# 설치 로그 확인
cat ${TMPDIR:-/tmp}/usagemonitor-install.log
```

</details>

---

## 초기 설정 (필수)

### 1. Provider 로그인

앱이 실행되는 **로컬 Mac 터미널**에서 각 provider에 로그인하세요.

```bash
claude login        # Claude Code
codex login         # Codex (OpenAI)
gh auth login       # Copilot (GitHub)
gemini auth         # Gemini
# Kimi: kimi login (Kimi Code OAuth)
```

> CLI 명령은 버전에 따라 다를 수 있으니 `--help`로 확인하세요.

### Provider별 빠른 설정 (아이콘 가이드)

> <img src="Sources/UsageMonitor/Resources/claude_logo.png" alt="Claude" width="16" /> **Claude Code** — `claude login` 후 `Settings`에서 Claude ON

> <img src="Sources/UsageMonitor/Resources/kimi_logo.png" alt="Kimi" width="16" /> **Kimi** — `kimi login` 후 `~/.kimi/credentials/kimi-code.json` OAuth 세션 사용

> <img src="Sources/UsageMonitor/Resources/codex_logo.png" alt="Codex" width="16" /> **Codex** — `codex login` 후 `~/.codex/auth.json` 세션 사용

> <img src="Sources/UsageMonitor/Resources/copilot_logo.png" alt="Copilot" width="16" /> **Copilot** — `gh auth login` 또는 `GH_TOKEN`/`GITHUB_TOKEN`

> <img src="Sources/UsageMonitor/Resources/gemini_logo.png" alt="Gemini" width="16" /> **Gemini** — `gemini auth` 또는 `GEMINI_API_KEY`

> <img src="Sources/UsageMonitor/Resources/openrouter_logo.png" alt="OpenRouter" width="16" /> **OpenRouter** — Settings의 API Key 입력란에 키 저장

### 2. Provider 활성화

메뉴바 아이콘 → `Settings...` → 사용할 provider ON → `Refresh Now` (`⌘R`)

### 3. 알림 설정

1. `Settings...` → `Notifications` → `Enable usage alerts` ON
2. `Request permission` 클릭 → `Notifications: Allowed` 확인
3. `Send test alert`로 배너가 뜨는지 확인

> `Denied`로 보이면 macOS **시스템 설정 → 알림 → AIUsageMonitor**에서 허용하세요.

---

## 인증 토큰 관리

각 provider마다 로그인 유지 기간이 다릅니다.

| Provider | 로그인 유지 기간 | 비고 |
|---|---|---|
| **Claude Code** | **자동 갱신** | `claude login` 필수 (아래 참고) |
| Codex (OpenAI) | ~10일 | 자동 갱신 |
| Copilot | GitHub 로그인 유지 | `gh auth login` |
| Gemini | Google 로그인 유지 | `gemini auth` |
| Kimi (Moonshot) | Kimi OAuth 세션 | `kimi login` (토큰은 `~/.kimi`에 저장) |

### Claude Code: 자동 토큰 갱신

`claude login`으로 로그인하면 **refresh token**이 함께 저장되어,
앱이 만료된 토큰을 자동으로 갱신합니다.
```bash
claude login    # 브라우저 인증 → refresh token 자동 저장
```

> **`setup-token`은 사용하지 마세요.** 8시간짜리 access token만 발급되며 자동 갱신이 불가합니다.
> 반드시 `claude login`을 사용하세요. Pro/Max 구독자만 해당됩니다.

### Claude 다중 계정 등록

여러 Claude 계정을 동시에 모니터링할 수 있습니다 (최대 3개).
계정마다 다른 색상의 로고로 구분되어 메뉴바와 드롭다운에 표시됩니다.

**원리:** `claude login`은 macOS Keychain의 동일한 슬롯에 토큰을 덮어씁니다.
멀티 계정을 유지하려면 각 계정 토큰을 `~/.claude/auth.<label>.json` 파일로 박제해야 합니다.

**계정 1개 추가 절차:**

```bash
# 1) 추가할 계정으로 claude CLI 로그인
claude login

# 2) Keychain에서 토큰을 라벨 파일로 박제 (라벨은 자유롭게 — 예: personal, work, team)
security find-generic-password -s "Claude Code-credentials" -a "$USER" -w \
  > ~/.claude/auth.personal.json && chmod 600 ~/.claude/auth.personal.json

# 3) 다음 계정도 같은 방식으로 반복
claude login   # 다른 계정
security find-generic-password -s "Claude Code-credentials" -a "$USER" -w \
  > ~/.claude/auth.work.json && chmod 600 ~/.claude/auth.work.json

# 4) 앱 재시작
killall AIUsageMonitor 2>/dev/null && open /Applications/AIUsageMonitor.app
```

**동작 방식:**

* `~/.claude/auth.<label>.json`이 1개 이상 있으면 **라벨 파일만** 표시됩니다
  (Keychain의 현재 활성 계정과 중복 표시 방지).
* 라벨 파일이 0개면 기존처럼 단일 "Claude Code" (Keychain) 모드로 동작합니다.
* 표시 순서는 라벨 알파벳 **역순** — 라벨 명을 조정해 메뉴 순서를 직접 제어할 수 있습니다.
* 토큰이 만료되면 앱이 자동으로 갱신해 같은 라벨 파일에 다시 씁니다 (Keychain 갱신과 동일).
* 메뉴에는 `Claude (라벨)` 형태로 표시됩니다 (예: `Claude (personal)`, `Claude (work)`).

**계정 식별 팁:** 추출한 토큰이 어느 계정인지 헷갈릴 때:

```bash
TOKEN=$(python3 -c "import json; print(json.load(open('$HOME/.claude/auth.personal.json'))['claudeAiOauth']['accessToken'])")
curl -s -H "Authorization: Bearer $TOKEN" -H "anthropic-version: 2023-06-01" \
  -H "anthropic-beta: oauth-2025-04-20" https://api.anthropic.com/api/oauth/profile \
  | python3 -m json.tool
```

이메일/플랜이 응답에 포함됩니다.

> Codex 다중 계정도 동일한 패턴으로 동작합니다 (`~/.codex/auth.<label>.json`).

---

## 단축키

| 단축키 | 동작 |
|---|---|
| `⌘R` | 새로고침 |
| `⌘,` | 설정 |
| `⌘D` | Claude 대시보드 |
| `⌘Q` | 종료 |

---

## 업데이트 / 삭제

```bash
# 업데이트
cd AI_Provider_Usage_monitor_for_mac
git pull && ./install.sh

# 삭제
cd AI_Provider_Usage_monitor_for_mac
./uninstall.sh
```

<details>
<summary>수동 삭제</summary>

```bash
rm -rf /Applications/AIUsageMonitor.app ~/Applications/AIUsageMonitor.app
defaults delete com.choihwanil.usagemonitor 2>/dev/null || true
rm -rf ~/Library/Application\ Support/UsageMonitor
rm -rf ~/Library/Caches/com.choihwanil.usagemonitor ~/Library/Caches/UsageMonitor
```

</details>

---

## 문제 해결

| 증상 | 해결 |
|---|---|
| `No data`만 보임 | 터미널에서 provider 재로그인 후 `⌘R` |
| Keychain 팝업 반복 | 팝업에서 `Always Allow` 선택 |
| OpenRouter 안 뜸 | Settings에서 ON + API key 저장 |
| 아이콘 안 바뀜 | 앱 종료 후 재설치 (Finder 캐시 지연) |
| 설치 경로 꼬임 | `rm -rf /Applications/AIUsageMonitor.app ~/Applications/AIUsageMonitor.app` 후 재설치 |

---

## FAQ

**Q. 왜 DMG 대신 소스 설치를 권장하나요?**

다운로드된 DMG 앱은 macOS Gatekeeper에 의해 차단될 수 있습니다.
로컬에서 직접 빌드하면 이 문제가 없습니다.

---

## 개발

```bash
swift build
swift test
./Scripts/package_app.sh
```

---

## 변경 로그

### 2026-04-30 (최신)

* **Claude 다중 계정 지원** — `~/.claude/auth.<label>.json` 패턴으로 최대 3개 계정 동시 모니터링
* **계정별 색상 구분** — 같은 Claude 로고를 코랄/블루/퍼플 3색으로 팅트해 메뉴바·드롭다운에서 시각적으로 구분
* **HTTP 캐시 격리 수정** — 멀티 계정 사용 시 URLCache 때문에 다른 계정 응답이 leak되던 문제 수정
* **Claude usage API 디코딩 보강** — `seven_day_sonnet.resets_at`이 `null`일 때 디코딩 실패하던 문제 수정 (사용량 0인 윈도우)
* 라벨 파일이 1개 이상 있으면 keychain default 항목은 자동 숨김 (중복 표시 방지)

### 2026-02-23

* Claude OAuth 토큰 자동 갱신 개선: 만료 시 credential 파일/키체인 재읽기 → 자체 refresh → 인터랙티브 키체인 3단계 복구
* Claude Code CLI와의 refresh token 경쟁 조건(race condition) 수정
* `setup-token` 대신 `claude login` 기반 자동 갱신으로 전환

### 2026-02-20
- Codex status bar 아이콘을 ChatGPT 블로섬 로고로 교체 (드롭다운은 기존 로고 유지)
- OpenRouter 로고를 lobehub Avatar 스타일로 업데이트
- status bar provider 아이콘 크기 축소 (17→15pt, ~12%)

<details>
<summary>2026-02-15</summary>

- Codex Spark 모델 사용량 추적 추가 (5h/7d 별도 표시)
- Claude OAuth 토큰 만료 후 키체인 재읽기 차단 버그 수정
- provider 에러 시 stale 데이터 클리어 (status bar 오버레이 방지)
- 에러→복구 전환 시 trend 화살표 소실 방지
- provider 에러 발생 시 status bar 아이콘-메뉴 동기화 수정
- 인증 토큰 관리 가이드 추가 (Claude `setup-token` 해결법)

</details>

<details>
<summary>2026-02-13</summary>

- 앱 이름 `AIUsageMonitor`로 통합
- 패키징/설치 스크립트 실행 파일명·앱 번들명 불일치 수정
- Xcode toolchain 자동 선택 + module cache 경로 보정
- 앱 시작 시 캐시 폴더 처리 안정화
- Codex 5h/7d 남은 시간 분리 표시 로직 보강
- Codex 파서에 `primary_window`/`secondary_window` + `reset_at`/`reset_after_seconds` 지원
- Codex 사용량 파싱 오탐(100% 고정) 방지
- 앱 아이콘 확대 및 `.icns` 재생성
- status bar 게이지 바 모서리 둥글게 렌더링

</details>

<details>
<summary>2026-02-12</summary>

- release 패키징 정리
- Swift 6 actor isolation 빌드 오류 수정
- Codex auth 오류 수정
- status bar 길이 조정

</details>

---

## License

[MIT License](LICENSE)
