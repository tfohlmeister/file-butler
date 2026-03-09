import Foundation

struct FileInfo {
    var path: String
    var name: String
    var ext: String
    var isDirectory: Bool
    var dateModified: Date
    var dateAdded: Date
    var tags: [String]
    var size: UInt64

    init(url: URL) throws {
        let resourceValues = try url.resourceValues(forKeys: [
            .isDirectoryKey,
            .contentModificationDateKey,
            .creationDateKey,
            .tagNamesKey,
            .fileSizeKey,
            .totalFileSizeKey,
        ])

        self.path = url.path
        self.name = url.lastPathComponent
        self.ext = url.pathExtension.lowercased()
        self.isDirectory = resourceValues.isDirectory ?? false
        self.dateModified = resourceValues.contentModificationDate ?? Date()
        // Prefer Spotlight dateAdded, fall back to file creation date
        if let spotlightDate = SpotlightMetadata.dateAdded(for: url) {
            self.dateAdded = spotlightDate
        } else if let creationDate = resourceValues.creationDate {
            self.dateAdded = creationDate
        } else {
            self.dateAdded = self.dateModified
        }
        self.tags = resourceValues.tagNames ?? []
        self.size = UInt64(resourceValues.totalFileSize ?? resourceValues.fileSize ?? 0)
    }
}

typealias Matcher = (FileInfo) -> Bool
typealias Action = (inout FileInfo) throws -> Void

struct Rule {
    let name: String
    let watch: String
    let match: [Matcher]
    let action: [Action]
}

struct Duration {
    var minutes: Int = 0
    var hours: Int = 0
    var days: Int = 0
    var months: Int = 0

    var timeInterval: TimeInterval {
        var total: TimeInterval = 0
        total += Double(minutes) * 60
        total += Double(hours) * 3600
        total += Double(days) * 86400
        total += Double(months) * 30 * 86400
        return total
    }
}
