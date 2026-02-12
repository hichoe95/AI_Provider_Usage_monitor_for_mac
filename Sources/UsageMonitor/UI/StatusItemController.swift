import AppKit
import Combine
import SwiftUI
import UsageMonitorCore

/// @MainActor controller for managing NSStatusBar integration
/// Handles status item creation, lifecycle, and reactive updates from UsageStore
@MainActor
final class StatusItemController: ObservableObject {
    // MARK: - Properties
    
    private var statusItem: NSStatusItem?
    private var cancellables = Set<AnyCancellable>()
    private let usageStore: UsageStore
    private var settingsWindowController: NSWindowController?
    
    // MARK: - Initialization
    
    /// Initialize StatusItemController with a UsageStore instance
    /// - Parameter usageStore: The store to subscribe to for usage data updates
    init(usageStore: UsageStore) {
        self.usageStore = usageStore
        setupStatusItem()
        bindStore()
        attachMenu()
        updateIcon()
    }
    
    // MARK: - Private Methods
    
    /// Create and configure the NSStatusItem
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        applyStatusItemLayout()
        
        // Set placeholder icon (SF Symbol)
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "gauge.high", accessibilityDescription: "Usage Monitor")
            button.image?.isTemplate = true
            button.imageScaling = .scaleNone
            button.imagePosition = .imageOnly
            button.title = ""
        }
    }

    private func applyStatusItemLayout() {
        guard let statusItem else {
            return
        }

        if isDetailedStatusBarEnabled {
            statusItem.length = NSStatusItem.variableLength
        } else {
            statusItem.length = NSStatusItem.squareLength
        }
    }

    private func isProviderEnabled(_ key: String) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            switch key {
            case "claudeEnabled", "codexEnabled":
                return true
            case "openRouterEnabled", "copilotEnabled", "geminiEnabled":
                return false
            default:
                return true
            }
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    private var isDetailedStatusBarEnabled: Bool {
        UserDefaults.standard.object(forKey: "statusBarDetailedView") == nil
            ? true
            : UserDefaults.standard.bool(forKey: "statusBarDetailedView")
    }
    
    /// Subscribe to UsageStore changes and update icon when data changes
    private func bindStore() {
        // Subscribe to Claude data changes
        usageStore.$claudeData
            .sink { [weak self] _ in
                self?.updateIcon()
                self?.updateMenu()
            }
            .store(in: &cancellables)
        
        // Subscribe to Codex data changes
        usageStore.$codexData
            .sink { [weak self] _ in
                self?.updateIcon()
                self?.updateMenu()
            }
            .store(in: &cancellables)
        
        // Subscribe to OpenRouter data changes
        usageStore.$openRouterData
            .sink { [weak self] _ in
                self?.updateIcon()
                self?.updateMenu()
            }
            .store(in: &cancellables)

        usageStore.$copilotData
            .sink { [weak self] _ in
                self?.updateIcon()
                self?.updateMenu()
            }
            .store(in: &cancellables)

        usageStore.$geminiData
            .sink { [weak self] _ in
                self?.updateIcon()
                self?.updateMenu()
            }
            .store(in: &cancellables)

        usageStore.$isLoading
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)

        usageStore.$providerErrors
            .sink { [weak self] _ in
                self?.updateMenu()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                self?.applyStatusItemLayout()
                self?.updateIcon()
                self?.updateMenu()
            }
            .store(in: &cancellables)
    }
    
    private func attachMenu() {
        statusItem?.menu = buildCurrentMenu()
    }
    
    private func updateMenu() {
        statusItem?.menu = buildCurrentMenu()
    }

    private func buildCurrentMenu() -> NSMenu {
        var sessionTrends: [String: Double] = [:]
        if let trend = usageStore.sessionTrend(for: "Claude Code") {
            sessionTrends["Claude"] = trend
        }
        if let trend = usageStore.sessionTrend(for: "Codex") {
            sessionTrends["Codex"] = trend
        }
        if let trend = usageStore.sessionTrend(for: "Copilot") {
            sessionTrends["Copilot"] = trend
        }
        if let trend = usageStore.sessionTrend(for: "Gemini") {
            sessionTrends["Gemini"] = trend
        }

        return MenuBuilder.buildMenu(
            claudeData: usageStore.claudeData,
            codexData: usageStore.codexData,
            copilotData: usageStore.copilotData,
            geminiData: usageStore.geminiData,
            openRouterData: usageStore.openRouterData,
            sessionTrends: sessionTrends,
            isLoading: usageStore.isLoading,
            providerErrors: usageStore.providerErrors,
            lastUpdated: usageStore.lastUpdatedTime,
            onRefresh: { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    await self.usageStore.refresh()
                }
            },
            onSettings: { [weak self] in
                self?.openSettings()
            }
        )
    }
    
    /// Open the Settings window
    private func openSettings() {
        NSApp.activate(ignoringOtherApps: true)

        if settingsWindowController == nil {
            let hostingController = NSHostingController(rootView: SettingsView())
            let window = NSWindow(contentViewController: hostingController)
            window.title = "UsageMonitor Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 420, height: 700))
            window.center()
            window.isReleasedWhenClosed = false
            settingsWindowController = NSWindowController(window: window)
        }

        settingsWindowController?.showWindow(nil)
        settingsWindowController?.window?.makeKeyAndOrderFront(nil)
    }
    
    /// Update the status bar icon based on current usage data
    private func updateIcon() {
        // Determine if data is stale (older than 10 minutes)
        let now = Date()
        let isStale = {
            if let claudeTime = usageStore.claudeData?.lastUpdated {
                return now.timeIntervalSince(claudeTime) > 600
            }
            if let codexTime = usageStore.codexData?.lastUpdated {
                return now.timeIntervalSince(codexTime) > 600
            }
            if let copilotTime = usageStore.copilotData?.lastUpdated {
                return now.timeIntervalSince(copilotTime) > 600
            }
            if let geminiTime = usageStore.geminiData?.lastUpdated {
                return now.timeIntervalSince(geminiTime) > 600
            }
            if let openRouterTime = usageStore.openRouterData?.lastUpdated {
                return now.timeIntervalSince(openRouterTime) > 600
            }
            return false
        }()
        
        // Use Claude data as primary, fallback to others
        let sessionUsage = usageStore.claudeData?.sessionUsage
            ?? usageStore.codexData?.sessionUsage
            ?? usageStore.copilotData?.sessionUsage
            ?? usageStore.geminiData?.sessionUsage
            ?? usageStore.openRouterData?.sessionUsage
        
        let weeklyUsage = usageStore.claudeData?.weeklyUsage
            ?? usageStore.codexData?.weeklyUsage
            ?? usageStore.copilotData?.weeklyUsage
            ?? usageStore.geminiData?.weeklyUsage
            ?? usageStore.openRouterData?.weeklyUsage

        if isDetailedStatusBarEnabled {
            var barProviders: [ProviderSegmentData] = []

            if isProviderEnabled("claudeEnabled") {
                barProviders.append(ProviderSegmentData(
                    icon: StatusBarIcon.claude, brandColor: BrandColor.claude,
                    session: usageStore.claudeData?.sessionUsage, weekly: usageStore.claudeData?.weeklyUsage))
            }
            if isProviderEnabled("codexEnabled") {
                barProviders.append(ProviderSegmentData(
                    icon: StatusBarIcon.codex, brandColor: BrandColor.codex,
                    session: usageStore.codexData?.sessionUsage, weekly: usageStore.codexData?.weeklyUsage))
            }
            if isProviderEnabled("copilotEnabled") {
                barProviders.append(ProviderSegmentData(
                    icon: StatusBarIcon.copilot, brandColor: BrandColor.copilot,
                    session: usageStore.copilotData?.sessionUsage, weekly: usageStore.copilotData?.weeklyUsage))
            }
            if isProviderEnabled("geminiEnabled") {
                barProviders.append(ProviderSegmentData(
                    icon: StatusBarIcon.gemini, brandColor: BrandColor.gemini,
                    session: usageStore.geminiData?.sessionUsage, weekly: usageStore.geminiData?.weeklyUsage))
            }

            let orData: OpenRouterSegmentData? = isProviderEnabled("openRouterEnabled")
                ? OpenRouterSegmentData(
                    icon: StatusBarIcon.openRouter, brandColor: BrandColor.openRouter,
                    credits: usageStore.openRouterData?.remainingCredits)
                : nil

            if barProviders.isEmpty && orData == nil {
                statusItem?.button?.image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Usage Monitor")
                statusItem?.button?.image?.isTemplate = true
                statusItem?.length = NSStatusItem.squareLength
                return
            }

            let detailedIcon = IconRenderer.renderDetailedProvidersIcon(
                barProviders: barProviders, openRouter: orData, isStale: isStale)
            statusItem?.button?.image = detailedIcon
            statusItem?.length = detailedIcon.size.width + 4
            return
        }

        if sessionUsage == nil && weeklyUsage == nil {
            statusItem?.button?.image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: "Usage Monitor")
            statusItem?.button?.image?.isTemplate = true
            statusItem?.length = NSStatusItem.squareLength
            return
        }
        
        let icon = IconRenderer.renderProviderIcon(
            sessionUsage: sessionUsage,
            weeklyUsage: weeklyUsage,
            isStale: isStale
        )
        
        statusItem?.button?.image = icon
        statusItem?.button?.image?.isTemplate = true
        statusItem?.length = NSStatusItem.squareLength
    }
}
