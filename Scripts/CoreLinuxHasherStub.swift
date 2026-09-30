#if os(Linux)
import Foundation

struct ExactFingerprint: Hashable, Codable, Sendable {
    let algorithm: String
    let digest: String
    let byteCount: Int64
}

actor ExactHasher {
    func hashFile(at url: URL) throws -> ExactFingerprint {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hash: UInt64 = 14695981039346656037
        var byteCount: Int64 = 0
        while true {
            let data = try handle.read(upToCount: 64 * 1024) ?? Data()
            if data.isEmpty { break }
            byteCount += Int64(data.count)
            for byte in data {
                hash ^= UInt64(byte)
                hash &*= 1099511628211
            }
        }
        return ExactFingerprint(algorithm: "fnv1a64-linux-smoke", digest: String(hash, radix: 16), byteCount: byteCount)
    }
}
#endif
