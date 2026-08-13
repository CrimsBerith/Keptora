import AppKit
import Foundation
import UniformTypeIdentifiers

struct DiagnosticsSnapshot: Codable, Sendable {
    let generatedAt: Date
    let appVersion: String
    let buildNumber: String
    let implementationPhase: String
    let operatingSystem: String
    let architecture: String
    let scanState: String
    let similarityState: String
    let sourceState: String
    let sourceReference: String
    let indexedAssets: Int
    let activeAssets: Int
    let duplicateGroups: Int
    let quarantinedAssets: Int
    let recoveryIssueCount: Int
    let lastScanSummary: String
    let lastSimilaritySummary: String
    let recentPerformance: [PerformanceSample]
    let error: String?
}

enum DiagnosticsRedactor {
    static func redact(_ value: String, sensitivePaths: [String]) -> String {
        var output = value
        let candidates = sensitivePaths
            .filter { !$0.isEmpty }
            .sorted { $0.count > $1.count }
        for path in candidates { output = output.replacingOccurrences(of: path, with: "<redacted-path>") }
        output = output.replacingOccurrences(
            of: #"/Users/[^/\s]+"#,
            with: "/Users/<redacted>",
            options: .regularExpression
        )
        return output
    }
}

@MainActor
enum DiagnosticsExporter {
    static func copy(_ snapshot: DiagnosticsSnapshot) throws {
        let data = try encoded(snapshot)
        guard let text = String(data: data, encoding: .utf8) else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    static func export(_ snapshot: DiagnosticsSnapshot) throws -> URL? {
        let panel = NSSavePanel()
        panel.title = "Export Cullora Diagnostics"
        panel.prompt = "Export"
        panel.nameFieldStringValue = "Cullora-Diagnostics-\(dateStamp()).json"
        panel.allowedContentTypes = [.json]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return nil }
        try encoded(snapshot).write(to: url, options: .atomic)
        return url
    }

    private static func encoded(_ snapshot: DiagnosticsSnapshot) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(snapshot)
    }

    private static func dateStamp() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: Date())
    }
}
