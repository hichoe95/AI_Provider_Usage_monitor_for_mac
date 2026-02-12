# UsageMonitor

macOS 메뉴바에서 Claude, Codex, Copilot, Gemini, OpenRouter 사용량을 확인하는 네이티브 앱입니다.

[English README](README_EN.md)

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

![UsageMonitor App Icon](docs/images/app-icon.png)
![UsageMonitor Dropdown Demo](docs/images/usage-monitor-demo.gif)
![UsageMonitor Dropdown](docs/images/usage-monitor-dropdown.png)

## 스크린샷

### 기본 화면

![Default View Screenshot](docs/images/default-view-example.png)

### 알림 예시

![Notification Screenshot](docs/images/notification-example.png)

## 핵심 기능

- 메뉴바에서 provider별 사용량(5h / 7d) 시각화
- OpenRouter 잔액($) 표시
- provider on/off, 갱신 주기, 알림 임계치 설정
- Keychain/로컬 인증 세션 기반 자동 조회

## 시스템 요구사항

- macOS 14 이상
- Apple Silicon / Intel 모두 가능 (SwiftPM 빌드 환경 필요)
- Swift 6.0 toolchain (`swift --version`)
- 네트워크 연결

## 빠른 시작

### 1) 소스에서 바로 실행

```bash
git clone https://github.com/<YOUR_ACCOUNT>/AI_provider_usage_monitor.git
cd AI_provider_usage_monitor
swift build
./Scripts/package_app.sh
open UsageMonitor.app
```

### 2) 설치 스크립트 사용

```bash
./Scripts/install_app.sh
```

설치 스크립트 동작:

1. release 빌드
2. `UsageMonitor.app` 생성
3. `/Applications` (권한 없으면 `~/Applications`)에 복사
4. 앱 실행

## 인증이 필요한 이유 (중요)

이 앱은 각 provider의 사용량 API를 직접 호출합니다.

즉, provider 입장에서 "누가 조회하는지"를 증명할 토큰/API Key가 필요합니다. 이 인증 정보가 없으면 사용량 API 응답을 받을 수 없어서 `No data` 또는 인증 오류가 표시됩니다.

## auth login은 어디서 해야 하나?

짧게 말하면: **앱이 실행되는 로컬 Mac의 터미널에서 해야 합니다.**

이유:

- UsageMonitor는 **현재 로그인한 macOS 사용자 계정의**
  - `~/.claude`, `~/.codex`, `~/.copilot`, `~/.gemini` 파일
  - macOS Keychain
  을 읽습니다.
- 서버/원격 개발환경(SSH, cloud VM, devcontainer)에서 로그인하면 인증 정보는 "서버 쪽"에 저장됩니다.
- 메뉴바 앱은 "로컬 Mac"에서 실행되므로 서버에 있는 인증 파일/Keychain을 자동으로 볼 수 없습니다.

따라서 서버에서 코딩하더라도, UsageMonitor를 쓰려면 **로컬 Mac 터미널에서 provider 로그인(auth login)** 을 해줘야 값이 뜹니다.

추가로, Keychain 접근 팝업(접근 허용 알림창)이 뜨면 **`항상 허용(Always Allow)`** 을 권장합니다.  
`허용(Allow)`만 누르면 이후 실행/갱신 때 같은 팝업이 반복될 수 있습니다.

## Provider별 인증 소스

### Claude Code

우선순위:

1. Keychain `Claude Code-credentials`
2. `~/.claude/.credentials.json`
3. `~/.claude/auth.json`

### Codex

- 기본: `~/.codex/auth.json` OAuth 토큰
- CLI 로그인 세션이 유지되어야 조회 가능

### Copilot

우선순위:

1. `GH_TOKEN` / `GITHUB_TOKEN` / `COPILOT_TOKEN` 환경변수
2. Keychain `copilot-access-token`
3. `~/.copilot/config.json`
4. `~/.config/github-copilot/apps.json`
5. `~/.config/github-copilot/hosts.json`
6. `~/.config/gh/hosts.yml` (`oauth_token`)

### Gemini

우선순위:

1. `~/.gemini/oauth_creds.json` 등 OAuth 파일
2. `GEMINI_API_KEY` / `GOOGLE_API_KEY` 환경변수
3. Keychain `gemini-api-key`
4. `~/.gemini/.env`

### OpenRouter

- Settings에서 API Key 저장 (Keychain: `openrouter-api-key`)
- 기본은 OFF (수동 활성화 필요)

## 권장 로그인 절차 (로컬 Mac 기준)

1. 로컬 터미널에서 Claude/Codex/Copilot/Gemini CLI 로그인
2. `UsageMonitor.app` 실행
3. 메뉴에서 `Refresh Now`
4. Settings에서 필요한 provider만 ON

참고: CLI 버전마다 명령은 다를 수 있으므로 `--help`로 확인하세요.
예: `codex --help`, `gemini --help`, `claude --help`, `gh --help`

## 앱 사용법

1. 메뉴바 아이콘 클릭
2. provider별 5h / 7d 게이지 확인
3. OpenRouter 잔액 확인
4. `Refresh Now`로 즉시 갱신
5. `Settings...`에서 설정 변경

## Settings 항목

- Providers on/off
- Refresh Interval: 1m / 5m / 15m
- Menu Bar Detailed View on/off
- Notifications on/off
- Provider별 임계치 설정
- OpenRouter API Key 저장

## 알림 동작

- Claude/Codex/Copilot/Gemini: 사용률이 임계치 이상일 때
- OpenRouter: 잔액이 임계치 이하일 때
- 동일 알림은 쿨다운 후 재알림

## 트러블슈팅

### 1) 값이 안 뜨고 `No data`만 보임

- 해당 provider 로그인 세션이 로컬에 있는지 확인
- 앱이 실행되는 계정과 로그인한 터미널 계정이 같은지 확인
- `Refresh Now` 실행

### 2) "The operation couldn't be completed"류 에러

- 최신 코드로 업데이트 후 재빌드
- 드롭다운 에러 문구 전체 확인 (이제 상세 메시지 표시)

### 3) OpenRouter 아이콘/잔액 표시 문제

- Settings에서 OpenRouter ON 확인
- API Key 저장 확인
- `Refresh Now` 실행

### 4) 서버에서는 되는데 로컬 앱은 안 됨

- 인증이 서버에만 존재하는 상황입니다.
- 로컬 Mac에서 다시 auth login 하세요.

### 5) Keychain 허용 팝업이 자주 뜸

- 접근 알림창이 뜰 때 `Always Allow`를 선택하세요.
- 이미 `Allow`만 선택한 경우, Keychain Access에서 UsageMonitor 관련 항목 접근 권한을 `Always Allow`로 변경하세요.

## 보안/개인정보

- 자격증명은 가능한 Keychain/로컬 인증 파일을 사용
- 사용자 입력 OpenRouter API Key는 Keychain 저장
- 앱 시작 시 URL 캐시/앱 캐시 정리 (설정/Keychain 유지)

## 배포 가이드 (GitHub)

### 1) 저장소 공개

```bash
git init
git add .
git commit -m "Initial release"
git branch -M main
git remote add origin https://github.com/<YOUR_ACCOUNT>/AI_provider_usage_monitor.git
git push -u origin main
```

### 2) 릴리즈 아티팩트 생성

```bash
./Scripts/package_app.sh
zip -r UsageMonitor-macOS.zip UsageMonitor.app
```

### 3) GitHub Release 등록

- tag 생성 (예: `v1.0.0`)
- `UsageMonitor-macOS.zip` 업로드
- README의 설치 섹션 링크 연결

## 개발

```bash
swift build
swift test
./Scripts/package_app.sh
```

## 프로젝트 구조

```text
AI_provider_usage_monitor/
├── Assets/
├── docs/images/
├── Scripts/
├── Sources/
│   ├── UsageMonitor/
│   └── UsageMonitorCore/
└── Package.swift
```

## 라이선스

MIT License
