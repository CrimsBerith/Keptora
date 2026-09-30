#if os(Linux)
import Foundation

struct CoordinatedFileMover: Sendable {
    func moveItem(from source: URL, to destination: URL) throws {
        try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: source, to: destination)
    }
}
#endif
