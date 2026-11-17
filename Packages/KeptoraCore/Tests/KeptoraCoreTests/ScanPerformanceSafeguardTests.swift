import XCTest
@testable import KeptoraCore

/// Guards for the scan performance changes: exact grouping and progress reporting must
/// never hide a real duplicate or hang a scan.
final class ScanPerformanceSafeguardTests: XCTestCase {
    private func photo(_ id: String) -> UniversalMediaAsset {
        UniversalMediaAsset(id: id, sourceID: LibrarySource.photos.id, reference: .photoLibrary(localIdentifier: id),
                            displayName: id + ".heic", mediaKind: .image, pixelWidth: 4032, pixelHeight: 3024)
    }

    func testImageCandidatesUseFullFingerprintsAndOnlyMatchingDigestsGroup() async throws {
        let first = photo(UUID().uuidString)
        let second = photo(UUID().uuidString).with(hasAdjustments: true)
        let different = photo(UUID().uuidString)
        let assets = [first, second, different]
        let adapter = ExactFingerprintTestAdapter(assets: assets, digests: [
            first.id: "same-full-content",
            second.id: "same-full-content",
            different.id: "different-full-content"
        ])
        let scanner = UniversalExactScanner()
        let result = try await scanner.scan(
            adapter: adapter,
            allowNetwork: false,
            preloadedAssets: assets,
            progress: { _, _, _ in }
        )

        let callCounts = await adapter.fingerprintCallCounts()
        XCTAssertEqual(callCounts, Dictionary(uniqueKeysWithValues: assets.map { ($0.id, 1) }))
        XCTAssertEqual(result.groups.map(\.digest), ["same-full-content"])
        XCTAssertEqual(Set(result.groups[0].assets.map(\.id)), Set([first.id, second.id]))
    }

    func testProgressGateAlwaysAdmitsStartAndEnd() {
        let gate = AnalysisProgressGate(interval: 60)
        XCTAssertTrue(gate.admit(done: 0, total: 10))
        XCTAssertFalse(gate.admit(done: 5, total: 10))
        XCTAssertTrue(gate.admit(done: 10, total: 10))
    }

}

private actor ExactFingerprintTestAdapter: SourceAdapter {
    nonisolated let source = LibrarySource.photos
    nonisolated let capabilities = PlatformCapabilities(
        exactScan: true,
        similarityReview: false,
        cleanupMode: .photosRecentlyDeleted,
        canRestoreInApp: true,
        mayRequireNetworkDownload: false,
        canRevealInFileBrowser: false
    )
    private let assets: [UniversalMediaAsset]
    private let digests: [String: String]
    private var callCounts: [String: Int] = [:]

    init(assets: [UniversalMediaAsset], digests: [String: String]) {
        self.assets = assets
        self.digests = digests
    }

    func authorizationStatus() async -> SourceAuthorization { .authorized }
    func requestAuthorization() async -> SourceAuthorization { .authorized }
    func enumerateAssets() async throws -> [UniversalMediaAsset] { assets }

    func exactFingerprint(
        for asset: UniversalMediaAsset,
        allowNetwork: Bool,
        progress: @escaping @Sendable (Int64) -> Void
    ) async throws -> UniversalExactFingerprint {
        callCounts[asset.id, default: 0] += 1
        return UniversalExactFingerprint(digest: digests[asset.id] ?? "missing:\(asset.id)", byteCount: 4096)
    }

    func fingerprintCallCounts() -> [String: Int] { callCounts }
}
