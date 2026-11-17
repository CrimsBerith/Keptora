import XCTest
@testable import KeptoraCore

final class SyntheticScanSourceAdapterTests: XCTestCase {
    func testEnumerationPublishesCumulativeBatchesAndSyntheticFingerprints() async throws {
        let adapter = SyntheticScanSourceAdapter(
            sourceID: "synthetic-unit-test",
            assetCount: 7,
            initialBatchSize: 3
        )
        let recorder = SyntheticBatchRecorder()

        let assets = try await adapter.enumerateAssets(batchSize: 2, control: nil) { batch in
            await recorder.record(batch.map(\.id))
        }

        let batches = await recorder.batches
        XCTAssertEqual(batches.map(\.count), [3, 5, 7])
        XCTAssertEqual(assets.map(\.id), batches.last)
        XCTAssertTrue(assets.allSatisfy { $0.mediaKind == .video })

        let fingerprint = try await adapter.exactFingerprint(for: assets[0], allowNetwork: true) { _ in }
        XCTAssertEqual(fingerprint.algorithm, "synthetic-fixture-v1")
        XCTAssertEqual(fingerprint.digest, assets[0].id)
        guard case .file(let fileURL) = assets[0].reference else {
            XCTFail("Synthetic assets use inert file references")
            return
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: fileURL.path))
    }

    func testUnifiedAdapterPublishesSyntheticSourceBatchesAndFinalCatalogue() async throws {
        let source = SyntheticScanSourceAdapter(
            sourceID: "synthetic-unified-test",
            assetCount: 7,
            initialBatchSize: 3
        )
        let adapter = UnifiedLibraryAdapter(adapters: [source])
        let recorder = SyntheticBatchRecorder()

        let assets = try await adapter.enumerateAssets(control: nil) { items, _, _ in
            await recorder.record(items.map(\.id))
        }

        let batches = await recorder.batches
        let coverage = await adapter.coverage
        XCTAssertEqual(batches.first?.count, 3)
        XCTAssertEqual(batches.last?.count, 7)
        XCTAssertEqual(assets.count, 7)
        XCTAssertEqual(coverage.first?.itemCount, 7)
    }

    func testEnumerationCancellationStopsLaterBatches() async throws {
        let adapter = SyntheticScanSourceAdapter(
            sourceID: "synthetic-cancel-test",
            assetCount: 5,
            initialBatchSize: 1,
            batchDelayNanoseconds: 100_000_000
        )
        let recorder = SyntheticBatchRecorder()
        let task = Task {
            try await adapter.enumerateAssets(batchSize: 1, control: nil) { batch in
                await recorder.record(batch.map(\.id))
            }
        }

        try await Task.sleep(nanoseconds: 10_000_000)
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Cancelled synthetic enumeration must not complete")
        } catch is CancellationError {
        }

        let batches = await recorder.batches
        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches[0].count, 1)
    }
}

private actor SyntheticBatchRecorder {
    private(set) var batches: [[String]] = []

    func record(_ ids: [String]) {
        batches.append(ids)
    }
}
