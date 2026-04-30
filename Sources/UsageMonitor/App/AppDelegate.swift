import AppKit
import UsageMonitorCore

class AppDelegate: NSObject, NSApplicationDelegate {
    private var usageStore: UsageStore?
    private var statusItemController: StatusItemController?

    private let bundleID = "com.choihwanil.usagemonitor"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        clearTransientCacheOnLaunch()

        let refreshInterval = TimeInterval(UserDefaults.standard.integer(forKey: "refreshInterval"))
        let resolvedInterval = refreshInterval > 0 ? refreshInterval : 300

        var providers: [any Provider] = discoverClaudeProviders() as [any Provider]
        providers.append(contentsOf: discoverCodexProviders() as [any Provider])
        let tail: [any Provider] = [
            CopilotProvider(),
            GeminiProvider(),
            OpenRouterProvider(),
            KimiProvider()
        ]
        providers.append(contentsOf: tail)

        let store = UsageStore(providers: providers, refreshInterval: resolvedInterval)
        usageStore = store
        statusItemController = StatusItemController(usageStore: store)
        
        NotificationManager.shared.requestPermission()
        
        store.startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        usageStore?.stopPolling()
    }

    /// `~/.claude` 디렉터리에서 OAuth 파일을 탐색해 ClaudeProvider 인스턴스 목록을 만듭니다.
    /// - 라벨 파일이 하나도 없으면: keychain/env/credentials.json 기반 단일 "Claude Code"만 등록
    ///   (단일 계정 기존 사용자 호환)
    /// - 라벨 파일이 하나라도 있으면: 라벨 파일만 등록하고 keychain default는 무시
    ///   (사용자가 모든 활성 계정을 `auth.<label>.json`으로 박제했다고 가정 →
    ///    어느 계정으로 keychain 로그인되든 동일한 N개의 계정이 표시됨)
    /// 메뉴 폭/식별 가능한 색상 수를 고려해 최대 3개의 라벨 파일까지만 채택합니다.
    private func discoverClaudeProviders() -> [ClaudeProvider] {
        let maxAccounts = 3
        let fm = FileManager.default
        let claudeDir = ("~/.claude" as NSString).expandingTildeInPath

        var labeled: [ClaudeProvider] = []

        if let entries = try? fm.contentsOfDirectory(atPath: claudeDir) {
            // 알파벳 역순 정렬: 라벨 이름으로 표시 순서를 직관적으로 제어할 수 있게 함.
            let extraAuthFiles = entries
                .filter { $0.hasPrefix("auth.") && $0.hasSuffix(".json") && $0 != "auth.json" }
                .sorted(by: >)
                .prefix(maxAccounts)

            for file in extraAuthFiles {
                let fullPath = "\(claudeDir)/\(file)"
                let stripped = file
                    .replacingOccurrences(of: "auth.", with: "", options: .anchored)
                    .replacingOccurrences(of: ".json", with: "")
                let label = stripped.isEmpty ? file : stripped
                labeled.append(ClaudeProvider(
                    name: "Claude (\(label))",
                    credentialSource: .file(URL(fileURLWithPath: fullPath))
                ))
            }
        }

        return labeled.isEmpty ? [ClaudeProvider()] : labeled
    }

    /// `~/.codex` 디렉터리에서 OAuth 파일을 탐색해 CodexProvider 인스턴스 목록을 만듭니다.
    /// - 기본 `auth.json`은 "Codex"
    /// - 추가 계정은 `auth.<label>.json` 형태로 두면 "Codex (label)" 로 표시됩니다.
    /// 단일 계정만 있는 기존 사용자는 그대로 동작합니다.
    private func discoverCodexProviders() -> [CodexProvider] {
        let fm = FileManager.default
        let codexDir = ("~/.codex" as NSString).expandingTildeInPath
        let defaultAuth = "\(codexDir)/auth.json"

        var providers: [CodexProvider] = []
        var seenPaths = Set<String>()

        if fm.fileExists(atPath: defaultAuth) {
            providers.append(CodexProvider(name: "Codex", authFilePath: defaultAuth))
            seenPaths.insert(defaultAuth)
        }

        if let entries = try? fm.contentsOfDirectory(atPath: codexDir) {
            let extraAuthFiles = entries
                .filter { $0.hasPrefix("auth.") && $0.hasSuffix(".json") && $0 != "auth.json" }
                .sorted()

            for file in extraAuthFiles {
                let fullPath = "\(codexDir)/\(file)"
                guard !seenPaths.contains(fullPath) else { continue }

                let stripped = file
                    .replacingOccurrences(of: "auth.", with: "", options: .anchored)
                    .replacingOccurrences(of: ".json", with: "")
                let label = stripped.isEmpty ? file : stripped
                providers.append(CodexProvider(name: "Codex (\(label))", authFilePath: fullPath))
                seenPaths.insert(fullPath)
            }
        }

        if providers.isEmpty {
            // 파일이 없어도 등록은 해둬서, 토글이 켜져 있을 때 일관된 에러 표시.
            providers.append(CodexProvider(name: "Codex", authFilePath: defaultAuth))
        }

        return providers
    }

    private func clearTransientCacheOnLaunch() {
        URLCache.shared.removeAllCachedResponses()

        let fm = FileManager.default
        guard let cachesRoot = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        // Keep the current bundle cache directory intact for URLSession/URLCache internals.
        // We only clear legacy cache paths from older app names.
        let legacyCache = cachesRoot.appendingPathComponent("UsageMonitor")
        if fm.fileExists(atPath: legacyCache.path) {
            try? fm.removeItem(at: legacyCache)
        }

        let bundleCache = cachesRoot.appendingPathComponent(bundleID, isDirectory: true)
        if !fm.fileExists(atPath: bundleCache.path) {
            try? fm.createDirectory(at: bundleCache, withIntermediateDirectories: true)
        }
    }
}
