import Foundation
import AppKit
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()

    private override init() {
        super.init()
    }

    func setup() {
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if granted {
                Logger.info("Notification permission granted")
            } else if let error = error {
                Logger.error("Notification permission error: \(error)")
            }
        }
    }

    func send(title: String, body: String, filePath: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let path = filePath {
            content.userInfo = ["filePath": path]
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }

    // Show notifications even when app is in foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // Handle notification click: reveal file in Finder
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let filePath = response.notification.request.content.userInfo["filePath"] as? String {
            let url = URL(fileURLWithPath: filePath)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }
        completionHandler()
    }
}
