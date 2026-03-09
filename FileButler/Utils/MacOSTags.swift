import Foundation

enum MacOSTags {
    static func get(for url: URL) -> [String] {
        guard let resourceValues = try? url.resourceValues(forKeys: [.tagNamesKey]) else {
            return []
        }
        return resourceValues.tagNames ?? []
    }

    static func add(_ tag: String, to url: URL) throws {
        var existingTags = get(for: url)
        guard !existingTags.contains(tag) else { return }
        existingTags.append(tag)
        var resourceValues = URLResourceValues()
        resourceValues.tagNames = existingTags
        var mutableURL = url
        try mutableURL.setResourceValues(resourceValues)
    }

    static func remove(_ tag: String, from url: URL) throws {
        var existingTags = get(for: url)
        existingTags.removeAll { $0 == tag }
        var resourceValues = URLResourceValues()
        resourceValues.tagNames = existingTags
        var mutableURL = url
        try mutableURL.setResourceValues(resourceValues)
    }
}
