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

        var providers: [any Provider] = [ClaudeProvider()]
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
