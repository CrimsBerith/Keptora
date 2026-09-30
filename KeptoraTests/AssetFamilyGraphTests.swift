import Foundation
import XCTest
@testable import Keptora

final class AssetFamilyGraphTests: XCTestCase {
    func testBuildsRAWBundleWithSidecar() throws {
        let root = URL(fileURLWithPath: "/tmp/keptora-family-tests")
        let source = SourceID(rawValue: "source")
        let assets = [
            descriptor("IMG_0001.CR3", kind: .image, root: root, source: source),
            descriptor("IMG_0001.JPG", kind: .image, root: root, source: source),
            descriptor("IMG_0001.XMP", kind: .sidecar, root: root, source: source)
        ]

        let families = AssetFamilyGraphBuilder().build(from: assets)
        XCTAssertEqual(families.count, 1)
        XCTAssertEqual(families[0].kind, .rawBundle)
        XCTAssertEqual(families[0].policy, .allOrNothing)
        XCTAssertEqual(Set(families[0].members.map(\.role)), Set([.raw, .rendered, .sidecar]))
    }

    func testBuildsLivePhotoPair() throws {
        let root = URL(fileURLWithPath: "/tmp/keptora-family-tests")
        let source = SourceID(rawValue: "source")
        let assets = [
            descriptor("IMG_0042.HEIC", kind: .image, root: root, source: source),
            descriptor("IMG_0042.MOV", kind: .video, root: root, source: source)
        ]

        let family = try XCTUnwrap(AssetFamilyGraphBuilder().build(from: assets).first)
        XCTAssertEqual(family.kind, .livePhoto)
        XCTAssertEqual(Set(family.members.map(\.role)), Set([.primary, .motion]))
    }

    func testEditedDerivativeIsAdvisory() throws {
        let root = URL(fileURLWithPath: "/tmp/keptora-family-tests")
        let source = SourceID(rawValue: "source")
        let assets = [
            descriptor("portrait.jpg", kind: .image, root: root, source: source),
            descriptor("portrait-edited.jpg", kind: .image, root: root, source: source)
        ]

        let family = try XCTUnwrap(AssetFamilyGraphBuilder().build(from: assets).first)
        XCTAssertEqual(family.kind, .editedExport)
        XCTAssertEqual(family.policy, .advisory)
    }


    func testBuildsExplicitBurstFamilyAsAdvisory() throws {
        let root = URL(fileURLWithPath: "/tmp/keptora-family-tests")
        let source = SourceID(rawValue: "source")
        let assets = [
            descriptor("IMG_0100_BURST001.jpg", kind: .image, root: root, source: source),
            descriptor("IMG_0100_BURST002.jpg", kind: .image, root: root, source: source),
            descriptor("IMG_0100_BURST003.jpg", kind: .image, root: root, source: source)
        ]

        let family = try XCTUnwrap(AssetFamilyGraphBuilder().build(from: assets).first)
        XCTAssertEqual(family.kind, .burst)
        XCTAssertEqual(family.policy, .advisory)
        XCTAssertTrue(family.members.allSatisfy { $0.role == .burstMember })
    }

    private func descriptor(_ name: String, kind: MediaKind, root: URL, source: SourceID) -> AssetDescriptor {
        let url = root.appendingPathComponent(name)
        return AssetDescriptor(
            id: AssetID(rawValue: name.lowercased()),
            sourceID: source,
            stableKey: url.path,
            displayName: name,
            fileURL: url,
            mediaKind: kind,
            byteCount: 10,
            pixelWidth: nil,
            pixelHeight: nil,
            creationDate: nil,
            modificationDate: nil
        )
    }
}
