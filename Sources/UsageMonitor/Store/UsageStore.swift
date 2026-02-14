import Foundation
import Combine
import UsageMonitorCore

/// @MainActor ObservableObject for managing usage data from multiple providers
/// Handles periodic polling, error management, and UI state binding
@MainActor
final class UsageStore: ObservableObject {
    // MARK: - Published Properties
    
    @Published var claudeData: UsageData?
    @Published var codexData: UsageData?
    @Published var copilotData: UsageData?
    @Published var geminiData: UsageData?
    @Published var openRouterData: UsageData?
    @Published var providerErrors: [String: String] = [:]
    @Published var isLoading = false
    @Published var lastUpdatedTime: Date?
    
    // MARK: - Private Properties
    
    private let providers: [any Provider]
    private var timer: Timer?
    private var refreshInterval: TimeInterval
    private var cancellables = Set<AnyCancellable>()
    private var previousClaudeData: UsageData?
    private var previousCodexData: UsageData?
    private var previousCopilotData: UsageData?
    private var previousGeminiData: UsageData?
    private var previousOpenRouterData: UsageData?
    
    // MARK: - Initialization
    
    init(
        providers: [any Provider],
        refreshInterval: TimeInterval = 300
    ) {
        self.providers = providers
        self.refreshInterval = refreshInterval

        NotificationCenter.default.publisher(for: .credentialsDidChange)
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else {
                        return
                    }

                    await self.invalidateAllProviderCaches()
                    await self.refresh()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public Methods
    
    /// Start polling for usage data at configured interval
    func startPolling() {
        refreshInterval = resolvedRefreshInterval()

        Task {
            await refresh()
        }

        scheduleTimer()
    }
    
    /// Stop polling for usage data
    func stopPolling() {
        timer?.invalidate()
        timer = nil
    }
    
    /// Manually refresh usage data from all providers
    func refresh() async {
        isLoading = true
        defer { isLoading = false }
        
        var newErrors: [String: String] = [:]
        
        for provider in providers {
            guard isProviderEnabled(provider.name) else {
                continue
            }

            do {
                let data = try await provider.fetchUsage()
                updateStore(with: data)
                
                if isNotificationsEnabled {
                    checkThreshold(for: data)
                }
            } catch {
                newErrors[provider.name] = error.localizedDescription
                clearStaleData(for: provider.name)
            }
        }
        
        providerErrors = newErrors
        lastUpdatedTime = Date()
    }

    func sessionTrend(for providerName: String) -> Double? {
        func normalizedPercent(_ value: Double) -> Double {
            value < 1 ? value * 100 : value
        }

        let currentAndPrevious: (current: UsageData?, previous: UsageData?)?
        switch providerName {
        case "Claude Code", "Claude":
            currentAndPrevious = (claudeData, previousClaudeData)
        case "Codex":
            currentAndPrevious = (codexData, previousCodexData)
        case "Copilot":
            currentAndPrevious = (copilotData, previousCopilotData)
        case "Gemini":
            currentAndPrevious = (geminiData, previousGeminiData)
        case "OpenRouter":
            return nil
        default:
            currentAndPrevious = nil
        }

        guard
            let current = currentAndPrevious?.current?.sessionUsage,
            let previous = currentAndPrevious?.previous?.sessionUsage
        else {
            return nil
        }

        return normalizedPercent(current) - normalizedPercent(previous)
    }
    
    // MARK: - Private Methods
    
    private func clearStaleData(for providerName: String) {
        switch providerName {
        case "Claude Code":
            previousClaudeData = claudeData
            claudeData = nil
        case "Codex":
            previousCodexData = codexData
            codexData = nil
        case "Copilot":
            previousCopilotData = copilotData
            copilotData = nil
        case "Gemini":
            previousGeminiData = geminiData
            geminiData = nil
        case "OpenRouter":
            previousOpenRouterData = openRouterData
            openRouterData = nil
        default:
            break
        }
    }

    private func updateStore(with data: UsageData) {
        switch data.provider {
        case "Claude Code":
            if claudeData != nil { previousClaudeData = claudeData }
            claudeData = data
        case "Codex":
            if codexData != nil { previousCodexData = codexData }
            codexData = data
        case "Copilot":
            if copilotData != nil { previousCopilotData = copilotData }
            copilotData = data
        case "Gemini":
            if geminiData != nil { previousGeminiData = geminiData }
            geminiData = data
        case "OpenRouter":
            if openRouterData != nil { previousOpenRouterData = openRouterData }
            openRouterData = data
        default:
            break
        }
    }

    private func checkThreshold(for data: UsageData) {
        let defaults = UserDefaults.standard

        func normalize(_ val: Double) -> Double {
            val < 1 ? val * 100 : val
        }

        func threshold(_ key: String, fallback: Double) -> Double {
            guard defaults.object(forKey: key) != nil else {
                return fallback
            }
            return defaults.double(forKey: key)
        }

        switch data.provider {
        case "Claude Code":
            if let session = data.sessionUsage {
                let threshold = threshold("claude5hThreshold", fallback: 80)
                NotificationManager.shared.checkAndNotify(provider: "Claude 5h", usage: normalize(session), threshold: threshold)
            }
            if let weekly = data.weeklyUsage {
                let threshold = threshold("claude7dThreshold", fallback: 80)
                NotificationManager.shared.checkAndNotify(provider: "Claude 7d", usage: normalize(weekly), threshold: threshold)
            }
        case "Codex":
            if let session = data.sessionUsage {
                let threshold = threshold("codex5hThreshold", fallback: 80)
                NotificationManager.shared.checkAndNotify(provider: "Codex 5h", usage: normalize(session), threshold: threshold)
            }
            if let weekly = data.weeklyUsage {
                let threshold = threshold("codex7dThreshold", fallback: 80)
                NotificationManager.shared.checkAndNotify(provider: "Codex 7d", usage: normalize(weekly), threshold: threshold)
            }
        case "Copilot":
            if let session = data.sessionUsage {
                let threshold = threshold("copilot5hThreshold", fallback: 80)
                NotificationManager.shared.checkAndNotify(provider: "Copilot 5h", usage: normalize(session), threshold: threshold)
            }
            if let weekly = data.weeklyUsage {
                let threshold = threshold("copilot7dThreshold", fallback: 80)
                NotificationManager.shared.checkAndNotify(provider: "Copilot 7d", usage: normalize(weekly), threshold: threshold)
            }
        case "Gemini":
            if let session = data.sessionUsage {
                let threshold = threshold("gemini5hThreshold", fallback: 80)
                NotificationManager.shared.checkAndNotify(provider: "Gemini 5h", usage: normalize(session), threshold: threshold)
            }
            if let weekly = data.weeklyUsage {
                let threshold = threshold("gemini7dThreshold", fallback: 80)
                NotificationManager.shared.checkAndNotify(provider: "Gemini 7d", usage: normalize(weekly), threshold: threshold)
            }
        case "OpenRouter":
            if let credits = data.remainingCredits {
                let threshold = threshold("openRouterThreshold", fallback: 5)
                NotificationManager.shared.checkAndNotify(provider: "OpenRouter", usage: credits, threshold: threshold)
            }
        default:
            break
        }
    }

    private func scheduleTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else {
                    return
                }

                let latestInterval = self.resolvedRefreshInterval()
                if latestInterval != self.refreshInterval {
                    self.refreshInterval = latestInterval
                    self.scheduleTimer()
                    return
                }

                await self.refresh()
            }
        }
    }

    private func resolvedRefreshInterval() -> TimeInterval {
        let stored = TimeInterval(UserDefaults.standard.integer(forKey: "refreshInterval"))
        switch stored {
        case 60, 300, 900:
            return stored
        default:
            return 300
        }
    }

    private var isNotificationsEnabled: Bool {
        UserDefaults.standard.object(forKey: "notificationsEnabled") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "notificationsEnabled")
    }

    private func isProviderEnabled(_ providerName: String) -> Bool {
        func boolValue(_ key: String, default defaultValue: Bool) -> Bool {
            guard UserDefaults.standard.object(forKey: key) != nil else {
                return defaultValue
            }
            return UserDefaults.standard.bool(forKey: key)
        }

        switch providerName {
        case "Claude Code":
            return boolValue("claudeEnabled", default: true)
        case "Codex":
            return boolValue("codexEnabled", default: true)
        case "Copilot":
            return boolValue("copilotEnabled", default: false)
        case "Gemini":
            return boolValue("geminiEnabled", default: false)
        case "OpenRouter":
            return boolValue("openRouterEnabled", default: false)
        default:
            return true
        }
    }

    private func invalidateAllProviderCaches() async {
        for provider in providers {
            await provider.invalidateCache()
        }
    }
}
