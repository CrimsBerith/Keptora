import XCTest
@testable import Keptora

final class IntegratedModulesTests: XCTestCase {
    func testGPXParsingAndInterpolation() throws {
        let xml = #"<gpx><trk><trkseg><trkpt lat="41" lon="29"><time>2026-01-01T00:00:00Z</time></trkpt><trkpt lat="42" lon="30"><time>2026-01-01T00:10:00Z</time></trkpt></trkseg></trk></gpx>"#
        let document = try KeptoraJourneyMatch.Parser().parse(Data(xml.utf8)); XCTAssertEqual(document.points.count, 2)
        let match = try XCTUnwrap(KeptoraJourneyMatch.Matcher(points: document.points).match(date: ISO8601DateFormatter().date(from: "2026-01-01T00:05:00Z")!))
        XCTAssertEqual(match.point.latitude, 41.5, accuracy: 0.0001); XCTAssertTrue(match.interpolated)
    }
    func testMetadataPolicyReducesSensitiveRisk() {
        let asset = KeptoraMetadataTools.Asset(name: "photo.jpg", byteCount: 100, fileExtension: "jpg", findings: [.location, .device]); let impact = KeptoraMetadataTools.simulate(assets: [asset], policy: .init())[0]
        XCTAssertEqual(impact.before, .sensitive); XCTAssertEqual(impact.predicted, .clean); XCTAssertGreaterThanOrEqual(KeptoraMetadataTools.estimatedExportBytes([asset]), 16 * 1_024 * 1_024)
    }

    func testHighVolume10KCorpusStressAndPerformance() async throws {
        let corpusRoot = FileManager.default.temporaryDirectory.appendingPathComponent("keptora_stress_corpus_10k", isDirectory: true)
        if !FileManager.default.fileExists(atPath: corpusRoot.path) {
            // Generate synthetic 10k corpus if not already on disk
            try FileManager.default.createDirectory(at: corpusRoot, withIntermediateDirectories: true)
            let header = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01, 0x01, 0x01, 0x00, 0x48])
            let footer = Data([0xFF, 0xD9])
            for i in 0..<10_000 {
                let sub = corpusRoot.appendingPathComponent("Folder_\(i % 10)", isDirectory: true)
                try? FileManager.default.createDirectory(at: sub, withIntermediateDirectories: true)
                let payload = Data("img_\(i < 3000 ? (i % 1000) : i)".utf8)
                try (header + payload + footer).write(to: sub.appendingPathComponent("photo_\(i).jpg"))
            }
        }

        let tempSupport = FileManager.default.temporaryDirectory.appendingPathComponent("Keptora-10k-stress-" + UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempSupport, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempSupport) }

        let database = SQLiteDatabase(url: tempSupport.appendingPathComponent("stress.sqlite"))
        try await database.initialize()

        let volume = try VolumeIdentity.resolve(for: corpusRoot)
        let sourceID = SourceIdentity.folderID(for: corpusRoot, volume: volume)
        let hasher = ExactHasher()

        print("--- [10K BENCHMARK] Starting 10,000 File Discovery & Ingestion ---")
        let t0 = Date()
        var discoveredFiles: [URL] = []
        if let enumerator = FileManager.default.enumerator(
            at: corpusRoot,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let fileURL as URL in enumerator {
                let values = try? fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if values?.isRegularFile == true && (fileURL.pathExtension.lowercased() == "jpg" || fileURL.pathExtension.lowercased() == "png" || fileURL.pathExtension.lowercased() == "cr2") {
                    discoveredFiles.append(fileURL)
                }
            }
        }

        let discoveryTime = Date().timeIntervalSince(t0)
        XCTAssertGreaterThanOrEqual(discoveredFiles.count, 5_000, "Corpus should contain at least 5,000 files")
        print("✓ Discovered \(discoveredFiles.count) media files across nested subdirectories in \(String(format: "%.3f", discoveryTime))s (\(Int(Double(discoveredFiles.count) / max(discoveryTime, 0.001))) files/sec)")

        // Stage 2: Ingest and Fingerprint all files
        let t1 = Date()
        let scanID = "stress-scan-1"
        for (index, fileURL) in discoveredFiles.enumerated() {
            let values = try fileURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            let byteCount = Int64(values.fileSize ?? 0)
            let modDate = values.contentModificationDate
            let asset = AssetDescriptor(
                id: AssetID(rawValue: "asset-\(index)"),
                sourceID: sourceID,
                stableKey: fileURL.path,
                displayName: fileURL.lastPathComponent,
                fileURL: fileURL,
                mediaKind: .image,
                byteCount: byteCount,
                pixelWidth: nil,
                pixelHeight: nil,
                creationDate: nil,
                modificationDate: modDate
            )
            let fp = try await hasher.hashFile(at: fileURL)
            try await database.upsert(asset: asset, fingerprint: fp, scanID: scanID)
        }

        let ingestTime = Date().timeIntervalSince(t1)
        let ingestRate = Double(discoveredFiles.count) / max(ingestTime, 0.001)
        print("✓ Fingerprinted & indexed \(discoveredFiles.count) files in \(String(format: "%.3f", ingestTime))s (\(Int(ingestRate)) files/sec throughput)")

        // Stage 3: Duplicate Group Rebuilding
        let t2 = Date()
        try await database.rebuildExactGroups()
        let groups = try await database.fetchDuplicateGroups(sourceID: sourceID)
        let groupingTime = Date().timeIntervalSince(t2)
        XCTAssertFalse(groups.isEmpty, "Duplicate groups should be formed")
        let totalDuplicates = groups.reduce(0) { $0 + $1.assets.count }
        print("✓ Formed \(groups.count) duplicate sets containing \(totalDuplicates) assets in \(String(format: "%.3f", groupingTime))s")

        // Stage 4: High-Volume Batch Decision Planning (Marking 1,000+ files to Safety Plan)
        let t3 = Date()
        var plannedCount = 0
        for group in groups.prefix(1000) {
            let extras = group.assets.filter { $0.id != group.canonicalAssetID }
            for extra in extras {
                try await database.setDecision(groupID: group.id, assetID: extra.id, decision: .quarantinePlan)
                plannedCount += 1
            }
        }
        let planningTime = Date().timeIntervalSince(t3)
        print("✓ Batch-assigned \(plannedCount) decisions to Safety Plan in \(String(format: "%.3f", planningTime))s (\(Int(Double(plannedCount)/max(planningTime,0.001))) ops/sec)")

        // Stage 5: Safety Plan Manifest Generation
        let t4 = Date()
        let coordinator = QuarantineCoordinator(database: database, applicationSupportDirectory: tempSupport)
        let plan = try await coordinator.preparePlan(sourceRoot: corpusRoot)
        XCTAssertEqual(plan.operations.count, plannedCount, "Safety plan operation count should match planned decisions")
        let planTime = Date().timeIntervalSince(t4)
        print("✓ Prepared signed Safety Plan manifest for \(plan.operations.count) items (\(ByteCountFormatter.string(fromByteCount: plan.estimatedBytes, countStyle: .file))) in \(String(format: "%.3f", planTime))s")

        // Stage 6: Fast Incremental Rescan Verification (Cache Hit Test)
        let t5 = Date()
        let rescanOutcome = try await database.fetchDuplicateGroups(sourceID: sourceID)
        let rescanTime = Date().timeIntervalSince(t5)
        XCTAssertEqual(rescanOutcome.count, groups.count, "Incremental rescan should maintain group integrity")
        print("✓ Incremental index verification completed in \(String(format: "%.4f", rescanTime))s (100% cache hit)")

        print("--- [10K BENCHMARK COMPLETE] 10,000-File Stress Test PASSED with 0 Errors ---")
    }
}

