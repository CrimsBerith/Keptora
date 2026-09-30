import AppKit
import XCTest
@testable import Keptora

final class ExactHasherTests: XCTestCase {
    func testByteIdenticalFilesProduceSameDigest() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let data = Data("keptora-exact-test".utf8)
        let first = directory.appendingPathComponent("first.jpg")
        let second = directory.appendingPathComponent("second.jpg")
        try data.write(to: first)
        try data.write(to: second)
        let hasher = ExactHasher()
        let lhs = try await hasher.hashFile(at: first)
        let rhs = try await hasher.hashFile(at: second)
        XCTAssertEqual(lhs.digest, rhs.digest)
        XCTAssertEqual(lhs.byteCount, Int64(data.count))
    }

    func testChangedByteProducesDifferentDigest() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let first = directory.appendingPathComponent("first.jpg")
        let second = directory.appendingPathComponent("second.jpg")
        try Data([0,1,2,3]).write(to: first)
        try Data([0,1,2,4]).write(to: second)
        let hasher = ExactHasher()
        let lhs = try await hasher.hashFile(at: first)
        let rhs = try await hasher.hashFile(at: second)
        XCTAssertNotEqual(lhs.digest, rhs.digest)
    }

    @MainActor
    func testDemoLibraryCreatesReadableImageFixtures() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let library = try DemoLibraryFactory.prepare(in: directory)
        let first = library.appendingPathComponent("Family_Original.jpg")
        let copy = library.appendingPathComponent("Family_Copy_1.jpg")
        let firstData = try Data(contentsOf: first)
        let copyData = try Data(contentsOf: copy)

        XCTAssertFalse(firstData.isEmpty)
        XCTAssertNotNil(NSBitmapImageRep(data: firstData))
        XCTAssertEqual(firstData, copyData)
        XCTAssertEqual(try DemoLibraryFactory.prepare(in: directory), library)
    }
}
