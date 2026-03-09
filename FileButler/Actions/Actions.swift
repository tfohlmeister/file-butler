import Foundation
import AppKit

func moveTo(_ dest: String) -> Action {
    return { file in
        let expandedDest = NSString(string: dest).expandingTildeInPath
        let fm = FileManager.default
        try fm.createDirectory(atPath: expandedDest, withIntermediateDirectories: true)
        let destPath = uniquePath(for: (expandedDest as NSString).appendingPathComponent(file.name))
        try fm.moveItem(atPath: file.path, toPath: destPath)
        Logger.info("Moved \(file.name) -> \(expandedDest)")
        file.path = destPath
        file.name = (destPath as NSString).lastPathComponent
    }
}

func moveToTrash() -> Action {
    return { file in
        let url = URL(fileURLWithPath: file.path)
        var resultURL: NSURL?
        try FileManager.default.trashItem(at: url, resultingItemURL: &resultURL)
        Logger.info("Trashed \(file.name)")
    }
}

func sortIntoSubfolder(_ pattern: @escaping (FileInfo) -> String) -> Action {
    return { file in
        let subfolderName = pattern(file)
        let parentDir = (file.path as NSString).deletingLastPathComponent
        let destDir = (parentDir as NSString).appendingPathComponent(subfolderName)
        let fm = FileManager.default
        try fm.createDirectory(atPath: destDir, withIntermediateDirectories: true)
        let destPath = uniquePath(for: (destDir as NSString).appendingPathComponent(file.name))
        try fm.moveItem(atPath: file.path, toPath: destPath)
        Logger.info("Sorted \(file.name) -> \(subfolderName)/")
        file.path = destPath
        file.name = (destPath as NSString).lastPathComponent
    }
}

func rename(_ pattern: @escaping (FileInfo) -> String) -> Action {
    return { file in
        let newName = pattern(file)
        let parentDir = (file.path as NSString).deletingLastPathComponent
        let destPath = (parentDir as NSString).appendingPathComponent(newName)
        try FileManager.default.moveItem(atPath: file.path, toPath: destPath)
        Logger.info("Renamed \(file.name) -> \(newName)")
        file.path = destPath
        file.name = newName
        file.ext = URL(fileURLWithPath: newName).pathExtension.lowercased()
    }
}

func addTag(_ tag: String) -> Action {
    return { file in
        let url = URL(fileURLWithPath: file.path)
        try MacOSTags.add(tag, to: url)
        file.tags.append(tag)
        Logger.info("Tagged \(file.name) with '\(tag)'")
    }
}

func printFile() -> Action {
    return { file in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/lpr")
        process.arguments = [file.path]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus == 0 {
            Logger.info("Printed \(file.name)")
        } else {
            Logger.error("Print failed for \(file.name)")
        }
    }
}

func shell(_ cmd: String) -> Action {
    return { file in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let expanded = cmd.replacingOccurrences(of: "{path}", with: file.path)
            .replacingOccurrences(of: "{name}", with: file.name)
        process.arguments = ["-c", expanded]
        try process.run()
        process.waitUntilExit()
        if process.terminationStatus != 0 {
            Logger.warn("Shell command exited with \(process.terminationStatus): \(cmd)")
        }
    }
}

func openFile() -> Action {
    return { file in
        let url = URL(fileURLWithPath: file.path)
        NSWorkspace.shared.open(url)
        Logger.info("Opened \(file.name)")
    }
}

// Generate a unique path by appending (1), (2), etc. if the file already exists
func uniquePath(for path: String) -> String {
    let fm = FileManager.default
    guard fm.fileExists(atPath: path) else { return path }
    let dir = (path as NSString).deletingLastPathComponent
    let name = (path as NSString).deletingPathExtension.components(separatedBy: "/").last ?? ""
    let ext = (path as NSString).pathExtension
    var counter = 1
    while true {
        let suffix = ext.isEmpty ? "" : ".\(ext)"
        let candidate = (dir as NSString).appendingPathComponent("\(name) (\(counter))\(suffix)")
        if !fm.fileExists(atPath: candidate) { return candidate }
        counter += 1
    }
}

// Helper for date formatting in rules
func formatDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
}
