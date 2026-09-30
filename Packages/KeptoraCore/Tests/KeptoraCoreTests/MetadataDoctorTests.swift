import XCTest
@testable import KeptoraCore

#if canImport(ImageIO) && canImport(CoreGraphics)
import ImageIO
import CoreGraphics
import UniformTypeIdentifiers

final class MetadataDoctorTests: XCTestCase {
    private func makeJPEG(at url: URL, withGPS: Bool) throws {
        let context = CGContext(
            data: nil, width: 8, height: 8, bitsPerComponent: 8, bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
        )!
        let image = context.makeImage()!
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)!
        var properties: [CFString: Any] = [:]
        if withGPS {
            properties[kCGImagePropertyGPSDictionary] = [
                kCGImagePropertyGPSLatitude: 41.0082,
                kCGImagePropertyGPSLatitudeRef: "N",
                kCGImagePropertyGPSLongitude: 28.9784,
                kCGImagePropertyGPSLongitudeRef: "E"
            ]
            properties[kCGImagePropertyTIFFDictionary] = [kCGImagePropertyTIFFArtist: "Someone"]
        }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
    }

    private func properties(of url: URL) -> [CFString: Any]? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
    }

    func testStripLocationDataRemovesGPSAndArtistInCopy() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let source = dir.appendingPathComponent("photo.jpg")
        let copy = dir.appendingPathComponent("photo (no location).jpg")
        try makeJPEG(at: source, withGPS: true)
        XCTAssertNotNil(properties(of: source)?[kCGImagePropertyGPSDictionary])

        try MetadataDoctorEngine.stripLocationData(from: source, destinationURL: copy)

        XCTAssertNil(properties(of: copy)?[kCGImagePropertyGPSDictionary])
        let tiff = properties(of: copy)?[kCGImagePropertyTIFFDictionary] as? [CFString: Any]
        XCTAssertNil(tiff?[kCGImagePropertyTIFFArtist])
        // The original is untouched.
        XCTAssertNotNil(properties(of: source)?[kCGImagePropertyGPSDictionary])
    }

    func testStripLocationDataInPlaceRemovesGPS() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appendingPathComponent("photo.jpg")
        try makeJPEG(at: file, withGPS: true)

        try MetadataDoctorEngine.stripLocationData(from: file, destinationURL: file)

        XCTAssertNil(properties(of: file)?[kCGImagePropertyGPSDictionary])
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: dir.path), ["photo.jpg"])
    }

    func testInferDateHandlesScreenshotAndWhatsAppNamesAndRejectsInvalidDates() {
        let cal = Calendar.current
        let screenshot = MetadataDoctorEngine.inferDateFromFilename("Screenshot 2024-08-15 at 14.23.10.png")
        XCTAssertEqual(screenshot.map { cal.component(.hour, from: $0) }, 14)
        let whatsApp = MetadataDoctorEngine.inferDateFromFilename("WhatsApp Image 2024-08-15 at 09.05.01.jpeg")
        XCTAssertEqual(whatsApp.map { cal.component(.minute, from: $0) }, 5)
        XCTAssertNil(MetadataDoctorEngine.inferDateFromFilename("IMG_2024-19-39.jpg"))
    }
}
#endif
