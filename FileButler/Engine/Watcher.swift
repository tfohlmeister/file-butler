import Foundation

class Watcher {
    let path: String
    let rules: [Rule]
    weak var engine: Engine?

    private var eventStream: FSEventStreamRef?
    private var debounceItems: [String: DispatchWorkItem] = [:]
    private let debounceQueue = DispatchQueue(label: "file-butler.debounce")

    init(path: String, rules: [Rule], engine: Engine) {
        self.path = path
        self.rules = rules
        self.engine = engine
    }

    func start() {
        let pathsToWatch = [path] as CFArray

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        guard let stream = FSEventStreamCreate(
            nil,
            fsEventsCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            Logger.error("Failed to create FSEvent stream for \(path)")
            return
        }

        eventStream = stream
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        Logger.debug("FSEvents started for \(path)")
    }

    func stop() {
        if let stream = eventStream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
            eventStream = nil
        }
    }

    func handleEvent(_ filePath: String) {
        // Only process direct children of the watched directory
        let parentDir = (filePath as NSString).deletingLastPathComponent
        guard parentDir == path else { return }

        let fileName = (filePath as NSString).lastPathComponent
        guard !fileName.hasPrefix(".") else { return }

        // Skip if file doesn't exist (was deleted/moved)
        guard FileManager.default.fileExists(atPath: filePath) else { return }

        // Debounce: 500ms per file
        debounceQueue.async { [weak self] in
            guard let self = self else { return }

            self.debounceItems[filePath]?.cancel()

            let item = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                Logger.debug("Processing event for \(fileName)")
                self.engine?.processFile(filePath, rules: self.rules)
                self.debounceQueue.async {
                    self.debounceItems.removeValue(forKey: filePath)
                }
            }

            self.debounceItems[filePath] = item
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.5, execute: item)
        }
    }
}

private func fsEventsCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<Watcher>.fromOpaque(info).takeUnretainedValue()

    guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }

    for i in 0..<numEvents {
        let flags = eventFlags[i]
        // Only process item-level events (created, modified, renamed)
        if flags & UInt32(kFSEventStreamEventFlagItemIsFile | kFSEventStreamEventFlagItemIsDir) != 0 {
            watcher.handleEvent(paths[i])
        }
    }
}
