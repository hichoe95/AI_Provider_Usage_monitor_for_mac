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

        let providers: [any Provider] = [
            ClaudeProvider(),
            CodexProvider(),
            CopilotProvider(),
            GeminiProvider(),
            OpenRouterProvider()
        ]

        let store = UsageStore(providers: providers, refreshInterval: resolvedInterval)
        usageStore = store
        statusItemController = StatusItemController(usageStore: store)
        
        NotificationManager.shared.requestPermission()
        
        store.startPolling()
    }

    func applicationWillTerminate(_ notification: Notification) {
        usageStore?.stopPolling()
    }

    private func clearTransientCacheOnLaunch() {
        URLCache.shared.removeAllCachedResponses()

        let fm = FileManager.default
        guard let cachesRoot = fm.urls(for: .cachesDirectory, in: .userDomainMask).first else {
            return
        }

        let cacheTargets = [
            cachesRoot.appendingPathComponent(bundleID),
            cachesRoot.appendingPathComponent("UsageMonitor"),
        ]

        for target in cacheTargets where fm.fileExists(atPath: target.path) {
            try? fm.removeItem(at: target)
        }
    }
}
