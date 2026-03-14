import Cocoa

class CleanupPanel: NSObject {
    private var panel: NSPanel?
    private var items: [LeftoverItem]
    private let appName: String
    private var totalLabel: NSTextField?

    private static let sizeFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        return f
    }()

    init(appName: String, items: [LeftoverItem]) {
        self.appName = appName
        self.items = items
    }

    func show() {
        let panelWidth: CGFloat = 560

        // Header
        let header = NSTextField(labelWithString: "\(appName) wurde deinstalliert")
        header.font = NSFont.boldSystemFont(ofSize: 15)

        // Rows
        var rowViews: [NSView] = []
        for (index, item) in items.enumerated() {
            let row = makeRow(item: item, index: index)
            rowViews.append(row)
        }

        // List stack
        let listStack = NSStackView(views: rowViews)
        listStack.orientation = .vertical
        listStack.alignment = .leading
        listStack.spacing = 2

        // Footer
        let selectedSize = items.filter { $0.selected }.reduce(UInt64(0)) { $0 + $1.size }
        let totalStr = CleanupPanel.sizeFormatter.string(fromByteCount: Int64(selectedSize))
        let total = NSTextField(labelWithString: "Auswahl: \(totalStr)")
        total.font = NSFont.systemFont(ofSize: 12)
        totalLabel = total

        let closeBtn = NSButton(title: "Schließen", target: self, action: #selector(closePanel))
        closeBtn.bezelStyle = .rounded

        let trashBtn = NSButton(title: "In den Papierkorb", target: self, action: #selector(trashSelected))
        trashBtn.bezelStyle = .rounded
        trashBtn.keyEquivalent = "\r"

        let buttonSpacer = NSView()
        let footerStack = NSStackView(views: [total, buttonSpacer, closeBtn, trashBtn])
        footerStack.orientation = .horizontal
        footerStack.alignment = .centerY
        footerStack.spacing = 10
        buttonSpacer.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)

        // Main stack
        let mainStack = NSStackView(views: [header, listStack, footerStack])
        mainStack.orientation = .vertical
        mainStack.alignment = .leading
        mainStack.spacing = 12
        mainStack.edgeInsets = NSEdgeInsets(top: 16, left: 20, bottom: 16, right: 20)
        mainStack.translatesAutoresizingMaskIntoConstraints = false

        // Ensure footer and list rows stretch full width
        footerStack.translatesAutoresizingMaskIntoConstraints = false
        listStack.translatesAutoresizingMaskIntoConstraints = false
        for row in rowViews {
            row.translatesAutoresizingMaskIntoConstraints = false
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: 200),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "App Cleanup"
        panel.isFloatingPanel = true
        panel.level = .floating

        panel.contentView!.addSubview(mainStack)
        NSLayoutConstraint.activate([
            mainStack.topAnchor.constraint(equalTo: panel.contentView!.topAnchor),
            mainStack.bottomAnchor.constraint(equalTo: panel.contentView!.bottomAnchor),
            mainStack.leadingAnchor.constraint(equalTo: panel.contentView!.leadingAnchor),
            mainStack.trailingAnchor.constraint(equalTo: panel.contentView!.trailingAnchor),
            footerStack.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor, constant: -20),
            listStack.trailingAnchor.constraint(equalTo: mainStack.trailingAnchor, constant: -20),
        ])
        for row in rowViews {
            row.leadingAnchor.constraint(equalTo: listStack.leadingAnchor).isActive = true
            row.trailingAnchor.constraint(equalTo: listStack.trailingAnchor).isActive = true
        }

        panel.setContentSize(mainStack.fittingSize)
        // Enforce minimum width
        if panel.frame.width < panelWidth {
            panel.setContentSize(NSSize(width: panelWidth, height: mainStack.fittingSize.height))
        }
        panel.center()

        self.panel = panel
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeRow(item: LeftoverItem, index: Int) -> NSView {
        let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(checkboxToggled(_:)))
        checkbox.state = item.selected ? .on : .off
        checkbox.tag = index
        checkbox.translatesAutoresizingMaskIntoConstraints = false
        checkbox.widthAnchor.constraint(equalToConstant: 18).isActive = true

        let category = NSTextField(labelWithString: item.category)
        category.font = NSFont.systemFont(ofSize: 12)
        category.textColor = .secondaryLabelColor
        category.translatesAutoresizingMaskIntoConstraints = false
        category.widthAnchor.constraint(equalToConstant: 140).isActive = true
        category.setContentHuggingPriority(.required, for: .horizontal)
        category.setContentCompressionResistancePriority(.required, for: .horizontal)

        let name = NSTextField(labelWithString: item.displayName)
        name.font = NSFont.systemFont(ofSize: 13)
        name.lineBreakMode = .byTruncatingMiddle
        name.setContentHuggingPriority(.defaultLow - 1, for: .horizontal)
        name.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        let sizeStr = CleanupPanel.sizeFormatter.string(fromByteCount: Int64(item.size))
        let size = NSTextField(labelWithString: sizeStr)
        size.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        size.alignment = .right
        size.translatesAutoresizingMaskIntoConstraints = false
        size.widthAnchor.constraint(equalToConstant: 70).isActive = true
        size.setContentHuggingPriority(.required, for: .horizontal)

        let row = NSStackView(views: [checkbox, category, name, size])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 8
        return row
    }

    @objc private func checkboxToggled(_ sender: NSButton) {
        items[sender.tag].selected = sender.state == .on
        updateTotalLabel()
    }

    private func updateTotalLabel() {
        let selectedSize = items.filter { $0.selected }.reduce(UInt64(0)) { $0 + $1.size }
        let totalStr = CleanupPanel.sizeFormatter.string(fromByteCount: Int64(selectedSize))
        totalLabel?.stringValue = "Auswahl: \(totalStr)"
    }

    @objc private func closePanel() {
        panel?.close()
        panel = nil
    }

    @objc private func trashSelected() {
        let selectedItems = items.filter { $0.selected }
        guard !selectedItems.isEmpty else {
            closePanel()
            return
        }

        var trashedCount = 0
        for item in selectedItems {
            do {
                try FileManager.default.trashItem(at: URL(fileURLWithPath: item.path), resultingItemURL: nil)
                trashedCount += 1
            } catch {
                Logger.error("Failed to trash \(item.path): \(error)")
            }
        }

        Logger.info("Trashed \(trashedCount)/\(selectedItems.count) leftover items for \(appName)")
        NotificationManager.shared.send(
            title: "Cleanup abgeschlossen",
            body: "\(trashedCount) Dateien von \(appName) in den Papierkorb verschoben"
        )
        closePanel()
    }
}
