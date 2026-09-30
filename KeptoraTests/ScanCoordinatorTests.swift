import XCTest
@testable import Keptora

final class ScanCoordinatorTests: XCTestCase {
    func testScanCoordinatorSkipsUnreadableFileAndContinues() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let support = directory.appendingPathComponent("Support", isDirectory: true)
        let folder = directory.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defer {
            let unreadable = folder.appendingPathComponent("unreadable.jpg")
            try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: unreadable.path)
            try? FileManager.default.removeItem(at: directory)
        }

        let database = SQLiteDatabase(url: support.appendingPathComponent("scan.sqlite"))
        try await database.initialize()

        let fileA = folder.appendingPathComponent("validA.jpg")
        let fileB = folder.appendingPathComponent("unreadable.jpg")
        let fileC = folder.appendingPathComponent("validC.jpg")
        try Data("valid-content-A".utf8).write(to: fileA)
        try Data("valid-content-B".utf8).write(to: fileB)
        try Data("valid-content-C".utf8).write(to: fileC)

        // Make fileB unreadable
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: fileB.path)

        var progressMessages: [String] = []
        let coordinator = ScanCoordinator(database: database)
        let outcome = try await coordinator.scan(folder: folder) { progress in
            if let msg = progress.message {
                progressMessages.append(msg)
            }
        }

        XCTAssertEqual(outcome.discovered, 3)
        XCTAssertEqual(outcome.hashed, 2)
        XCTAssertEqual(outcome.reused, 0)
        XCTAssertTrue(progressMessages.contains(where: { $0.contains("1 skipped") }))
    }

    func testScanCoordinatorCancellationStopsProcessing() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let support = directory.appendingPathComponent("Support", isDirectory: true)
        let folder = directory.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: support.appendingPathComponent("scan.sqlite"))
        try await database.initialize()

        for i in 0..<20 {
            let file = folder.appendingPathComponent("photo_\(i).jpg")
            try Data(repeating: UInt8(i), count: 1024 * 128).write(to: file)
        }

        let coordinator = ScanCoordinator(database: database)
        let task = Task {
            try await coordinator.scan(folder: folder) { _ in }
        }
        task.cancel()

        do {
            _ = try await task.value
        } catch is CancellationError {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testScanCoordinatorReusesUnchangedAssetsOnSubsequentScan() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let support = directory.appendingPathComponent("Support", isDirectory: true)
        let folder = directory.appendingPathComponent("Photos", isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let database = SQLiteDatabase(url: support.appendingPathComponent("scan.sqlite"))
        try await database.initialize()

        for i in 0..<3 {
            let file = folder.appendingPathComponent("reuse_\(i).jpg")
            try Data("identical-data-\(i)".utf8).write(to: file)
        }

        let coordinator = ScanCoordinator(database: database)
        let outcome1 = try await coordinator.scan(folder: folder) { _ in }
        XCTAssertEqual(outcome1.hashed, 3)
        XCTAssertEqual(outcome1.reused, 0)

        let outcome2 = try await coordinator.scan(folder: folder) { _ in }
        XCTAssertEqual(outcome2.hashed, 0)
        XCTAssertEqual(outcome2.reused, 3)
    }
}
