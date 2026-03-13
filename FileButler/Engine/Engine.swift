import Foundation

class Engine {
    let rules: [Rule]
    private var watchers: [Watcher] = []
    private var scanTimer: DispatchSourceTimer?

    // Track which rules have been applied to which files
    // Key: "ruleName::filePath", Value: (modification date, when processed)
    // Expires after 1 hour so time-based rules can re-trigger
    private static let processedTTL: TimeInterval = 3600
    private var processed: [String: (modified: Date, processedAt: Date)] = [:]
    private let processedQueue = DispatchQueue(label: "file-butler.processed")
    private let workerQueue = DispatchQueue(label: "file-butler.worker", qos: .utility)

    init(rules: [Rule]) {
        self.rules = rules
    }

    func start() {
        Logger.info("Engine starting with \(rules.count) rules")

        // Group rules by watch path
        var rulesByPath: [String: [Rule]] = [:]
        for rule in rules {
            let expanded = NSString(string: rule.watch).expandingTildeInPath
            rulesByPath[expanded, default: []].append(rule)
        }

        // Create watchers
        for (path, pathRules) in rulesByPath {
            let watcher = Watcher(path: path, rules: pathRules, engine: self)
            watcher.start()
            watchers.append(watcher)
            Logger.info("Watching \(path) (\(pathRules.count) rules)")
        }

        // Initial scan (delayed so the RunLoop is active)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            guard let self = self else { return }
            Logger.info("Running initial scan...")
            for (path, pathRules) in rulesByPath {
                self.scanDirectory(path, rules: pathRules)
            }
        }

        // Periodic scan every 30 minutes
        let timer = DispatchSource.makeTimerSource(queue: .global())
        timer.schedule(deadline: .now() + 1800, repeating: 1800)
        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            Logger.debug("Periodic scan triggered")
            for (path, pathRules) in rulesByPath {
                self.scanDirectory(path, rules: pathRules)
            }
        }
        timer.resume()
        scanTimer = timer
    }

    func stop() {
        Logger.info("Engine stopping")
        for watcher in watchers {
            watcher.stop()
        }
        watchers.removeAll()
        scanTimer?.cancel()
        scanTimer = nil
    }

    func scanDirectory(_ path: String, rules: [Rule]) {
        let fm = FileManager.default
        guard let entries = try? fm.contentsOfDirectory(atPath: path) else {
            Logger.error("Failed to scan \(path)")
            return
        }

        // Clean up expired entries
        processedQueue.sync {
            let now = Date()
            processed = processed.filter { now.timeIntervalSince($0.value.processedAt) < Engine.processedTTL }
        }

        for entry in entries {
            if entry.hasPrefix(".") { continue }
            let fullPath = (path as NSString).appendingPathComponent(entry)
            processFile(fullPath, rules: rules)
        }
    }

    private func processedKey(rule: String, path: String) -> String {
        "\(rule)::\(path)"
    }

    func processFile(_ path: String, rules: [Rule]) {
        workerQueue.async { [weak self] in
            guard let self = self else { return }
            guard FileManager.default.fileExists(atPath: path) else { return }

            for rule in rules {
                do {
                    let url = URL(fileURLWithPath: path)
                    guard FileManager.default.fileExists(atPath: path) else { return }
                    let fileInfo = try FileInfo(url: url)

                    // Check if this specific rule was already applied to this file
                    let key = self.processedKey(rule: rule.name, path: path)
                    let skip = self.processedQueue.sync { () -> Bool in
                        if let entry = self.processed[key] {
                            let expired = Date().timeIntervalSince(entry.processedAt) > Engine.processedTTL
                            if expired { return false }
                            return entry.modified >= fileInfo.dateModified
                        }
                        return false
                    }
                    if skip {
                        Logger.debug("Skipping rule \"\(rule.name)\" for \(fileInfo.name) (already applied)")
                        continue
                    }

                    var allMatch = true
                    for matcher in rule.match {
                        if !matcher(fileInfo) {
                            allMatch = false
                            break
                        }
                    }

                    if allMatch {
                        var mutableFile = fileInfo
                        for action in rule.action {
                            try action(&mutableFile)
                        }

                        Logger.info("Rule \"\(rule.name)\" matched: \(fileInfo.name)")
                        NotificationManager.shared.send(
                            title: rule.name,
                            body: fileInfo.name,
                            filePath: mutableFile.path
                        )

                        // Mark this rule as applied to this file
                        let now = Date()
                        self.processedQueue.sync {
                            self.processed[key] = (modified: fileInfo.dateModified, processedAt: now)
                        }

                        // If the file was moved/deleted, stop processing further rules
                        if !FileManager.default.fileExists(atPath: path) {
                            return
                        }
                    }
                } catch {
                    Logger.error("Error in rule \"\(rule.name)\" for \(path): \(error)")
                    // Mark as processed even on failure to prevent retry spam
                    let key = self.processedKey(rule: rule.name, path: path)
                    let now = Date()
                    self.processedQueue.sync {
                        self.processed[key] = (modified: Date.distantFuture, processedAt: now)
                    }
                }
            }
        }
    }
}
