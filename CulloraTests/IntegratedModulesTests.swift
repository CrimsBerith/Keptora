import XCTest
@testable import Cullora

final class IntegratedModulesTests: XCTestCase {
    func testGPXParsingAndInterpolation() throws {
        let xml = #"<gpx><trk><trkseg><trkpt lat="41" lon="29"><time>2026-01-01T00:00:00Z</time></trkpt><trkpt lat="42" lon="30"><time>2026-01-01T00:10:00Z</time></trkpt></trkseg></trk></gpx>"#
        let document = try CulloraJourneyMatch.Parser().parse(Data(xml.utf8)); XCTAssertEqual(document.points.count, 2)
        let match = try XCTUnwrap(CulloraJourneyMatch.Matcher(points: document.points).match(date: ISO8601DateFormatter().date(from: "2026-01-01T00:05:00Z")!))
        XCTAssertEqual(match.point.latitude, 41.5, accuracy: 0.0001); XCTAssertTrue(match.interpolated)
    }
    func testMetadataPolicyReducesSensitiveRisk() {
        let asset = CulloraMetadataTools.Asset(name: "photo.jpg", byteCount: 100, fileExtension: "jpg", findings: [.location, .device]); let impact = CulloraMetadataTools.simulate(assets: [asset], policy: .init())[0]
        XCTAssertEqual(impact.before, .sensitive); XCTAssertEqual(impact.predicted, .clean); XCTAssertGreaterThanOrEqual(CulloraMetadataTools.estimatedExportBytes([asset]), 16 * 1_024 * 1_024)
    }
}
