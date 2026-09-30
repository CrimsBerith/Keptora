#if os(Linux)
import Foundation
struct ExactFingerprint: Hashable, Codable, Sendable {
    let algorithm: String
    let digest: String
    let byteCount: Int64
}
#endif
