import Foundation

func hasExtension(_ exts: String...) -> Matcher {
    let lowered = exts.map { $0.lowercased() }
    return { file in lowered.contains(file.ext) }
}

func nameStartsWith(_ prefix: String) -> Matcher {
    return { file in file.name.hasPrefix(prefix) }
}

func nameContains(_ substring: String) -> Matcher {
    return { file in file.name.localizedCaseInsensitiveContains(substring) }
}

func nameMatches(_ pattern: String) -> Matcher {
    return { file in
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return false }
        let range = NSRange(file.name.startIndex..., in: file.name)
        return regex.firstMatch(in: file.name, range: range) != nil
    }
}

func isFolder() -> Matcher {
    return { file in file.isDirectory }
}

func isFile() -> Matcher {
    return { file in !file.isDirectory }
}

func olderThan(_ duration: Duration) -> Matcher {
    return { file in
        Date().timeIntervalSince(file.dateModified) > duration.timeInterval
    }
}

func addedBefore(_ duration: Duration) -> Matcher {
    return { file in
        Date().timeIntervalSince(file.dateAdded) > duration.timeInterval
    }
}

func notAddedToday() -> Matcher {
    return { file in
        !Calendar.current.isDateInToday(file.dateAdded)
    }
}

func hasTag(_ tag: String) -> Matcher {
    return { file in file.tags.contains(tag) }
}

func lacksTag(_ tag: String) -> Matcher {
    return { file in !file.tags.contains(tag) }
}

func hasGitRepo() -> Matcher {
    return { file in
        guard file.isDirectory else { return false }
        return FileManager.default.fileExists(atPath: (file.path as NSString).appendingPathComponent(".git"))
    }
}

func isEmpty() -> Matcher {
    return { file in
        if file.isDirectory {
            let contents = try? FileManager.default.contentsOfDirectory(atPath: file.path)
            let filtered = contents?.filter { !$0.hasPrefix(".") } ?? []
            return filtered.isEmpty
        }
        return file.size == 0
    }
}

func downloadedFrom(_ urlPrefix: String) -> Matcher {
    return { file in
        let urls = SpotlightMetadata.whereFroms(for: URL(fileURLWithPath: file.path))
        return urls.contains { $0.hasPrefix(urlPrefix) }
    }
}

func shellPasses(_ cmd: String) -> Matcher {
    return { file in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        let expanded = cmd.replacingOccurrences(of: "{path}", with: file.path)
            .replacingOccurrences(of: "{name}", with: file.name)
        process.arguments = ["-c", expanded]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }
}

func not(_ matcher: @escaping Matcher) -> Matcher {
    return { file in
        !matcher(file)
    }
}
