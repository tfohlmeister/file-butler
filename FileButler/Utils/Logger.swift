import Foundation
import os

enum LogLevel: String {
    case debug = "DEBUG"
    case info = "INFO"
    case warn = "WARN"
    case error = "ERROR"
}

enum Logger {
    static var isDebug: Bool {
        ProcessInfo.processInfo.environment["DEBUG"] != nil
    }

    static let logFile: String = {
        let path = NSString(string: "~/Library/Logs/file-butler.log").expandingTildeInPath
        // Create/truncate on launch
        FileManager.default.createFile(atPath: path, contents: nil)
        return path
    }()

    private static let osLog = os.Logger(subsystem: "com.tfohlmeister.file-butler", category: "engine")

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return f
    }()

    private static let fileHandle: FileHandle? = {
        return FileHandle(forWritingAtPath: logFile)
    }()

    static func log(_ level: LogLevel, _ message: String) {
        if level == .debug && !isDebug { return }
        let timestamp = dateFormatter.string(from: Date())
        let line = "[\(timestamp)] \(level.rawValue) \(message)\n"

        // Write to log file
        if let data = line.data(using: .utf8) {
            fileHandle?.seekToEndOfFile()
            fileHandle?.write(data)
        }

        // Also write to unified log (Console.app)
        switch level {
        case .debug: osLog.debug("\(message, privacy: .public)")
        case .info:  osLog.info("\(message, privacy: .public)")
        case .warn:  osLog.warning("\(message, privacy: .public)")
        case .error: osLog.error("\(message, privacy: .public)")
        }
    }

    static func debug(_ message: String) { log(.debug, message) }
    static func info(_ message: String) { log(.info, message) }
    static func warn(_ message: String) { log(.warn, message) }
    static func error(_ message: String) { log(.error, message) }
}
