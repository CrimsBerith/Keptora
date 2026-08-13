#if os(Linux)
import Foundation

actor ManifestSigner {
    private let keyURL: URL
    init(keyURL: URL) { self.keyURL = keyURL }

    func seal(_ manifest: CleanupManifest) throws -> SignedCleanupManifest {
        let payload = try Self.canonicalEncoder.encode(manifest)
        return SignedCleanupManifest(
            algorithm: "linux-smoke-v1",
            payloadBase64: payload.base64EncodedString(),
            signatureBase64: Data("linux-smoke-signature".utf8).base64EncodedString(),
            publicKeyBase64: Data("linux-smoke-key".utf8).base64EncodedString()
        )
    }

    func verify(_ envelope: SignedCleanupManifest) -> Bool {
        envelope.algorithm == "linux-smoke-v1" && Data(base64Encoded: envelope.payloadBase64) != nil
    }

    func decodedManifest(from envelope: SignedCleanupManifest) throws -> CleanupManifest {
        guard verify(envelope), let payload = Data(base64Encoded: envelope.payloadBase64) else {
            throw NSError(domain: "ManifestSignerLinuxStub", code: 1)
        }
        return try Self.canonicalDecoder.decode(CleanupManifest.self, from: payload)
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
#endif
