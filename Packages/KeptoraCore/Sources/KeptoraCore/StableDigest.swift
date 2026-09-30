import Foundation

public enum StableDigest {
    /// 64-bit FNV-1a hash algorithm returning a hexadecimal string.
    public static func fnv1a64(_ value: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }
}
