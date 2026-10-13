import CoreGraphics
import ImageIO
import UniformTypeIdentifiers
import XCTest
import Vision
@testable import Keptora

final class SimilarityEngineTests: XCTestCase {
    func testArchivedFeaturePrintRoundTripHasNearZeroDistance() async throws {
        let url = try makeImage(seed: 7)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        let engine = SimilarityEngine()
        let first = try await engine.feature(for: url)
        let second = try await engine.feature(for: url)
        let distance = try await engine.distance(featureArchive: first.featureArchive, to: second.featureArchive)
        XCTAssertLessThan(distance, 0.0001)
        XCTAssertEqual(first.visionRevision, VNGenerateImageFeaturePrintRequestRevision1)
        XCTAssertEqual(first.cropScale, "scaleFit")
    }

    private func makeImage(seed: Int) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("fixture.png")
        let width = 320
        let height = 240
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { throw CocoaError(.fileWriteUnknown) }

        context.setFillColor(CGColor(red: 0.12, green: 0.22, blue: 0.42, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(red: 0.8, green: 0.3, blue: 0.2, alpha: 1))
        context.fillEllipse(in: CGRect(x: 40 + seed, y: 50, width: 130, height: 130))
        guard let image = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        return url
    }
}
