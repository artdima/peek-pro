import Foundation

nonisolated struct RecentFile: Identifiable, Hashable, Sendable {
    let url: URL
    let bookmark: Data

    var id: URL { url }
    var name: String { url.lastPathComponent }
}

/// The Open Recent list: newest first, one row per file, kept as security-scoped bookmarks
/// because the sandbox forgets a file's permission when the app quits.
nonisolated struct RecentFiles: Equatable, Sendable {
    static let limit = 10
    static let storageKey = "recentFileBookmarks"

    private(set) var items: [RecentFile]

    init(_ items: [RecentFile] = []) {
        self.items = Array(items.prefix(Self.limit))
    }

    init(defaults: UserDefaults) {
        let bookmarks = defaults.array(forKey: Self.storageKey) as? [Data] ?? []
        self.init(bookmarks.compactMap { bookmark in
            Self.resolve(bookmark).map { RecentFile(url: $0, bookmark: bookmark) }
        })
    }

    func save(to defaults: UserDefaults) {
        defaults.set(items.map(\.bookmark), forKey: Self.storageKey)
    }

    mutating func add(_ file: RecentFile) {
        remove(file.url)
        items.insert(file, at: 0)
        if items.count > Self.limit { items.removeLast(items.count - Self.limit) }
    }

    mutating func remove(_ url: URL) {
        items.removeAll { $0.url.standardizedFileURL == url.standardizedFileURL }
    }

    mutating func clear() {
        items = []
    }

    static func resolve(_ bookmark: Data) -> URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
}
