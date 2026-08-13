import Foundation

struct SecurityScopedBookmarkStore: Sendable {
    func makeBookmark(for url: URL) throws -> Data {
        try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
    }

    func resolve(_ data: Data) throws -> (url: URL, stale: Bool) {
        var stale = false
        let url = try URL(
            resolvingBookmarkData: data,
            options: [.withSecurityScope],
            relativeTo: nil,
            bookmarkDataIsStale: &stale
        )
        return (url, stale)
    }

    @MainActor
    func withAccess<T>(to url: URL, operation: () async throws -> T) async rethrows -> T {
        let started = url.startAccessingSecurityScopedResource()
        defer { if started { url.stopAccessingSecurityScopedResource() } }
        return try await operation()
    }
}
