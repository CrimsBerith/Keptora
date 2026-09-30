import CryptoKit
import Foundation

struct ExactFingerprint: Hashable, Codable, Sendable {
    let algorithm: String
    let digest: String
    let byteCount: Int64
}

struct ExactHasher: Sendable {
    enum HasherError: LocalizedError {
        case notRegularFile(URL)

        var errorDescription: String? {
            switch self {
            case .notRegularFile(let url): return "The selected item is not a regular file: \(url.lastPathComponent)"
            }
        }
    }

    func hashFile(at url: URL, chunkSize: Int = 1_048_576) async throws -> ExactFingerprint {
        // Detached tasks do not inherit cancellation; forward it so cancelling a scan stops hashing.
        let work = Task.detached(priority: .utility) { () -> ExactFingerprint in
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true else { throw HasherError.notRegularFile(url) }

            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }

            var hasher = SHA256()
            var bytesRead: Int64 = 0
            while true {
                try Task.checkCancellation()
                guard let data = try handle.read(upToCount: chunkSize), !data.isEmpty else { break }
                hasher.update(data: data)
                bytesRead += Int64(data.count)
            }

            let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
            return ExactFingerprint(algorithm: "sha256-v1", digest: digest, byteCount: bytesRead)
        }
        return try await withTaskCancellationHandler {
            try await work.value
        } onCancel: {
            work.cancel()
        }
    }
}
