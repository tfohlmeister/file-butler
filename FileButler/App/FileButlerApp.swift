import Cocoa
import ServiceManagement
import UserNotifications

@main
struct FileButlerMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var engine: Engine!
    var appCleanupMonitor: AppCleanupMonitor!
    private var activeCleanupPanel: CleanupPanel?

    func applicationDidFinishLaunching(_ notification: Notification) {
        loadEnvFile()
        setupMenuBar()
        NotificationManager.shared.setup()

        engine = Engine(rules: Rules.all)
        engine.start()

        appCleanupMonitor = AppCleanupMonitor()
        appCleanupMonitor.onShowCleanupPanel = { [weak self] appName, _, items in
            self?.showCleanupPanel(appName: appName, items: items)
        }
        NotificationManager.shared.onShowCleanupDetails = { [weak self] appName in
            self?.appCleanupMonitor.showPanel(forApp: appName + ".app")
        }
        if UserDefaults.standard.object(forKey: "appCleanupEnabled") == nil {
            UserDefaults.standard.set(true, forKey: "appCleanupEnabled")
        }
        if UserDefaults.standard.bool(forKey: "appCleanupEnabled") {
            appCleanupMonitor.start()
        }
    }

    private func showCleanupPanel(appName: String, items: [LeftoverItem]) {
        let panel = CleanupPanel(appName: appName, items: items)
        activeCleanupPanel = panel
        panel.show()
    }

    private func loadEnvFile() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let configDir = appSupport.appendingPathComponent("FileButler").path
        let envPath = configDir + "/.env"
        guard let contents = try? String(contentsOfFile: envPath, encoding: .utf8) else {
            Logger.debug("No .env file found at \(envPath)")
            return
        }
        var count = 0
        for line in contents.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            let parts = trimmed.split(separator: "=", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
            var value = String(parts[1]).trimmingCharacters(in: .whitespaces)
            // Strip surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            setenv(key, value, 1)
            count += 1
        }
        Logger.info("Loaded \(count) env vars from .env")
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
        appCleanupMonitor?.stop()
    }

    private func setupMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let iconPath = Bundle.main.path(forResource: "MenuBarIcon", ofType: "png"),
               let image = NSImage(contentsOfFile: iconPath) {
                image.isTemplate = true
                image.size = NSSize(width: 18, height: 18)
                button.image = image
            } else {
                button.title = "FB"
            }
        }

        let menu = NSMenu()

        let statusMenuItem = NSMenuItem(title: "FileButler is running", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)

        let rulesCount = Rules.all.count
        let rulesMenuItem = NSMenuItem(title: "\(rulesCount) rules active", action: nil, keyEquivalent: "")
        rulesMenuItem.isEnabled = false
        menu.addItem(rulesMenuItem)

        menu.addItem(NSMenuItem.separator())

        let launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin(_:)), keyEquivalent: "")
        launchAtLoginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(launchAtLoginItem)

        let appCleanupItem = NSMenuItem(title: "App Cleanup", action: #selector(toggleAppCleanup(_:)), keyEquivalent: "")
        appCleanupItem.state = UserDefaults.standard.bool(forKey: "appCleanupEnabled") ? .on : .off
        menu.addItem(appCleanupItem)

        menu.addItem(NSMenuItem.separator())

        let viewLogsItem = NSMenuItem(title: "View Logs", action: #selector(viewLogs), keyEquivalent: "l")
        menu.addItem(viewLogsItem)

        let restartItem = NSMenuItem(title: "Restart Engine", action: #selector(restartEngine), keyEquivalent: "r")
        menu.addItem(restartItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit FileButler", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func toggleLaunchAtLogin(_ sender: NSMenuItem) {
        let service = SMAppService.mainApp
        do {
            if service.status == .enabled {
                try service.unregister()
                sender.state = .off
                Logger.info("Launch at Login disabled")
            } else {
                try service.register()
                sender.state = .on
                Logger.info("Launch at Login enabled")
            }
        } catch {
            Logger.error("Failed to toggle Launch at Login: \(error)")
        }
    }

    @objc private func toggleAppCleanup(_ sender: NSMenuItem) {
        let enabled = !UserDefaults.standard.bool(forKey: "appCleanupEnabled")
        UserDefaults.standard.set(enabled, forKey: "appCleanupEnabled")
        sender.state = enabled ? .on : .off
        if enabled {
            appCleanupMonitor.start()
            Logger.info("App Cleanup enabled")
        } else {
            appCleanupMonitor.stop()
            Logger.info("App Cleanup disabled")
        }
    }

    @objc private func viewLogs() {
        NSWorkspace.shared.open(URL(fileURLWithPath: Logger.logFile))
    }

    @objc private func restartEngine() {
        engine?.stop()
        engine = Engine(rules: Rules.all)
        engine.start()
        Logger.info("Engine restarted")
    }

    @objc private func quitApp() {
        engine?.stop()
        appCleanupMonitor?.stop()
        NSApplication.shared.terminate(nil)
    }
}

