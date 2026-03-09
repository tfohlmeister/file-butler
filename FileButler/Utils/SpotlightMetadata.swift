import Foundation

enum SpotlightMetadata {
    static func dateAdded(for url: URL) -> Date? {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return nil }
        guard let value = MDItemCopyAttribute(item, kMDItemDateAdded) else { return nil }
        return value as? Date
    }

    static func whereFroms(for url: URL) -> [String] {
        guard let item = MDItemCreateWithURL(nil, url as CFURL) else { return [] }
        guard let value = MDItemCopyAttribute(item, kMDItemWhereFroms) else { return [] }
        return value as? [String] ?? []
    }
}
