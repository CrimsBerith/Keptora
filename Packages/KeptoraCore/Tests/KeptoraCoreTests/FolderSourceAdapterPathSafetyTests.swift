import Foundation
import XCTest
@testable import KeptoraCore

final class FolderSourceAdapterPathSafetyTests: XCTestCase {
    func testEnumerationSkipsSymlinksAndAccessRejectsLateEscape() async throws {
        let files = FileManager.default
        let temporaryRoot = files.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let root = temporaryRoot.appendingPathComponent("selected", isDirectory: true)
        let outside = temporaryRoot.appendingPathComponent("outside", isDirectory: true)
        try files.createDirectory(at: root, withIntermediateDirectories: true)
        try files.createDirectory(at: outside, withIntermediateDirectories: true)
        defer { try? files.removeItem(at: temporaryRoot) }

        let candidate = root.appendingPathComponent("candidate.jpg")
        let linked = root.appendingPathComponent("linked.jpg")
        let outsideFile = outside.appendingPathComponent("outside.jpg")
        try Data("in-root fixture".utf8).write(to: candidate)
        let outsideContents = Data("outside fixture with distinct content".utf8)
        try outsideContents.write(to: outsideFile)
        try files.createSymbolicLink(at: linked, withDestinationURL: outsideFile)

        let adapter = FolderSourceAdapter(rootURL: root, cleanupAvailable: false)
        let assets = try await adapter.enumerateAssets()
        XCTAssertEqual(assets.map(\.displayName), ["candidate.jpg"])

        try files.removeItem(at: candidate)
        try files.createSymbolicLink(at: candidate, withDestinationURL: outsideFile)
        XCTAssertNil(LibraryFileIdentity.relativePath(candidate, root: root))

        do {
            let fingerprint = try await adapter.exactFingerprint(for: try XCTUnwrap(assets.first), allowNetwork: false) { _ in }
            XCTAssertEqual(fingerprint.byteCount, Int64(outsideContents.count))
            XCTFail("Access must reject an asset path that resolves outside the selected root")
        } catch let error as UniversalScanError {
            if case .inaccessibleAsset = error { return }
            XCTFail("Expected an inaccessible-asset error, got \(error)")
        } catch {
            XCTFail("Expected a typed inaccessible-asset error, got \(error)")
        }
    }
}
