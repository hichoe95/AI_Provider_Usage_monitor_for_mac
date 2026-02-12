# UsageMonitor

Claude, Codex, Copilot, Gemini, OpenRouter 사용량을 macOS 메뉴바에서 한눈에 보는 앱입니다.

[English README](README_EN.md)

![macOS](https://img.shields.io/badge/macOS-14%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0-orange)
![License](https://img.shields.io/badge/license-MIT-green)

![UsageMonitor Menu Screenshot](docs/images/screenshot-menu-2026-02-13.png)
![UsageMonitor Settings Screenshot](docs/images/screenshot-settings-2026-02-13.png)

## 1분 설치 (권장)

```bash
git clone https://github.com/hichoe95/AI_Provider_Usage_monitor_for_mac.git
cd AI_Provider_Usage_monitor_for_mac
./Scripts/install_app.sh
```

`install_app.sh`가 자동으로 처리합니다.
- release 빌드
- `UsageMonitor.app` 생성
- `/Applications` (권한 없으면 `~/Applications`) 복사
- quarantine 제거
- 앱 실행

## 처음 30초 세팅

1. 앱이 실행되는 **로컬 Mac 터미널**에서 provider 로그인
2. 메뉴바 아이콘 클릭 -> `Settings...`에서 필요한 provider ON
3. `Refresh Now`(⌘R) 클릭

CLI 로그인 명령은 버전에 따라 다를 수 있으니 `--help`로 확인하세요.

```bash
claude --help
codex --help
gh --help
gemini --help
```

## 알림 설정 방법 (필수)

1. 메뉴바 아이콘 -> `Settings...` -> `Notifications` 섹션 이동
2. `Enable usage alerts` ON
3. `Request permission` 클릭
4. 상태가 `Notifications: Allowed`인지 확인
5. `Send test alert` 클릭 후 실제 배너 표시 확인

권한 상태가 `Denied`라면 macOS `시스템 설정 -> 알림 -> UsageMonitor`에서 허용으로 변경하세요.

참고: 같은 provider 알림은 30분 쿨다운이 있어 바로 연속으로 재알림되지 않습니다.

## 메뉴에서 바로 보이는 것

- provider별 사용량 바: `5h`, `7d`, (Claude는 `sn` 포함)
- 각 바의 남은 시간: reset까지 `2h 15m`, `3d 4h` 형태로 표시
- 상태 점: 정상/오류 상태를 색으로 표시
- 트렌드: `↑` / `↓` (직전 대비)
- `Open Dashboard ↗` 빠른 이동
- 마지막 갱신 시각: `Updated ... ago`

## 단축키

- `⌘R`: Refresh Now
- `⌘,`: Settings
- `⌘D`: Claude Dashboard
- `⌘Q`: Quit

## 요구사항

| 항목 | 최소 요구사항 |
|---|---|
| OS | macOS 14 이상 |
| Xcode | 16 이상 (Swift 6 포함) |
| Git | 설치 필요 |
| 네트워크 | API 조회에 필요 |

확인 명령:

```bash
swift --version
git --version
```

## 업데이트

```bash
cd AI_Provider_Usage_monitor_for_mac
git pull
./Scripts/install_app.sh
```

## 변경 로그

### 2026-02-13 (최신)

- 드롭다운: `Sonnet Only` 배지 제거
- 드롭다운: Codex/기타 provider의 남은 시간 표기를 각 라인에서 더 안정적으로 보이도록 fallback 보강
- Claude reset 시간 파싱 강화 (epoch/ISO8601/소수초 ISO8601 지원)
- Notifications 설정 진단 추가 (`Re-check`, `Request permission`, `Send test alert`)
- README: 알림 설정 방법(필수) 섹션 추가
- README: 스크린샷 2장으로 교체
- 아이콘: 배경 투명화 및 `UsageMonitor.icns` 재생성

<details>
<summary>2026-02-12 변경 (접기)</summary>

- release 패키징 정리
- Swift 6 actor isolation 빌드 오류 수정
- Codex auth 오류 수정
- status bar 길이 조정
- README 업데이트

</details>

## 자주 막히는 문제

### 1) `No data`만 보일 때

- 로그인한 터미널 계정과 앱 실행 계정이 같은지 확인
- 로컬 Mac에서 provider 로그인 다시 진행
- `Refresh Now` 실행

### 2) Keychain 팝업이 반복될 때

- 팝업에서 `Always Allow` 선택
- 이미 `Allow`만 눌렀다면 Keychain Access에서 권한을 `Always Allow`로 변경

### 3) OpenRouter가 안 뜰 때

- Settings에서 OpenRouter ON
- API key 저장 후 `Refresh Now`

### 4) `swift` 명령이 없을 때

```bash
xcode-select --install
```

필요하면 Xcode 16 이상 설치 후 다시 실행하세요.

## 왜 DMG 대신 소스 설치를 권장하나요?

다운로드된 DMG 앱은 macOS Gatekeeper 정책 때문에 실행 차단될 수 있습니다.
로컬에서 직접 빌드/설치하면 실행 문제가 가장 적습니다.

## 개발

```bash
swift build
swift test
./Scripts/package_app.sh
```

## 라이선스

MIT License
