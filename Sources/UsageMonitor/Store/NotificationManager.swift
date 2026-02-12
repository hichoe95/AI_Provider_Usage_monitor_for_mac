import Foundation
@preconcurrency import UserNotifications

@MainActor
final class NotificationManager: NSObject {
    static let shared = NotificationManager()
    private var lastNotifiedProviders: [String: Date] = [:]
    private let cooldownInterval: TimeInterval = 1800 // 30 minutes
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    nonisolated func requestPermission() {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                return
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        print("Notification permission error: \(error.localizedDescription)")
                        return
                    }
                    if !granted {
                        print("Notification permission denied by user")
                    }
                }
            case .denied:
                print("Notifications are denied in System Settings")
            @unknown default:
                return
            }
        }
    }
    
    func checkAndNotify(provider: String, usage: Double, threshold: Double) {
        // For OpenRouter, usage is remaining credits (dollars), so we alert if usage < threshold
        // For others, usage is percentage, so we alert if usage > threshold
        
        let shouldNotify: Bool
        let message: String
        
        if provider == "OpenRouter" {
            shouldNotify = usage <= threshold
            message = String(format: "Balance at $%.2f — running low", usage)
        } else {
            shouldNotify = usage >= threshold
            message = String(format: "Usage at %.0f%% — approaching limit", usage)
        }
        
        guard shouldNotify else { return }
        
        if let lastDate = lastNotifiedProviders[provider],
           Date().timeIntervalSince(lastDate) < cooldownInterval {
            return
        }
        
        sendNotification(title: "⚠️ \(provider) Usage Alert", body: message)
        lastNotifiedProviders[provider] = Date()
    }
    
    private nonisolated func sendNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        center.getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                let content = UNMutableNotificationContent()
                content.title = title
                content.body = body
                content.sound = .default

                let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
                center.add(request) { error in
                    if let error {
                        print("Failed to schedule notification: \(error.localizedDescription)")
                    }
                }
            case .notDetermined:
                center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                    if let error {
                        print("Notification permission error: \(error.localizedDescription)")
                        return
                    }
                    if granted {
                        self.sendNotification(title: title, body: body)
                    }
                }
            case .denied:
                print("Notification skipped because authorization is denied")
            @unknown default:
                return
            }
        }
    }
}

extension NotificationManager: UNUserNotificationCenterDelegate {
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}
