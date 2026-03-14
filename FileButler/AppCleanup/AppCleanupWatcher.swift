import Foundation

class AppCleanupWatcher {
    private var eventStreams: [FSEventStreamRef] = []
    var onAppRemoved: ((String) -> Void)?

    private let watchedPaths = [
        "/Applications",
        NSString(string: "~/Applications").expandingTildeInPath
    ]

    func start() {
        for path in watchedPaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            startStream(for: path)
        }
    }

    func stop() {
        for stream in eventStreams {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        eventStreams.removeAll()
    }

    private func startStream(for path: String) {
        let pathsToWatch = [path] as CFArray

        var context = FSEventStreamContext()
        context.info = Unmanaged.passUnretained(self).toOpaque()

        guard let stream = FSEventStreamCreate(
            nil,
            appCleanupFSCallback,
            &context,
            pathsToWatch,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            1.0,
            UInt32(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagUseCFTypes)
        ) else {
            Logger.error("Failed to create AppCleanup FSEvent stream for \(path)")
            return
        }

        FSEventStreamSetDispatchQueue(stream, DispatchQueue.main)
        FSEventStreamStart(stream)
        eventStreams.append(stream)
        Logger.debug("AppCleanupWatcher started for \(path)")
    }

    func handleEvent(_ filePath: String, flags: FSEventStreamEventFlags) {
        let isRemoved = flags & UInt32(kFSEventStreamEventFlagItemRemoved) != 0
        let isRenamed = flags & UInt32(kFSEventStreamEventFlagItemRenamed) != 0

        guard isRemoved || isRenamed else { return }
        guard filePath.hasSuffix(".app") else { return }

        // Only process direct children of watched directories
        let parentDir = (filePath as NSString).deletingLastPathComponent
        guard watchedPaths.contains(parentDir) else { return }

        // Confirm the app no longer exists at this path
        guard !FileManager.default.fileExists(atPath: filePath) else { return }

        let appName = (filePath as NSString).lastPathComponent
        Logger.info("App removal detected: \(appName)")
        onAppRemoved?(appName)
    }
}

private func appCleanupFSCallback(
    _ streamRef: ConstFSEventStreamRef,
    _ clientCallBackInfo: UnsafeMutableRawPointer?,
    _ numEvents: Int,
    _ eventPaths: UnsafeMutableRawPointer,
    _ eventFlags: UnsafePointer<FSEventStreamEventFlags>,
    _ eventIds: UnsafePointer<FSEventStreamEventId>
) {
    guard let info = clientCallBackInfo else { return }
    let watcher = Unmanaged<AppCleanupWatcher>.fromOpaque(info).takeUnretainedValue()

    guard let paths = unsafeBitCast(eventPaths, to: NSArray.self) as? [String] else { return }

    for i in 0..<numEvents {
        watcher.handleEvent(paths[i], flags: eventFlags[i])
    }
}
