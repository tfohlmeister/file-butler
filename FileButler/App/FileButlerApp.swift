import Cocoa
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

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMenuBar()
        NotificationManager.shared.setup()

        engine = Engine(rules: Rules.all)
        engine.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        engine?.stop()
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

        let viewLogsItem = NSMenuItem(title: "View Logs", action: #selector(viewLogs), keyEquivalent: "l")
        menu.addItem(viewLogsItem)

        let restartItem = NSMenuItem(title: "Restart Engine", action: #selector(restartEngine), keyEquivalent: "r")
        menu.addItem(restartItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit FileButler", action: #selector(quitApp), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
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
        NSApplication.shared.terminate(nil)
    }
}

