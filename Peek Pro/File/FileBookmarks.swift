import Foundation

nonisolated struct FileBookmark: Identifiable, Hashable, Sendable {
    let url: URL
    let bookmark: Data

    var id: URL { url }
    var name: String { url.lastPathComponent }
}

/// Files kept across launches as security-scoped bookmarks, because the sandbox forgets a file's
/// permission when the app quits. Newest first, one row per file.
nonisolated struct FileBookmarks: Equatable, Sendable {
    let storageKey: String
    let limit: Int
    private(set) var items: [FileBookmark]

    /// The Open Recent menu.
    static func recent(_ defaults: UserDefaults = .standard) -> FileBookmarks {
        FileBookmarks(storageKey: "recentFileBookmarks", limit: 10, defaults: defaults)
    }

    /// The files open in the sidebar, reopened at the next launch.
    static func open(_ defaults: UserDefaults = .standard) -> FileBookmarks {
        FileBookmarks(storageKey: "openFileBookmarks", limit: 50, defaults: defaults)
    }

    init(storageKey: String, limit: Int, items: [FileBookmark] = []) {
        self.storageKey = storageKey
        self.limit = limit
        self.items = Array(items.prefix(limit))
    }

    init(storageKey: String, limit: Int, defaults: UserDefaults) {
        let bookmarks = defaults.array(forKey: storageKey) as? [Data] ?? []
        self.init(storageKey: storageKey, limit: limit, items: bookmarks.compactMap { bookmark in
            Self.resolve(bookmark).map { FileBookmark(url: $0, bookmark: bookmark) }
        })
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(items.map(\.bookmark), forKey: storageKey)
    }

    mutating func add(_ file: FileBookmark) {
        remove(file.url)
        items.insert(file, at: 0)
        if items.count > limit { items.removeLast(items.count - limit) }
    }

    mutating func remove(_ url: URL) {
        items.removeAll { $0.url.standardizedFileURL == url.standardizedFileURL }
    }

    /// Swaps a bookmark in place, keeping the order: a resolved bookmark can go stale and be renewed.
    mutating func replace(_ url: URL, with file: FileBookmark) {
        guard let index = items.firstIndex(where: { $0.url.standardizedFileURL == url.standardizedFileURL }) else { return }
        items[index] = file
    }

    mutating func clear() {
        items = []
    }

    static func resolve(_ bookmark: Data) -> URL? {
        var isStale = false
        return try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
    }
}
