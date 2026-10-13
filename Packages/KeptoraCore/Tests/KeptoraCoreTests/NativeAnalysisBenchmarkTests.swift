import XCTest
import CoreGraphics
import ImageIO
import Foundation
import Darwin
@testable import KeptoraCore

/// Opt-in actual JPEG decoding/hashing benchmark, separate from portable policy
/// tests and real-library precision calibration. Never reports a simulated speed.
final class NativeAnalysisBenchmarkTests: XCTestCase {
    func testLargeLocalCorpusColdAndWarm() async throws {
        guard let value = ProcessInfo.processInfo.environment["KEPTORA_BENCHMARK_ITEMS"],
              let count = Int(value), [2000, 3000].contains(count) else {
            throw XCTSkip("Set KEPTORA_BENCHMARK_ITEMS=2000 or 3000 to measure actual Apple decoding and hashing.")
        }
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        // Ten byte-identical copies per distinct JPEG; no fixture IDs bypass APIs.
        for group in 0..<(count / 10) {
            let data = try jpeg(seed: group)
            for copy in 0..<10 { try data.write(to: root.appendingPathComponent("g\(group)-\(copy).jpg")) }
        }
        await MediaFingerprintDiskCache.shared.clear()
        let cold = try await run(root: root), warm = try await run(root: root)
        XCTAssertEqual(cold.items, count); XCTAssertEqual(warm.items, count)
        XCTAssertEqual(cold.exactGroups, count / 10); XCTAssertEqual(warm.exactGroups, count / 10)
        XCTAssertEqual(cold.exact?.hashedOriginals, count)
        XCTAssertEqual(warm.exact?.hashedOriginals, 0)
        XCTAssertEqual(warm.exact?.cacheHits, count)
        XCTAssertEqual(warm.photos?.cacheHits, count)
        var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
        let report = BenchmarkReport(items: count, cold: cold, warm: warm, peakResidentBytes: Int64(usage.ru_maxrss),
                                     os: ProcessInfo.processInfo.operatingSystemVersionString)
        let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(report)
        if let path = ProcessInfo.processInfo.environment["KEPTORA_BENCHMARK_OUTPUT"] {
            try data.write(to: URL(fileURLWithPath: path), options: .atomic)
        }
        print(String(decoding: data, as: UTF8.self))
    }
    private func run(root: URL) async throws -> BenchmarkPass {
        let recorder = BenchmarkRecorder()
        let coordinator = LibraryAnalysisCoordinator { await recorder.record($0) }
        try await coordinator.run(adapter: UnifiedLibraryAdapter(adapters: [FolderSourceAdapter(rootURL: root, cleanupAvailable: false)]), allowNetwork: false)
        return await recorder.result()
    }
    private func jpeg(seed: Int) throws -> Data {
        let width = 320, height = 240
        let context = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: CGFloat(seed % 17) / 17, green: CGFloat(seed % 31) / 31, blue: 0.4, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        context.setFillColor(CGColor(gray: 0.95, alpha: 1))
        context.fillEllipse(in: CGRect(x: seed % 190, y: seed % 110, width: 100, height: 100))
        let image = try XCTUnwrap(context.makeImage()), data = NSMutableData()
        let destination = try XCTUnwrap(CGImageDestinationCreateWithData(data as CFMutableData, "public.jpeg" as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
private struct BenchmarkPass: Codable, Sendable {
    var elapsedSeconds: Double = 0
    var firstCatalogueSeconds: Double?
    var firstGroupSeconds: Double?
    var items = 0
    var exactGroups = 0
    var exact: AnalysisWorkMetrics?
    var photos: AnalysisWorkMetrics?
    var stageSeconds: [String: Double] = [:]
}
private struct BenchmarkReport: Codable {
    let items: Int
    let cold: BenchmarkPass
    let warm: BenchmarkPass
    let peakResidentBytes: Int64
    let os: String
    let note = "Generated local JPEG corpus. Real-photo precision, cloud downloads, scrolling, energy and heat require device acceptance."
}
private actor BenchmarkRecorder {
    private let started = Date()
    private var pass = BenchmarkPass()
    func record(_ event: LibraryAnalysisUpdate) {
        let elapsed = Date().timeIntervalSince(started)
        switch event {
        case .catalogue(let items, _, _):
            pass.items = items.count
            if !items.isEmpty, pass.firstCatalogueSeconds == nil { pass.firstCatalogueSeconds = elapsed }
        case .exact(let groups, _, _, _):
            pass.exactGroups = groups.count
            if !groups.isEmpty, pass.firstGroupSeconds == nil { pass.firstGroupSeconds = elapsed }
        case .photos(let groups, _, _): if !groups.isEmpty, pass.firstGroupSeconds == nil { pass.firstGroupSeconds = elapsed }
        case .exactGroups(let groups): if !groups.isEmpty, pass.firstGroupSeconds == nil { pass.firstGroupSeconds = elapsed }
        case .photoGroups(let groups): if !groups.isEmpty, pass.firstGroupSeconds == nil { pass.firstGroupSeconds = elapsed }
        case .progress(let stage, let progress): if progress.isTerminal { pass.stageSeconds[stage.rawValue] = elapsed }
        case .metrics(let stage, let metrics): if stage == .exact { pass.exact = metrics }; if stage == .photos { pass.photos = metrics }
        case .finished: pass.elapsedSeconds = elapsed
        default: break
        }
    }
    func result() -> BenchmarkPass { pass }
}
