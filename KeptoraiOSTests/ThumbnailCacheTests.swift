import KeptoraCore
import UIKit
import XCTest
@testable import KeptoraiOS

@MainActor
final class ThumbnailCacheTests: XCTestCase {
    func testEditingFileWithPreservedModificationDateDoesNotReuseItsOldPreview() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("photo.jpg")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        try Data("original photo".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        let adapter = FolderSourceAdapter(rootURL: root, cleanupAvailable: false)
        let before = try await adapter.enumerateAssets()
        let original = try XCTUnwrap(before.first)
        let key = MobileAssetThumbnail(asset: original).cacheKey
        let image = UIGraphicsImageRenderer(size: CGSize(width: 1, height: 1)).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 1, height: 1))
        }
        MobileThumbnailCache.shared.setImage(image, forKey: key)
        XCTAssertNotNil(MobileThumbnailCache.shared.image(forKey: key))

        try await Task.sleep(nanoseconds: 2_000_000)
        try Data("modified photo".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        let after = try await adapter.enumerateAssets()
        let edited = try XCTUnwrap(after.first)
        XCTAssertEqual(original.id, edited.id)
        XCTAssertEqual(original.modificationDate, edited.modificationDate)
        XCTAssertNotEqual(original.fileRevision, edited.fileRevision)
        XCTAssertNil(MobileThumbnailCache.shared.image(forKey: MobileAssetThumbnail(asset: edited).cacheKey))
    }

    func testCellReloadsThumbnailWhenAssetRevisionChangesWithSameID() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("cell_test.jpg")
        let date = Date(timeIntervalSince1970: 1_700_000_000)
        try Data("original content".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        let adapter = FolderSourceAdapter(rootURL: root, cleanupAvailable: false)
        let before = try await adapter.enumerateAssets()
        let original = try XCTUnwrap(before.first)

        try await Task.sleep(nanoseconds: 2_000_000)
        try Data("modified content".utf8).write(to: url)
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: url.path)
        let after = try await adapter.enumerateAssets()
        let edited = try XCTUnwrap(after.first)

        XCTAssertEqual(original.id, edited.id)
        XCTAssertNotEqual(original.fileRevision, edited.fileRevision)

        let originalKey = MobileGalleryThumbnailLoader.cacheKey(for: original)
        let editedKey = MobileGalleryThumbnailLoader.cacheKey(for: edited)
        XCTAssertNotEqual(originalKey, editedKey)

        let image1 = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        let image2 = UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { context in
            UIColor.green.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 2, height: 2))
        }
        MobileThumbnailCache.shared.setImage(image1, forKey: originalKey)
        MobileThumbnailCache.shared.setImage(image2, forKey: editedKey)

        let cell = MobileGalleryAssetCell(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let loader = MobileGalleryThumbnailLoader()
        let state = MobileGalleryCellState()

        cell.apply(asset: original, state: state, loader: loader)
        XCTAssertEqual(cell.testDisplayedImage, image1)

        cell.apply(asset: edited, state: state, loader: loader)
        XCTAssertEqual(cell.testDisplayedImage, image2)
    }
}
