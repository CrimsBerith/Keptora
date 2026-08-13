import XCTest
@testable import Cullora

final class SourceExclusionPolicyTests: XCTestCase {
    func testFolderMatchingIsUnicodeNormalizedAndCaseInsensitive() {
        let decomposed = "Re\u{301}sume\u{301}"
        let policy = SourceExclusionPolicy(folderNames: ["Résumé"], extensions: [])
        let root = URL(fileURLWithPath: "/Library")
        let file = root.appendingPathComponent(decomposed).appendingPathComponent("IMG_0001.JPG")
        XCTAssertTrue(policy.excludes(file, root: root))
    }

    func testExtensionMatchingTrimsDotAndIgnoresCase() {
        let policy = SourceExclusionPolicy(folderNames: [], extensions: [".JpG", " XMP "])
        let root = URL(fileURLWithPath: "/Library")
        XCTAssertTrue(policy.excludes(root.appendingPathComponent("Photo.JPG"), root: root))
        XCTAssertTrue(policy.excludes(root.appendingPathComponent("Photo.xmp"), root: root))
        XCTAssertFalse(policy.excludes(root.appendingPathComponent("Photo.png"), root: root))
    }

    func testBuiltInQuarantineNameCannotBeBypassedByCase() {
        let policy = SourceExclusionPolicy(folderNames: [".Cullora Quarantine"], extensions: [])
        let root = URL(fileURLWithPath: "/Library")
        let file = root.appendingPathComponent(".CULLORA QUARANTINE/plan/copy.jpg")
        XCTAssertTrue(policy.excludes(file, root: root))
    }
}
