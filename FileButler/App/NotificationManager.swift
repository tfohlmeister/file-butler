import Foundation
import AppKit
import UserNotifications

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private static let cleanupCategoryID = "APP_CLEANUP"
    private static let showDetailsActionID = "SHOW_CLEANUP_DETAILS"

    var onShowCleanupDetails: ((String) -> Void)?

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

        let showAction = UNNotificationAction(
            identifier: NotificationManager.showDetailsActionID,
            title: "Details anzeigen",
            options: [.foreground]
        )
        let cleanupCategory = UNNotificationCategory(
            identifier: NotificationManager.cleanupCategoryID,
            actions: [showAction],
            intentIdentifiers: []
        )
        center.setNotificationCategories([cleanupCategory])
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

    // Handle notification click: reveal file in Finder or show cleanup panel
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        if response.actionIdentifier == NotificationManager.showDetailsActionID ||
           (response.actionIdentifier == UNNotificationDefaultActionIdentifier &&
            response.notification.request.content.categoryIdentifier == NotificationManager.cleanupCategoryID) {
            if let appName = userInfo["cleanupAppName"] as? String {
                onShowCleanupDetails?(appName)
            }
        } else if let filePath = userInfo["filePath"] as? String {
            let url = URL(fileURLWithPath: filePath)
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        completionHandler()
    }

    func sendCleanupNotification(appName: String, itemCount: Int, totalSize: UInt64) {
        let content = UNMutableNotificationContent()
        content.title = "\(appName) wurde deinstalliert"
        let sizeStr = ByteCountFormatter.string(fromByteCount: Int64(totalSize), countStyle: .file)
        content.body = "\(itemCount) verbleibende Dateien gefunden (\(sizeStr))"
        content.sound = .default
        content.categoryIdentifier = NotificationManager.cleanupCategoryID
        content.userInfo = ["cleanupAppName": appName]

        let request = UNNotificationRequest(
            identifier: "cleanup-\(appName)",
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(request)
    }
}
