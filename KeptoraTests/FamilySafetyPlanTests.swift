import Foundation
import XCTest
@testable import Keptora

final class FamilySafetyPlanTests: XCTestCase {
    func testPartialRAWFamilyIsBlocked() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let source = root.appendingPathComponent("Source", isDirectory: true)
        let support = root.appendingPathComponent("Support", isDirectory: true)
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try Data("raw duplicate".utf8).write(to: source.appendingPathComponent("IMG_0001.CR3"))
        try Data("raw duplicate".utf8).write(to: source.appendingPathComponent("IMG_0001 copy.CR3"))
        try Data("rendered".utf8).write(to: source.appendingPathComponent("IMG_0001.JPG"))

        let database = SQLiteDatabase(url: support.appendingPathComponent("test.sqlite"))
        let outcome = try await ScanCoordinator(database: database).scan(folder: source) { _ in }
        let group = try XCTUnwrap(outcome.groups.first)
        let candidate = try XCTUnwrap(group.assets.first(where: { $0.id != group.canonicalAssetID }))
        try await database.setDecision(groupID: group.id, assetID: candidate.id, decision: .quarantinePlan)

        let coordinator = QuarantineCoordinator(database: database, applicationSupportDirectory: support)
        do {
            _ = try await coordinator.preparePlan(sourceRoot: source)
            XCTFail("Expected family safety blocker")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("partial rawBundle"))
        }
    }
}
