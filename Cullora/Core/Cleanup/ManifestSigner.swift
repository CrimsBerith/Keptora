import CryptoKit
import Foundation

actor ManifestSigner {
    enum SignerError: LocalizedError {
        case invalidStoredKey
        case invalidPayload

        var errorDescription: String? {
            switch self {
            case .invalidStoredKey: return "Cullora could not load its local manifest signing key."
            case .invalidPayload: return "The cleanup manifest could not be encoded for signing."
            }
        }
    }

    private let keyURL: URL
    private var cachedKey: Curve25519.Signing.PrivateKey?

    init(keyURL: URL) {
        self.keyURL = keyURL
    }

    func seal(_ manifest: CleanupManifest) throws -> SignedCleanupManifest {
        let encoder = Self.canonicalEncoder
        let payload = try encoder.encode(manifest)
        let key = try signingKey()
        let signature = try key.signature(for: payload)
        return SignedCleanupManifest(
            algorithm: "curve25519-signing-v1",
            payloadBase64: payload.base64EncodedString(),
            signatureBase64: signature.base64EncodedString(),
            publicKeyBase64: key.publicKey.rawRepresentation.base64EncodedString()
        )
    }

    func verify(_ envelope: SignedCleanupManifest) -> Bool {
        guard envelope.algorithm == "curve25519-signing-v1",
              let payload = Data(base64Encoded: envelope.payloadBase64),
              let signature = Data(base64Encoded: envelope.signatureBase64),
              let publicKeyData = Data(base64Encoded: envelope.publicKeyBase64),
              let publicKey = try? Curve25519.Signing.PublicKey(rawRepresentation: publicKeyData) else {
            return false
        }
        return publicKey.isValidSignature(signature, for: payload)
    }

    func decodedManifest(from envelope: SignedCleanupManifest) throws -> CleanupManifest {
        guard verify(envelope), let payload = Data(base64Encoded: envelope.payloadBase64) else {
            throw SignerError.invalidPayload
        }
        return try Self.canonicalDecoder.decode(CleanupManifest.self, from: payload)
    }

    private func signingKey() throws -> Curve25519.Signing.PrivateKey {
        if let cachedKey { return cachedKey }
        if FileManager.default.fileExists(atPath: keyURL.path) {
            let data = try Data(contentsOf: keyURL)
            guard let key = try? Curve25519.Signing.PrivateKey(rawRepresentation: data) else {
                throw SignerError.invalidStoredKey
            }
            cachedKey = key
            return key
        }

        let key = Curve25519.Signing.PrivateKey()
        try FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try key.rawRepresentation.write(to: keyURL, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: keyURL.path)
        cachedKey = key
        return key
    }

    static var canonicalEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .millisecondsSince1970
        return encoder
    }

    static var canonicalDecoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .millisecondsSince1970
        return decoder
    }
}
