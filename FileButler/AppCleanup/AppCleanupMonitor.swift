import Foundation

class AppCleanupMonitor {
    let appIndex = AppIndex()
    let watcher = AppCleanupWatcher()
    private(set) var isRunning = false

    private var pendingCleanups: [String: DispatchWorkItem] = [:]
    private var lastScanResults: [String: (appName: String, bundleID: String, items: [LeftoverItem])] = [:]

    var onShowCleanupPanel: ((String, String, [LeftoverItem]) -> Void)?

    func start() {
        guard !isRunning else { return }
        isRunning = true

        appIndex.start()

        watcher.onAppRemoved = { [weak self] appName in
            self?.handleAppRemoved(appName)
        }
        watcher.start()

        Logger.info("AppCleanupMonitor started")
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false

        watcher.stop()
        appIndex.stop()

        for (_, item) in pendingCleanups {
            item.cancel()
        }
        pendingCleanups.removeAll()

        Logger.info("AppCleanupMonitor stopped")
    }

    func showPanel(forApp appName: String) {
        guard let result = lastScanResults[appName] else { return }
        onShowCleanupPanel?(result.appName, result.bundleID, result.items)
    }

    private func handleAppRemoved(_ appName: String) {
        // Cancel any existing pending cleanup for this app
        pendingCleanups[appName]?.cancel()

        // 30-second delay to handle app updates / Finder undo
        let workItem = DispatchWorkItem { [weak self] in
            self?.performCleanupCheck(appName)
        }
        pendingCleanups[appName] = workItem
        DispatchQueue.global().asyncAfter(deadline: .now() + 30, execute: workItem)
        Logger.debug("Scheduled cleanup check for \(appName) in 30s")
    }

    private func performCleanupCheck(_ appName: String) {
        pendingCleanups.removeValue(forKey: appName)

        // Check if app came back (update scenario)
        let paths = [
            "/Applications/" + appName,
            NSString(string: "~/Applications").expandingTildeInPath + "/" + appName
        ]
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                Logger.info("App \(appName) returned, skipping cleanup")
                return
            }
        }

        // Get bundle ID
        guard let bundleID = appIndex.bundleIdentifier(forApp: appName) else {
            Logger.warn("No bundle ID found for \(appName), trying name-based scan")
            let displayName = appName.replacingOccurrences(of: ".app", with: "")
            let items = LeftoverScanner.scan(bundleID: displayName, appName: displayName)
            if !items.isEmpty {
                lastScanResults[appName] = (displayName, displayName, items)
                showPanel(appName: displayName, items: items)
            }
            return
        }

        let displayName = appName.replacingOccurrences(of: ".app", with: "")
        let items = LeftoverScanner.scan(bundleID: bundleID, appName: displayName)

        guard !items.isEmpty else {
            Logger.info("No leftovers found for \(displayName) (\(bundleID))")
            return
        }

        lastScanResults[appName] = (displayName, bundleID, items)

        let totalSize = items.reduce(UInt64(0)) { $0 + $1.size }
        Logger.info("Found \(items.count) leftovers for \(displayName), total \(totalSize) bytes")

        showPanel(appName: displayName, items: items)
    }

    private func showPanel(appName: String, items: [LeftoverItem]) {
        DispatchQueue.main.async { [weak self] in
            self?.onShowCleanupPanel?(appName, "", items)
        }
    }
}
