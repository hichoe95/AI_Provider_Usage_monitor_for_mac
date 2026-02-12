import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    @AppStorage("claudeEnabled") var claudeEnabled = true
    @AppStorage("codexEnabled") var codexEnabled = true
    @AppStorage("copilotEnabled") var copilotEnabled = false
    @AppStorage("geminiEnabled") var geminiEnabled = false
    @AppStorage("openRouterEnabled") var openRouterEnabled = false
    @AppStorage("refreshInterval") var refreshInterval: Int = 300 // seconds
    @AppStorage("statusBarDetailedView") var statusBarDetailedView = true
    
    @AppStorage("notificationsEnabled") var notificationsEnabled = true
    @AppStorage("claude5hThreshold") var claude5hThreshold: Double = 80
    @AppStorage("claude7dThreshold") var claude7dThreshold: Double = 80
    @AppStorage("codex5hThreshold") var codex5hThreshold: Double = 80
    @AppStorage("codex7dThreshold") var codex7dThreshold: Double = 80
    @AppStorage("copilot5hThreshold") var copilot5hThreshold: Double = 80
    @AppStorage("copilot7dThreshold") var copilot7dThreshold: Double = 80
    @AppStorage("gemini5hThreshold") var gemini5hThreshold: Double = 80
    @AppStorage("gemini7dThreshold") var gemini7dThreshold: Double = 80
    @AppStorage("copilotMonthlyRequestLimit") var copilotMonthlyRequestLimit: Double = 300
    @AppStorage("openRouterThreshold") var openRouterThreshold: Double = 5.0
    
    var refreshIntervalDescription: String {
        switch refreshInterval {
        case 60: return "1 minute"
        case 300: return "5 minutes"
        case 900: return "15 minutes"
        default: return "5 minutes"
        }
    }
}
