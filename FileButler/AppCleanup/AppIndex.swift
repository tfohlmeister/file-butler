import Foundation

struct AppRecord {
    let bundleID: String
    let path: String
}

class AppIndex {
    private var index: [String: AppRecord] = [:]
    private var refreshTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "file-butler.app-index")

    func start() {
        queue.async { [weak self] in
            self?.refreshOnQueue()
        }

        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 1800, repeating: 1800)
        timer.setEventHandler { [weak self] in
            self?.refreshOnQueue()
        }
        timer.resume()
        refreshTimer = timer
    }

    func stop() {
        refreshTimer?.cancel()
        refreshTimer = nil
    }

    func bundleIdentifier(forApp appName: String) -> String? {
        // First try the trash for the recently deleted app
        let trashPath = NSString(string: "~/.Trash").expandingTildeInPath
        let trashAppPath = trashPath + "/" + appName
        if let bundleID = readBundleID(atAppPath: trashAppPath) {
            return bundleID
        }

        // Fallback to index
        return queue.sync { index[appName]?.bundleID }
    }

    /// Called from any thread; dispatches to queue internally.
    func refresh() {
        queue.async { [weak self] in
            self?.refreshOnQueue()
        }
    }

    /// Must be called on `queue`.
    private func refreshOnQueue() {
        let paths = [
            "/Applications",
            NSString(string: "~/Applications").expandingTildeInPath
        ]

        var newIndex: [String: AppRecord] = [:]
        let fm = FileManager.default

        for basePath in paths {
            guard let contents = try? fm.contentsOfDirectory(atPath: basePath) else { continue }
            for item in contents {
                guard item.hasSuffix(".app") else { continue }
                let appPath = basePath + "/" + item
                guard let bundleID = readBundleID(atAppPath: appPath) else { continue }
                newIndex[item] = AppRecord(bundleID: bundleID, path: appPath)
            }
        }

        index = newIndex
        Logger.debug("AppIndex refreshed: \(newIndex.count) apps indexed")
    }

    private func readBundleID(atAppPath appPath: String) -> String? {
        let plistPath = appPath + "/Contents/Info.plist"
        guard let data = FileManager.default.contents(atPath: plistPath),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let bundleID = plist["CFBundleIdentifier"] as? String else {
            return nil
        }
        return bundleID
    }
}
