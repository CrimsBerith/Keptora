import AppKit
import Foundation
import UniformTypeIdentifiers

struct PerformanceSample: Codable, Hashable, Sendable, Identifiable {
    let id: UUID
    let label: String
    let itemCount: Int
    let elapsedSeconds: Double
    let itemsPerSecond: Double
    let recordedAt: Date
    let result: String

    init(label: String, itemCount: Int, elapsedSeconds: Double, result: String = "completed", recordedAt: Date = Date()) {
        self.id = UUID()
        self.label = label
        self.itemCount = max(0, itemCount)
        self.elapsedSeconds = max(0, elapsedSeconds)
        self.itemsPerSecond = elapsedSeconds > 0 ? Double(max(0, itemCount)) / elapsedSeconds : 0
        self.recordedAt = recordedAt
        self.result = result
    }
}

@MainActor
enum PerformanceRecorder {
    private static let fileName = "PerformanceHistory.json"
    private static let maximumSamples = 200

    static func append(_ sample: PerformanceSample, in applicationSupportDirectory: URL) throws -> [PerformanceSample] {
        var samples = read(in: applicationSupportDirectory)
        samples.append(sample)
        if samples.count > maximumSamples {
            samples.removeFirst(samples.count - maximumSamples)
        }
        try write(samples, to: historyURL(in: applicationSupportDirectory))
        return samples
    }

    static func read(in applicationSupportDirectory: URL) -> [PerformanceSample] {
        let url = historyURL(in: applicationSupportDirectory)
        guard let data = try? Data(contentsOf: url) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([PerformanceSample].self, from: data)) ?? []
    }

    @MainActor
    static func export(_ samples: [PerformanceSample]) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Local Performance History"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "Cullora-Performance-History.json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try write(samples, to: url)
        return url
    }

    private static func historyURL(in directory: URL) -> URL {
        directory.appendingPathComponent(fileName)
    }

    private static func write(_ samples: [PerformanceSample], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode(samples).write(to: url, options: .atomic)
    }
}
