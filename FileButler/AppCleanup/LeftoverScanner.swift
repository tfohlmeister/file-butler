import Foundation

struct LeftoverItem {
    let path: String
    let displayName: String
    let category: String
    let size: UInt64
    var selected: Bool = true
}

enum LeftoverScanner {
    static func scan(bundleID: String, appName: String) -> [LeftoverItem] {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        let library = home + "/Library"
        var items: [LeftoverItem] = []

        let fm = FileManager.default

        // Application Support
        for name in [bundleID, appName] {
            let path = library + "/Application Support/" + name
            if fm.fileExists(atPath: path) {
                items.append(LeftoverItem(
                    path: path,
                    displayName: name,
                    category: "Application Support",
                    size: directorySize(path)
                ))
            }
        }

        // Caches
        for name in [bundleID, appName] {
            let path = library + "/Caches/" + name
            if fm.fileExists(atPath: path) {
                items.append(LeftoverItem(
                    path: path,
                    displayName: name,
                    category: "Cache",
                    size: directorySize(path)
                ))
            }
        }

        // Preferences
        let prefsDir = library + "/Preferences"
        if let contents = try? fm.contentsOfDirectory(atPath: prefsDir) {
            for file in contents {
                if file == bundleID + ".plist" || file.hasPrefix(bundleID + ".") && file.hasSuffix(".plist") {
                    let path = prefsDir + "/" + file
                    items.append(LeftoverItem(
                        path: path,
                        displayName: file,
                        category: "Einstellungen",
                        size: fileSize(path)
                    ))
                }
            }
        }

        // Logs
        let logsPath = library + "/Logs/" + appName
        if fm.fileExists(atPath: logsPath) {
            items.append(LeftoverItem(
                path: logsPath,
                displayName: appName,
                category: "Logs",
                size: directorySize(logsPath)
            ))
        }

        // Containers
        let containersPath = library + "/Containers/" + bundleID
        if fm.fileExists(atPath: containersPath) {
            items.append(LeftoverItem(
                path: containersPath,
                displayName: bundleID,
                category: "Container",
                size: directorySize(containersPath)
            ))
        }

        // Group Containers (match on bundleID suffix)
        let groupContainersDir = library + "/Group Containers"
        if let contents = try? fm.contentsOfDirectory(atPath: groupContainersDir) {
            for dir in contents {
                if dir.hasSuffix("." + bundleID) || dir.contains(bundleID) {
                    let path = groupContainersDir + "/" + dir
                    items.append(LeftoverItem(
                        path: path,
                        displayName: dir,
                        category: "Group Container",
                        size: directorySize(path)
                    ))
                }
            }
        }

        // Saved Application State
        let savedStatePath = library + "/Saved Application State/" + bundleID + ".savedState"
        if fm.fileExists(atPath: savedStatePath) {
            items.append(LeftoverItem(
                path: savedStatePath,
                displayName: bundleID + ".savedState",
                category: "Gespeicherter Zustand",
                size: directorySize(savedStatePath)
            ))
        }

        // HTTPStorages
        let httpStoragePath = library + "/HTTPStorages/" + bundleID
        if fm.fileExists(atPath: httpStoragePath) {
            items.append(LeftoverItem(
                path: httpStoragePath,
                displayName: bundleID,
                category: "HTTP-Speicher",
                size: directorySize(httpStoragePath)
            ))
        }

        // WebKit
        let webkitPath = library + "/WebKit/" + bundleID
        if fm.fileExists(atPath: webkitPath) {
            items.append(LeftoverItem(
                path: webkitPath,
                displayName: bundleID,
                category: "WebKit",
                size: directorySize(webkitPath)
            ))
        }

        // Cookies
        let cookiesPath = library + "/Cookies/" + bundleID + ".binarycookies"
        if fm.fileExists(atPath: cookiesPath) {
            items.append(LeftoverItem(
                path: cookiesPath,
                displayName: bundleID + ".binarycookies",
                category: "Cookies",
                size: fileSize(cookiesPath)
            ))
        }

        return items
    }

    private static func fileSize(_ path: String) -> UInt64 {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: path) else { return 0 }
        return attrs[.size] as? UInt64 ?? 0
    }

    private static func directorySize(_ path: String) -> UInt64 {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir) else { return 0 }
        guard isDir.boolValue else { return fileSize(path) }

        var total: UInt64 = 0
        guard let enumerator = fm.enumerator(atPath: path) else { return 0 }
        while let file = enumerator.nextObject() as? String {
            let fullPath = path + "/" + file
            if let attrs = try? fm.attributesOfItem(atPath: fullPath) {
                total += attrs[.size] as? UInt64 ?? 0
            }
        }
        return total
    }
}
