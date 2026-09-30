import CryptoKit
import XCTest
@testable import Keptora
import KeptoraCore

final class ManifestSignerTests: XCTestCase {
    func testSealAndVerifyWithValidLocalKey() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let keyURL = directory.appendingPathComponent("Keys/manifest-signing.key")
        let signer = ManifestSigner(keyURL: keyURL)

        let manifest = CleanupManifest(
            schemaVersion: 4,
            planID: "test-plan",
            sourceRoot: "/tmp/source",
            quarantineRoot: "/tmp/quarantine",
            createdAt: Date(),
            appVersion: "1.0",
            operations: [
                CleanupManifestOperation(
                    operationID: "op-1",
                    groupID: "grp-1",
                    assetID: "asset-1",
                    originalPath: "/tmp/source/photo.jpg",
                    quarantinePath: "/tmp/quarantine/photo.jpg",
                    byteCount: 1024,
                    digest: "abc123"
                )
            ]
        )

        let envelope = try await signer.seal(manifest)
        XCTAssertEqual(envelope.algorithm, "curve25519-signing-v1")
        let isValid = await signer.verify(envelope)
        XCTAssertTrue(isValid)

        let decoded = try await signer.decodedManifest(from: envelope)
        XCTAssertEqual(decoded.planID, manifest.planID)
        XCTAssertEqual(decoded.operations.count, 1)
        XCTAssertEqual(decoded.operations.first?.assetID, "asset-1")
    }

    func testVerifyRejectsTamperedPayload() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let keyURL = directory.appendingPathComponent("Keys/manifest-signing.key")
        let signer = ManifestSigner(keyURL: keyURL)

        let manifest = CleanupManifest(
            schemaVersion: 4,
            planID: "test-plan",
            sourceRoot: "/tmp/source",
            quarantineRoot: "/tmp/quarantine",
            createdAt: Date(),
            appVersion: "1.0",
            operations: []
        )
        let envelope = try await signer.seal(manifest)

        let tamperedPayload = envelope.payloadBase64 + "AA=="
        let tamperedEnvelope = SignedCleanupManifest(
            algorithm: envelope.algorithm,
            payloadBase64: tamperedPayload,
            signatureBase64: envelope.signatureBase64,
            publicKeyBase64: envelope.publicKeyBase64
        )

        let isValid = await signer.verify(tamperedEnvelope)
        XCTAssertFalse(isValid)
        do {
            _ = try await signer.decodedManifest(from: tamperedEnvelope)
            XCTFail("Decoded manifest must throw on tampered envelope")
        } catch ManifestSigner.SignerError.invalidPayload {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testVerifyRejectsForeignSigningKeyDueToPinning() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let keyURL1 = directory.appendingPathComponent("Keys/device1.key")
        let keyURL2 = directory.appendingPathComponent("Keys/device2.key")
        let signer1 = ManifestSigner(keyURL: keyURL1)
        let signer2 = ManifestSigner(keyURL: keyURL2)

        let manifest = CleanupManifest(
            schemaVersion: 4,
            planID: "pinned-plan",
            sourceRoot: "/tmp/source",
            quarantineRoot: "/tmp/quarantine",
            createdAt: Date(),
            appVersion: "1.0",
            operations: []
        )
        let envelope1 = try await signer1.seal(manifest)
        // Ensure signer2 key is generated on disk so pinning is activated
        _ = try await signer2.seal(manifest)

        // Signer 2 must reject envelope signed by Signer 1
        let isValid = await signer2.verify(envelope1)
        XCTAssertFalse(isValid)
    }

    func testPrivateKeyCreatedWithOwnerOnlyPermissions() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let keyURL = directory.appendingPathComponent("Keys/manifest-signing.key")
        let signer = ManifestSigner(keyURL: keyURL)

        let manifest = CleanupManifest(
            schemaVersion: 4,
            planID: "perm-plan",
            sourceRoot: "/tmp/source",
            quarantineRoot: "/tmp/quarantine",
            createdAt: Date(),
            appVersion: "1.0",
            operations: []
        )
        _ = try await signer.seal(manifest)

        XCTAssertTrue(FileManager.default.fileExists(atPath: keyURL.path))
        let attributes = try FileManager.default.attributesOfItem(atPath: keyURL.path)
        if let permissions = attributes[.posixPermissions] as? NSNumber {
            XCTAssertEqual(permissions.intValue, 0o600)
        }
    }

    func testCorruptedKeyThrowsSignerError() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let keyURL = directory.appendingPathComponent("Keys/manifest-signing.key")
        try FileManager.default.createDirectory(at: keyURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("corrupt-short-key".utf8).write(to: keyURL)

        let signer = ManifestSigner(keyURL: keyURL)
        let manifest = CleanupManifest(
            schemaVersion: 4,
            planID: "corrupt-key-plan",
            sourceRoot: "/tmp/source",
            quarantineRoot: "/tmp/quarantine",
            createdAt: Date(),
            appVersion: "1.0",
            operations: []
        )

        do {
            _ = try await signer.seal(manifest)
            XCTFail("Sealing with corrupted key must throw invalidStoredKey")
        } catch ManifestSigner.SignerError.invalidStoredKey {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
