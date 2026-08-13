import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif

enum CulloraJourneyMatch {
    struct Point: Identifiable, Codable, Hashable, Sendable {
        let id: UUID; let latitude: Double; let longitude: Double; let elevation: Double?; let timestamp: Date; let segment: Int
        init(id: UUID = UUID(), latitude: Double, longitude: Double, elevation: Double? = nil, timestamp: Date, segment: Int = 0) {
            self.id = id; self.latitude = latitude; self.longitude = longitude; self.elevation = elevation; self.timestamp = timestamp; self.segment = segment
        }
    }
    struct Document: Sendable { let points: [Point]; let segmentCount: Int; let warnings: [String] }
    struct Match: Sendable { let point: Point; let deltaSeconds: TimeInterval; let interpolated: Bool }
    struct Matcher: Sendable {
        let points: [Point]
        init(points: [Point]) { self.points = points.sorted { $0.timestamp < $1.timestamp } }
        func match(date: Date, clockOffset: TimeInterval = 0, maximumDelta: TimeInterval = 300, interpolate: Bool = true) -> Match? {
            let adjusted = date.addingTimeInterval(clockOffset); let insertion = points.partitioningIndex { $0.timestamp >= adjusted }
            if interpolate, insertion > 0, insertion < points.count {
                let before = points[insertion - 1], after = points[insertion]; let span = after.timestamp.timeIntervalSince(before.timestamp)
                if before.segment == after.segment, span > 0, span <= 900 {
                    let ratio = adjusted.timeIntervalSince(before.timestamp) / span
                    return .init(point: .init(latitude: before.latitude + (after.latitude - before.latitude) * ratio, longitude: before.longitude + (after.longitude - before.longitude) * ratio, timestamp: adjusted, segment: before.segment), deltaSeconds: 0, interpolated: true)
                }
            }
            let candidates = [insertion - 1, insertion].filter { points.indices.contains($0) }.map { points[$0] }
            guard let nearest = candidates.min(by: { abs($0.timestamp.timeIntervalSince(adjusted)) < abs($1.timestamp.timeIntervalSince(adjusted)) }) else { return nil }
            let delta = abs(nearest.timestamp.timeIntervalSince(adjusted)); return delta <= maximumDelta ? .init(point: nearest, deltaSeconds: delta, interpolated: false) : nil
        }
    }
    final class Parser: NSObject, XMLParserDelegate {
        private var points: [Point] = [], warnings: [String] = [], text = ""; private var latitude: Double?, longitude: Double?, elevation: Double?, timestamp: Date?; private var segment = -1, pointNumber = 0
        func parse(_ data: Data) throws -> Document {
            points = []; warnings = []; segment = -1; pointNumber = 0; let parser = XMLParser(data: data); parser.delegate = self
            guard parser.parse() else { throw parser.parserError ?? CocoaError(.fileReadCorruptFile) }; guard !points.isEmpty else { throw CocoaError(.fileReadCorruptFile) }
            return .init(points: points.sorted { $0.timestamp < $1.timestamp }, segmentCount: max(segment + 1, 1), warnings: warnings)
        }
        func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes: [String: String] = [:]) {
            text = ""; let name = normalized(elementName); if name == "trkseg" || name == "rte" { segment += 1 }
            if name == "trkpt" || name == "rtept" { if segment < 0 { segment = 0 }; pointNumber += 1; latitude = Double(attributes["lat"] ?? ""); longitude = Double(attributes["lon"] ?? ""); elevation = nil; timestamp = nil }
        }
        func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }
        func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
            let name = normalized(elementName), value = text.trimmingCharacters(in: .whitespacesAndNewlines); if name == "ele" { elevation = Double(value) }; if name == "time" { timestamp = ISO8601DateFormatter().date(from: value) }
            guard name == "trkpt" || name == "rtept" else { return }; guard let latitude, (-90...90).contains(latitude), let longitude, (-180...180).contains(longitude), let timestamp else { warnings.append("Point \(pointNumber) skipped: invalid coordinates or timestamp."); return }
            points.append(.init(latitude: latitude, longitude: longitude, elevation: elevation, timestamp: timestamp, segment: segment))
        }
        private func normalized(_ value: String) -> String { value.split(separator: ":").last.map(String.init)?.lowercased() ?? value.lowercased() }
    }
}
private extension Array {
    func partitioningIndex(where predicate: (Element) -> Bool) -> Int { var low = 0, high = count; while low < high { let mid = (low + high) / 2; if predicate(self[mid]) { high = mid } else { low = mid + 1 } }; return low }
}
