import KeptoraCore
import Foundation
import Photos
import PhotosUI
import UIKit

enum MobileTab: Int, CaseIterable, Identifiable {
    case library = 0
    case review = 1
    case history = 2

    var id: Int { rawValue }
}

enum MobileModalRoute: String, Identifiable {
    case filePicker
    case settings
    case paywall

    var id: String { rawValue }
}

@MainActor
final class MobileKeptoraStore: ObservableObject {
    enum PhotosAuthorizationAction: Equatable {
        case requestSystemPermission
        case connect
        case showSettingsHelp
        case showRestrictedHelp
        case showUnavailableHelp
    }

    enum SourceSelection: Equatable {
        case none
        case photos
        case folder(URL)

        var title: String {
            switch self {
            case .none: return String(localized: "Choose a source")
            case .photos: return String(localized: "Photos")
            case .folder(let url): return url.lastPathComponent
            }
        }
    }

    enum ScanState: Equatable {
        case idle
        case scanning(processed: Int, total: Int, current: String)
        case paused
        case completed
        case failed(String)

        var isScanning: Bool {
            if case .scanning = self { return true }
            return false
        }
    }

    struct CleanupHistoryEntry: Identifiable, Codable, Hashable {
        enum Kind: String, Codable { case photosRecentlyDeleted, folderQuarantine }
        let id: UUID
        let kind: Kind
        let createdAt: Date
        let itemCount: Int
        let byteCount: Int64
        var folderRecord: FolderQuarantineRecord?
        var restoredAt: Date?
    }

    @Published private(set) var source: SourceSelection = .none
    @Published private(set) var authorization: SourceAuthorization = .notDetermined
    @Published var scanState: ScanState = .idle
    @Published private(set) var assets: [UniversalMediaAsset] = []
    @Published private(set) var exactGroups: [UniversalExactGroup] = []
    @Published private(set) var similarityGroups: [UniversalSimilarityGroup] = []
    @Published private(set) var similarVideoGroups: [UniversalSimilarityGroup] = []
    @Published var similarityProgress: (processed: Int, total: Int)?
    @Published var videoSimilarityProgress: (processed: Int, total: Int)?
    @Published private(set) var skippedCloudItems = 0
    @Published private(set) var history: [CleanupHistoryEntry] = []
    @Published private(set) var hasScanCheckpoint = false
    @Published private(set) var reviewedAssetIDs: Set<String> = []
    @Published private(set) var isCleaningUp = false
    @Published var selectedAssetIDs: Set<String> = []
    @Published var selectedSimilarVideoAssetIDs: Set<String> = []
    @Published var currentGroupIndex = 0
    @Published var currentSimilarityGroupIndex = 0
    @Published var selectedTab: MobileTab = .library
    @Published var modalRoute: MobileModalRoute?
    @Published var isShowingPhotosPermissionHelp = false
    @Published var errorMessage: String?

    func present(_ route: MobileModalRoute) {
        modalRoute = route
    }

    func dismissModal() {
        modalRoute = nil
    }

    private let photosAdapter = PhotoLibrarySourceAdapter()
    private let scanner = UniversalExactScanner()
    private let folderCleanup = FolderQuarantineExecutor()
    private let similarityAnalyzer = VisualSimilarityAnalyzer()
    private let videoSimilarityAnalyzer = VideoSimilarityAnalyzer()
    private var activeFolderAdapter: FolderSourceAdapter?
    private var activeFolderScopeURL: URL?
    private var scanTask: Task<Void, Never>?
    private var lastScanAllowedNetwork = false
    private(set) var suspendedForBackground = false
    private var shouldConnectPhotosWhenAuthorized = false
    private var scanFingerprintsByAssetID: [String: UniversalExactFingerprint] = [:]
    private let isPhotosDeniedUITesting: Bool

    private let bookmarkKey = AppStorageKeys.iOSSourceBookmark
    private let historyKey = AppStorageKeys.iOSCleanupHistory
    private let scanCheckpointKey = AppStorageKeys.iOSScanCheckpoint
    nonisolated private var scanCheckpointFileURL: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("scan_checkpoint.json")
    }
    private let reviewedAssetsKey = AppStorageKeys.iOSReviewedAssets
    private let freeReviewLimit = AppStoreConfiguration.freeReviewLimit
    private var lastProgressUpdateTime = Date.distantPast

    init() {
        isPhotosDeniedUITesting = LaunchArguments.contains(LaunchArguments.photosDeniedUITesting)
        if let data = UserDefaults.standard.data(forKey: historyKey),
           let decoded = try? JSONDecoder().decode([CleanupHistoryEntry].self, from: data) {
            history = decoded
        }
        let checkpointFileExists = scanCheckpointFileURL.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
        hasScanCheckpoint = checkpointFileExists || UserDefaults.standard.data(forKey: scanCheckpointKey) != nil
        reviewedAssetIDs = Set(UserDefaults.standard.stringArray(forKey: reviewedAssetsKey) ?? [])
        if LaunchArguments.contains(LaunchArguments.thousandsStressUITesting) {
            seedThousandsStressUITesting()
        } else if LaunchArguments.contains(LaunchArguments.comprehensiveUITesting) {
            seedComprehensiveReviewForUITesting()
        } else if LaunchArguments.contains(LaunchArguments.videoReviewUITesting) {
            seedVideoReviewForUITesting()
        } else if isPhotosDeniedUITesting {
            authorization = .denied
        }
    }

    deinit {
        scanTask?.cancel()
        activeFolderScopeURL?.stopAccessingSecurityScopedResource()
    }

    var dashboard: DashboardSnapshot {
        DashboardSnapshot(scannedItems: assets.count, groups: exactGroups)
    }

    var selectedSafeAssets: [UniversalMediaAsset] {
        var unique: [String: UniversalMediaAsset] = [:]
        for asset in exactGroups.flatMap(\.safeCopies) where selectedAssetIDs.contains(asset.id) {
            unique[asset.id] = asset
        }
        return Array(unique.values)
    }

    var selectedBytes: Int64 {
        selectedSafeAssets.reduce(0) { $0 + ($1.byteCount ?? 0) }
    }

    var selectedSimilarVideoAssets: [UniversalMediaAsset] {
        var unique: [String: UniversalMediaAsset] = [:]
        for asset in similarVideoGroups.flatMap(\.safeCandidates)
        where selectedSimilarVideoAssetIDs.contains(asset.id) {
            unique[asset.id] = asset
        }
        return Array(unique.values)
    }

    var selectedSimilarVideoBytes: Int64 {
        selectedSimilarVideoAssets.reduce(0) { $0 + ($1.byteCount ?? 0) }
    }

    var currentGroup: UniversalExactGroup? {
        guard exactGroups.indices.contains(currentGroupIndex) else { return nil }
        return exactGroups[currentGroupIndex]
    }

    func connectPhotos() async {
        if source == .photos && (authorization == .authorized || authorization == .limited) {
            return
        }
        releaseFolderScope()
        if isPhotosDeniedUITesting {
            authorization = .denied
            source = .none
            shouldConnectPhotosWhenAuthorized = true
            isShowingPhotosPermissionHelp = true
            return
        }
        authorization = await photosAdapter.authorizationStatus()

        switch Self.photosAuthorizationAction(for: authorization) {
        case .requestSystemPermission:
            shouldConnectPhotosWhenAuthorized = true
            authorization = await photosAdapter.requestAuthorization()
        case .connect:
            break
        case .showSettingsHelp, .showRestrictedHelp, .showUnavailableHelp:
            shouldConnectPhotosWhenAuthorized = true
            source = .none
            isShowingPhotosPermissionHelp = true
            return
        }

        guard authorization == .authorized || authorization == .limited else {
            source = .none
            isShowingPhotosPermissionHelp = true
            return
        }
        shouldConnectPhotosWhenAuthorized = false
        source = .photos
        resetResults(clearCheckpoint: false)
    }

    func handleAppLaunchAuthorization() async {
        guard !isPhotosDeniedUITesting,
              !LaunchArguments.contains(LaunchArguments.comprehensiveUITesting),
              !LaunchArguments.contains(LaunchArguments.videoReviewUITesting),
              !LaunchArguments.contains(LaunchArguments.thousandsStressUITesting) else { return }
        
        if case .folder = source { return }
        
        let status = await photosAdapter.authorizationStatus()
        authorization = status
        
        if status == .notDetermined {
            await connectPhotos()
        } else if status == .authorized || status == .limited {
            source = .photos
            resetResults(clearCheckpoint: false)
        }
    }

    func refreshPhotosAuthorization() async {
        let latest = await photosAdapter.authorizationStatus()
        authorization = latest
        guard shouldConnectPhotosWhenAuthorized,
              latest == .authorized || latest == .limited else { return }
        shouldConnectPhotosWhenAuthorized = false
        source = .photos
        resetResults(clearCheckpoint: false)
    }

    func openPhotosSettings() {
        guard authorization == .denied,
              let url = URL(string: UIApplication.openSettingsURLString),
              UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
    }

    var canOpenPhotosSettings: Bool { authorization == .denied }

    var photosPermissionHelpMessage: String {
        switch authorization {
        case .denied:
            return String(localized: "Photos access was denied. Open Settings and allow Photos access for Keptora, then return to the app.")
        case .restricted:
            return String(localized: "Photos access is restricted by this device. Check Screen Time or device-management restrictions.")
        case .unavailable:
            return String(localized: "Photos is not available on this device.")
        default:
            return String(localized: "Keptora needs Photos access only when you choose Photos as a source.")
        }
    }

    static func photosAuthorizationAction(for status: SourceAuthorization) -> PhotosAuthorizationAction {
        switch status {
        case .notDetermined: return .requestSystemPermission
        case .authorized, .limited: return .connect
        case .denied: return .showSettingsHelp
        case .restricted: return .showRestrictedHelp
        case .unavailable: return .showUnavailableHelp
        }
    }

    func manageLimitedPhotosAccess() {
        guard authorization == .limited,
              let scene = UIApplication.shared.connectedScenes.compactMap({ $0 as? UIWindowScene }).first,
              let root = scene.keyWindow?.rootViewController else { return }
        var top = root
        while let presented = top.presentedViewController {
            top = presented
        }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: top)
    }

    func connectFolder(_ url: URL) {
        if case .folder(let currentURL) = source, currentURL == url {
            return
        }
        releaseFolderScope()
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = String(localized: "Keptora could not access this folder.")
            source = .none
            return
        }
        activeFolderScopeURL = url
        activeFolderAdapter = FolderSourceAdapter(rootURL: url, cleanupAvailable: true)
        source = .folder(url)
        authorization = .authorized
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
        } catch {
            errorMessage = error.localizedDescription
        }
        resetResults(clearCheckpoint: false)
    }

    func restoreSavedSource() async {
        guard let bookmark = UserDefaults.standard.data(forKey: bookmarkKey) else { return }
        do {
            var stale = false
            let url = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &stale
            )
            // A stale bookmark still resolves; connectFolder re-creates and stores a fresh one.
            connectFolder(url)
        } catch {
            let ns = error as NSError
            if ns.domain == NSCocoaErrorDomain && (ns.code == NSFileNoSuchFileError || ns.code == NSFileReadNoSuchFileError) {
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
            } else {
                errorMessage = String(localized: "Could not access previously connected folder: \(error.localizedDescription)")
            }
        }
    }

    func startScan(allowNetwork: Bool = false) {
        scanTask?.cancel()
        selectedAssetIDs.removeAll()
        selectedSimilarVideoAssetIDs.removeAll()
        let selectedSource = source
        lastScanAllowedNetwork = allowNetwork
        let checkpoint = loadScanCheckpoint(matching: selectedSource, allowNetwork: allowNetwork)
        if checkpoint == nil { clearScanCheckpoint() }
        suspendedForBackground = false
        scanTask = Task { [weak self] in
            guard let self else { return }
            do {
                let adapter: any SourceAdapter
                let imageProvider: any SimilarityImageProviding
                let videoProvider: any SimilarityVideoProviding
                switch selectedSource {
                case .photos:
                    adapter = photosAdapter
                    imageProvider = photosAdapter
                    videoProvider = photosAdapter
                case .folder:
                    guard let folder = activeFolderAdapter else {
                        scanState = .failed(String(localized: "The selected folder is no longer available."))
                        return
                    }
                    adapter = folder
                    imageProvider = folder
                    videoProvider = folder
                case .none:
                    return
                }
                let result = try await scanner.scan(
                    adapter: adapter,
                    allowNetwork: allowNetwork,
                    resuming: checkpoint,
                    checkpointUpdate: { [weak self] checkpoint in
                        self?.saveScanCheckpoint(checkpoint)
                    },
                    progress: { processed, total, current in
                        Task { @MainActor [weak self] in
                            guard let self, case .scanning = self.scanState else { return }
                            let now = Date()
                            if processed == 0 || processed == total || now.timeIntervalSince(self.lastProgressUpdateTime) >= 0.1 {
                                self.lastProgressUpdateTime = now
                                self.scanState = .scanning(processed: processed, total: total, current: current)
                            }
                        }
                    }
                )
                guard !Task.isCancelled else { return }
                assets = result.assets
                exactGroups = result.groups
                scanFingerprintsByAssetID = result.fingerprintsByAssetID
                skippedCloudItems = result.skippedNetwork
                currentGroupIndex = 0
                scanState = .completed
                clearScanCheckpoint()
                
                // Secondary visual similarity comparison (fail-safe enrichment)
                do {
                    similarityProgress = (0, result.assets.filter { $0.mediaKind == .image }.count)
                    similarityGroups = try await similarityAnalyzer.analyze(
                        assets: result.assets,
                        provider: imageProvider,
                        allowNetwork: allowNetwork,
                        progress: { processed, total in
                            Task { @MainActor [weak self] in
                                self?.similarityProgress = (processed, total)
                            }
                        }
                    )
                    currentSimilarityGroupIndex = 0
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    similarityGroups = []
                }
                similarityProgress = nil

                do {
                    let exactCopyIDs = Set(result.groups.flatMap { group in
                        group.assets.filter { $0.id != group.keeperID }.map(\.id)
                    })
                    let videoCandidates = result.assets
                        .filter { $0.mediaKind == .video && !exactCopyIDs.contains($0.id) }
                        .map { self.withScannedByteCount($0) }
                    videoSimilarityProgress = (0, videoCandidates.count)
                    similarVideoGroups = try await videoSimilarityAnalyzer.analyze(
                        assets: videoCandidates,
                        provider: videoProvider,
                        allowNetwork: allowNetwork,
                        progress: { processed, total in
                            Task { @MainActor [weak self] in
                                self?.videoSimilarityProgress = (processed, total)
                            }
                        }
                    )
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    similarVideoGroups = []
                }
                videoSimilarityProgress = nil
            } catch is CancellationError {
                scanState = suspendedForBackground ? .paused : .idle
                similarityProgress = nil
                videoSimilarityProgress = nil
            } catch {
                scanState = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// True while the similarity passes are still running after the exact scan completed.
    var isAnalyzing: Bool { similarityProgress != nil || videoSimilarityProgress != nil }

    func cancelScan() {
        scanTask?.cancel()
        scanTask = nil
        scanState = .idle
        similarityProgress = nil
        videoSimilarityProgress = nil
        clearScanCheckpoint()
    }

    func suspendScanForBackground() {
        guard scanState.isScanning else { return }
        scanTask?.cancel()
        scanTask = nil
        suspendedForBackground = true
        scanState = .paused
    }

    @discardableResult
    func selectAllSafeCopies(in group: UniversalExactGroup? = nil, isUnlocked: Bool) -> Bool {
        let candidates = group.map(\.safeCopies) ?? exactGroups.flatMap(\.safeCopies)
        return selectAssets(candidates, isUnlocked: isUnlocked)
    }

    @discardableResult
    func selectAssets(_ candidates: [UniversalMediaAsset], isUnlocked: Bool) -> Bool {
        guard authorizeReview(assetIDs: candidates.map(\.id), isUnlocked: isUnlocked) else { return false }
        selectedAssetIDs.formUnion(candidates.map(\.id))
        return true
    }

    @discardableResult
    func toggleSelection(_ asset: UniversalMediaAsset, in group: UniversalExactGroup, isUnlocked: Bool) -> Bool {
        guard asset.id != group.keeperID, !asset.isProtectedFromGlobalSelection else { return true }
        guard authorizeReview(assetIDs: [asset.id], isUnlocked: isUnlocked) else { return false }
        if !selectedAssetIDs.insert(asset.id).inserted { selectedAssetIDs.remove(asset.id) }
        return true
    }

    @discardableResult
    func selectAllSafeSimilarVideos(in group: UniversalSimilarityGroup? = nil, isUnlocked: Bool) -> Bool {
        let groups = group.map { [$0] } ?? similarVideoGroups
        let candidates = groups
            .filter { $0.mediaKind == .video }
            .flatMap(\.safeCandidates)
        guard authorizeReview(assetIDs: candidates.map(\.id), isUnlocked: isUnlocked) else { return false }
        selectedSimilarVideoAssetIDs.formUnion(candidates.map(\.id))
        return true
    }

    @discardableResult
    func toggleSimilarVideoSelection(
        _ asset: UniversalMediaAsset,
        in group: UniversalSimilarityGroup,
        isUnlocked: Bool
    ) -> Bool {
        guard group.mediaKind == .video,
              asset.id != group.keeperID,
              !asset.isProtectedFromGlobalSelection else { return true }
        guard authorizeReview(assetIDs: [asset.id], isUnlocked: isUnlocked) else { return false }
        if !selectedSimilarVideoAssetIDs.insert(asset.id).inserted {
            selectedSimilarVideoAssetIDs.remove(asset.id)
        }
        return true
    }

    func clearSimilarVideoSelection() {
        selectedSimilarVideoAssetIDs.removeAll()
    }

    func clearExactSelection() {
        selectedAssetIDs.removeAll()
    }

    private func executeCleanup(
        selection: [UniversalMediaAsset],
        capturedBytes: Int64,
        resolveFolderCandidates: (URL) async throws -> [(asset: UniversalMediaAsset, expectedDigest: String)],
        onSuccess: () -> Void
    ) async {
        guard !isCleaningUp, !scanState.isScanning, !isAnalyzing else { return }
        guard !selection.isEmpty else { return }
        isCleaningUp = true
        defer { isCleaningUp = false }
        do {
            switch source {
            case .photos:
                let identifiers = selection.compactMap { asset -> String? in
                    guard case .photoLibrary(let identifier) = asset.reference else { return nil }
                    return identifier
                }
                try await photosAdapter.deleteSelectedAssets(localIdentifiers: identifiers)
                history.insert(
                    CleanupHistoryEntry(
                        id: UUID(),
                        kind: .photosRecentlyDeleted,
                        createdAt: Date(),
                        itemCount: selection.count,
                        byteCount: capturedBytes,
                        folderRecord: nil,
                        restoredAt: nil
                    ), at: 0
                )
            case .folder(let root):
                let candidates = try await resolveFolderCandidates(root)
                let record = try await folderCleanup.quarantine(root: root, selections: candidates)
                history.insert(
                    CleanupHistoryEntry(
                        id: record.id,
                        kind: .folderQuarantine,
                        createdAt: record.createdAt,
                        itemCount: record.operations.count,
                        byteCount: capturedBytes,
                        folderRecord: record,
                        restoredAt: nil
                    ), at: 0
                )
            case .none:
                return
            }
            persistHistory()
            onSuccess()
            startScan(allowNetwork: lastScanAllowedNetwork)
        } catch {
            guard !Self.isUserCancellation(error) else { return }
            errorMessage = error.localizedDescription
        }
    }

    func cleanupSelection() async {
        let selection = selectedSafeAssets
        let capturedBytes = selectedBytes
        await executeCleanup(
            selection: selection,
            capturedBytes: capturedBytes,
            resolveFolderCandidates: { [weak self] _ in
                guard let self else { return [] }
                let digestByAsset = Dictionary(self.exactGroups.flatMap { group in
                    group.assets.map { ($0.id, group.digest) }
                }, uniquingKeysWith: { first, _ in first })
                return selection.compactMap { asset -> (asset: UniversalMediaAsset, expectedDigest: String)? in
                    guard let digest = digestByAsset[asset.id] else { return nil }
                    return (asset, digest)
                }
            },
            onSuccess: { [weak self] in
                self?.selectedAssetIDs.removeAll()
            }
        )
    }

    func cleanupSimilarVideoSelection() async {
        let selection = selectedSimilarVideoAssets
        let capturedBytes = selectedSimilarVideoBytes
        await executeCleanup(
            selection: selection,
            capturedBytes: capturedBytes,
            resolveFolderCandidates: { [weak self] _ in
                guard let self else { return [] }
                try await self.verifyUnchanged(selection)
                let candidates = selection.compactMap { asset -> (asset: UniversalMediaAsset, expectedDigest: String)? in
                    guard let digest = self.scanFingerprintsByAssetID[asset.id]?.digest else { return nil }
                    return (asset, digest)
                }
                guard candidates.count == selection.count else {
                    throw UniversalScanError.cleanupNotPermitted("A video could not be reverified. Scan again before cleanup.")
                }
                return candidates
            },
            onSuccess: { [weak self] in
                self?.selectedSimilarVideoAssetIDs.removeAll()
            }
        )
    }

    private static func isUserCancellation(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain && nsError.code == NSUserCancelledError { return true }
        if nsError.domain == "PHPhotosErrorDomain" && nsError.code == 3072 { return true }
        return false
    }

    func restore(_ entry: CleanupHistoryEntry) async {
        guard !scanState.isScanning, !isAnalyzing else { return }
        guard let record = entry.folderRecord else { return }
        do {
            let restored = try await folderCleanup.restore(record)
            if let index = history.firstIndex(where: { $0.id == entry.id }) {
                history[index].folderRecord = restored
                history[index].restoredAt = restored.restoredAt
            }
            persistHistory()
            startScan(allowNetwork: lastScanAllowedNetwork)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteHistory(at offsets: IndexSet) {
        history.remove(atOffsets: offsets)
        persistHistory()
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func resetResults(clearCheckpoint shouldClearCheckpoint: Bool = true) {
        scanTask?.cancel()
        assets = []
        exactGroups = []
        similarityGroups = []
        similarVideoGroups = []
        similarityProgress = nil
        videoSimilarityProgress = nil
        scanFingerprintsByAssetID = [:]
        skippedCloudItems = 0
        selectedAssetIDs = []
        selectedSimilarVideoAssetIDs = []
        currentGroupIndex = 0
        currentSimilarityGroupIndex = 0
        scanState = .idle
        if shouldClearCheckpoint { clearScanCheckpoint() }
    }

    private func releaseFolderScope() {
        activeFolderScopeURL?.stopAccessingSecurityScopedResource()
        activeFolderScopeURL = nil
        activeFolderAdapter = nil
    }

    nonisolated private func saveScanCheckpoint(_ checkpoint: UniversalScanCheckpoint) {
        guard let data = try? JSONEncoder().encode(checkpoint) else { return }
        if let fileURL = scanCheckpointFileURL {
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }
        Task { @MainActor [weak self] in self?.hasScanCheckpoint = true }
    }

    private func loadScanCheckpoint(matching selection: SourceSelection, allowNetwork: Bool) -> UniversalScanCheckpoint? {
        let checkpointData: Data? = {
            if let fileURL = scanCheckpointFileURL, let data = try? Data(contentsOf: fileURL) {
                return data
            }
            if let legacyData = UserDefaults.standard.data(forKey: scanCheckpointKey) {
                UserDefaults.standard.removeObject(forKey: scanCheckpointKey)
                return legacyData
            }
            return nil
        }()
        guard let data = checkpointData,
              let checkpoint = try? JSONDecoder().decode(UniversalScanCheckpoint.self, from: data) else { return nil }
        let expectedSourceID: String?
        switch selection {
        case .photos: expectedSourceID = LibrarySource.photos.id
        case .folder: expectedSourceID = activeFolderAdapter?.source.id
        case .none: expectedSourceID = nil
        }
        guard checkpoint.sourceID == expectedSourceID, checkpoint.allowNetwork == allowNetwork else { return nil }
        return checkpoint
    }

    private func clearScanCheckpoint() {
        if let fileURL = scanCheckpointFileURL {
            try? FileManager.default.removeItem(at: fileURL)
        }
        UserDefaults.standard.removeObject(forKey: scanCheckpointKey)
        hasScanCheckpoint = false
    }

    private func authorizeReview(assetIDs: [String], isUnlocked: Bool) -> Bool {
        let newIDs = Set(assetIDs).subtracting(reviewedAssetIDs)
        guard isUnlocked || reviewedAssetIDs.count + newIDs.count <= freeReviewLimit else { return false }
        reviewedAssetIDs.formUnion(newIDs)
        UserDefaults.standard.set(Array(reviewedAssetIDs).sorted(), forKey: reviewedAssetsKey)
        return true
    }

    private func withScannedByteCount(_ asset: UniversalMediaAsset) -> UniversalMediaAsset {
        guard let fingerprint = scanFingerprintsByAssetID[asset.id] else { return asset }
        return asset.with(byteCount: fingerprint.byteCount)
    }

    private func verifyUnchanged(_ selection: [UniversalMediaAsset]) async throws {
        for asset in selection {
            guard let expected = scanFingerprintsByAssetID[asset.id] else {
                throw UniversalScanError.cleanupNotPermitted("A video could not be reverified. Scan again before cleanup.")
            }
            let fresh: UniversalExactFingerprint
            switch source {
            case .photos:
                fresh = try await photosAdapter.exactFingerprint(
                    for: asset,
                    allowNetwork: lastScanAllowedNetwork,
                    progress: { _ in }
                )
            case .folder:
                guard let adapter = activeFolderAdapter else {
                    throw UniversalScanError.cleanupNotPermitted("The selected folder is no longer available.")
                }
                fresh = try await adapter.exactFingerprint(for: asset, allowNetwork: false, progress: { _ in })
            case .none:
                throw UniversalScanError.cleanupNotPermitted("Choose a source and scan again.")
            }
            guard fresh == expected else {
                throw UniversalScanError.cleanupNotPermitted("A selected video changed after review. Scan again before cleanup.")
            }
        }
    }

    private func seedVideoReviewForUITesting() {
        let root = URL(fileURLWithPath: "/tmp/Keptora-Video-UI-Test", isDirectory: true)
        let exactKeeper = UniversalMediaAsset(
            id: "ui-exact-keeper",
            sourceID: "ui-test",
            reference: .file(root.appendingPathComponent("Original.mov")),
            displayName: "Original.mov",
            mediaKind: .video,
            byteCount: 8_000_000,
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: 14
        )
        let exactCopy = UniversalMediaAsset(
            id: "ui-exact-copy",
            sourceID: "ui-test",
            reference: .file(root.appendingPathComponent("Exact Copy.mov")),
            displayName: "Exact Copy.mov",
            mediaKind: .video,
            byteCount: 8_000_000,
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: 14
        )
        let similarKeeper = UniversalMediaAsset(
            id: "ui-similar-keeper",
            sourceID: "ui-test",
            reference: .file(root.appendingPathComponent("Best Take.mov")),
            displayName: "Best Take.mov",
            mediaKind: .video,
            byteCount: 12_000_000,
            pixelWidth: 3840,
            pixelHeight: 2160,
            duration: 16
        )
        let similarCandidate = UniversalMediaAsset(
            id: "ui-similar-candidate",
            sourceID: "ui-test",
            reference: .file(root.appendingPathComponent("Second Take.mov")),
            displayName: "Second Take.mov",
            mediaKind: .video,
            byteCount: 7_000_000,
            pixelWidth: 1920,
            pixelHeight: 1080,
            duration: 16
        )
        source = .folder(root)
        authorization = .authorized
        scanState = .completed
        assets = [exactKeeper, exactCopy, similarKeeper, similarCandidate]
        exactGroups = [UniversalExactGroup(digest: "ui-exact", assets: [exactKeeper, exactCopy], keeperID: exactKeeper.id)]
        similarVideoGroups = [UniversalSimilarityGroup(
            id: "ui-similar-video",
            assets: [similarKeeper, similarCandidate],
            maximumDistance: 0.18,
            mediaKind: .video,
            keeperID: similarKeeper.id
        )]
    }

    private func seedComprehensiveReviewForUITesting() {
        seedVideoReviewForUITesting()
        let root = URL(fileURLWithPath: "/tmp/Keptora-Comprehensive-UI-Test", isDirectory: true)
        let photoKeeper = UniversalMediaAsset(
            id: "ui-photo-keeper",
            sourceID: "ui-test",
            reference: .file(root.appendingPathComponent("Portrait Original.heic")),
            displayName: "Portrait Original.heic",
            mediaKind: .image,
            byteCount: 4_200_000,
            pixelWidth: 4032,
            pixelHeight: 3024
        )
        let photoCopy = UniversalMediaAsset(
            id: "ui-photo-copy",
            sourceID: "ui-test",
            reference: .file(root.appendingPathComponent("Portrait Copy.heic")),
            displayName: "Portrait Copy.heic",
            mediaKind: .image,
            byteCount: 4_200_000,
            pixelWidth: 4032,
            pixelHeight: 3024
        )
        let similarPhotoA = UniversalMediaAsset(
            id: "ui-similar-photo-a",
            sourceID: "ui-test",
            reference: .file(root.appendingPathComponent("Golden Hour 1.heic")),
            displayName: "Golden Hour 1.heic",
            mediaKind: .image,
            byteCount: 3_800_000,
            pixelWidth: 4032,
            pixelHeight: 3024
        )
        let similarPhotoB = UniversalMediaAsset(
            id: "ui-similar-photo-b",
            sourceID: "ui-test",
            reference: .file(root.appendingPathComponent("Golden Hour 2.heic")),
            displayName: "Golden Hour 2.heic",
            mediaKind: .image,
            byteCount: 3_600_000,
            pixelWidth: 4032,
            pixelHeight: 3024
        )
        assets.append(contentsOf: [photoKeeper, photoCopy, similarPhotoA, similarPhotoB])
        exactGroups.append(
            UniversalExactGroup(
                digest: "ui-photo-exact",
                assets: [photoKeeper, photoCopy],
                keeperID: photoKeeper.id
            )
        )
        similarityGroups = [UniversalSimilarityGroup(
            id: "ui-similar-photo",
            assets: [similarPhotoA, similarPhotoB],
            maximumDistance: 0.12,
            mediaKind: .image,
            keeperID: similarPhotoA.id
        )]
        history = [
            CleanupHistoryEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                kind: .photosRecentlyDeleted,
                createdAt: Date(timeIntervalSince1970: 1_786_000_000),
                itemCount: 3,
                byteCount: 12_000_000,
                folderRecord: nil,
                restoredAt: nil
            ),
            CleanupHistoryEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000102")!,
                kind: .folderQuarantine,
                createdAt: Date(timeIntervalSince1970: 1_786_000_100),
                itemCount: 2,
                byteCount: 8_000_000,
                folderRecord: nil,
                restoredAt: Date(timeIntervalSince1970: 1_786_000_200)
            )
        ]
    }

    private func seedThousandsStressUITesting() {
        let root = URL(fileURLWithPath: "/tmp/keptora_simulator_corpus", isDirectory: true)
        source = .folder(root)
        authorization = .authorized
        scanState = .completed
        
        var generatedAssets: [UniversalMediaAsset] = []
        var generatedExactGroups: [UniversalExactGroup] = []
        var generatedSimilarPhotoGroups: [UniversalSimilarityGroup] = []
        var generatedSimilarVideoGroups: [UniversalSimilarityGroup] = []
        
        // 300 Exact Photo Groups (750 photos)
        for i in 1...300 {
            let keeper = UniversalMediaAsset(
                id: "stress-photo-keeper-\(i)",
                sourceID: "stress-test",
                reference: .file(root.appendingPathComponent("Photo_Group_\(i)_Original.jpg")),
                displayName: "Photo_Group_\(i)_Original.jpg",
                mediaKind: .image,
                byteCount: Int64(2_400_000 + (i * 10_000)),
                pixelWidth: 3840,
                pixelHeight: 2160
            )
            let copyA = UniversalMediaAsset(
                id: "stress-photo-copy-a-\(i)",
                sourceID: "stress-test",
                reference: .file(root.appendingPathComponent("Photo_Group_\(i)_Copy_A.jpg")),
                displayName: "Photo_Group_\(i)_Copy_A.jpg",
                mediaKind: .image,
                byteCount: keeper.byteCount,
                pixelWidth: 3840,
                pixelHeight: 2160
            )
            var groupAssets = [keeper, copyA]
            if i % 2 == 0 {
                let copyB = UniversalMediaAsset(
                    id: "stress-photo-copy-b-\(i)",
                    sourceID: "stress-test",
                    reference: .file(root.appendingPathComponent("Photo_Group_\(i)_Copy_B.jpg")),
                    displayName: "Photo_Group_\(i)_Copy_B.jpg",
                    mediaKind: .image,
                    byteCount: keeper.byteCount,
                    pixelWidth: 3840,
                    pixelHeight: 2160
                )
                groupAssets.append(copyB)
            }
            generatedAssets.append(contentsOf: groupAssets)
            generatedExactGroups.append(UniversalExactGroup(digest: "stress-digest-\(i)", assets: groupAssets, keeperID: keeper.id))
        }
        
        // 25 Exact Video Groups (60 videos)
        for i in 1...25 {
            let keeper = UniversalMediaAsset(
                id: "stress-video-keeper-\(i)",
                sourceID: "stress-test",
                reference: .file(root.appendingPathComponent("Video_Group_\(i)_Original.mp4")),
                displayName: "Video_Group_\(i)_Original.mp4",
                mediaKind: .video,
                byteCount: Int64(45_000_000 + (i * 1_000_000)),
                pixelWidth: 1920,
                pixelHeight: 1080,
                duration: Double(15 + i)
            )
            let copy = UniversalMediaAsset(
                id: "stress-video-copy-\(i)",
                sourceID: "stress-test",
                reference: .file(root.appendingPathComponent("Video_Group_\(i)_Copy.mp4")),
                displayName: "Video_Group_\(i)_Copy.mp4",
                mediaKind: .video,
                byteCount: keeper.byteCount,
                pixelWidth: 1920,
                pixelHeight: 1080,
                duration: keeper.duration
            )
            generatedAssets.append(contentsOf: [keeper, copy])
            generatedExactGroups.append(UniversalExactGroup(digest: "stress-video-digest-\(i)", assets: [keeper, copy], keeperID: keeper.id))
        }
        
        // 50 Similar Photo Groups (150 photos)
        for i in 1...50 {
            let keeper = UniversalMediaAsset(
                id: "stress-burst-keeper-\(i)",
                sourceID: "stress-test",
                reference: .file(root.appendingPathComponent("Burst_Set_\(i)_Shot_1.jpg")),
                displayName: "Burst_Set_\(i)_Shot_1.jpg",
                mediaKind: .image,
                byteCount: Int64(3_000_000 + (i * 5_000)),
                pixelWidth: 3840,
                pixelHeight: 2160
            )
            let burst2 = UniversalMediaAsset(
                id: "stress-burst-shot2-\(i)",
                sourceID: "stress-test",
                reference: .file(root.appendingPathComponent("Burst_Set_\(i)_Shot_2.jpg")),
                displayName: "Burst_Set_\(i)_Shot_2.jpg",
                mediaKind: .image,
                byteCount: Int64(3_050_000 + (i * 5_000)),
                pixelWidth: 3840,
                pixelHeight: 2160
            )
            generatedAssets.append(contentsOf: [keeper, burst2])
            generatedSimilarPhotoGroups.append(UniversalSimilarityGroup(
                id: "stress-burst-group-\(i)",
                assets: [keeper, burst2],
                maximumDistance: 0.12,
                mediaKind: .image,
                keeperID: keeper.id
            ))
        }
        
        // 15 Similar Video Groups (30 videos)
        for i in 1...15 {
            let vid1 = UniversalMediaAsset(
                id: "stress-sim-video-1-\(i)",
                sourceID: "stress-test",
                reference: .file(root.appendingPathComponent("Similar_Video_\(i)_Take_1.mp4")),
                displayName: "Similar_Video_\(i)_Take_1.mp4",
                mediaKind: .video,
                byteCount: Int64(30_000_000 + (i * 500_000)),
                pixelWidth: 1920,
                pixelHeight: 1080,
                duration: 20
            )
            let vid2 = UniversalMediaAsset(
                id: "stress-sim-video-2-\(i)",
                sourceID: "stress-test",
                reference: .file(root.appendingPathComponent("Similar_Video_\(i)_Take_2.mp4")),
                displayName: "Similar_Video_\(i)_Take_2.mp4",
                mediaKind: .video,
                byteCount: Int64(31_000_000 + (i * 500_000)),
                pixelWidth: 1920,
                pixelHeight: 1080,
                duration: 20
            )
            generatedAssets.append(contentsOf: [vid1, vid2])
            generatedSimilarVideoGroups.append(UniversalSimilarityGroup(
                id: "stress-sim-video-group-\(i)",
                assets: [vid1, vid2],
                maximumDistance: 0.15,
                mediaKind: .video,
                keeperID: vid1.id
            ))
        }
        
        assets = generatedAssets
        exactGroups = generatedExactGroups
        similarityGroups = generatedSimilarPhotoGroups
        similarVideoGroups = generatedSimilarVideoGroups
        
        history = [
            CleanupHistoryEntry(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000101")!,
                kind: .photosRecentlyDeleted,
                createdAt: Date(timeIntervalSince1970: 1_786_000_000),
                itemCount: 48,
                byteCount: 840_000_000,
                folderRecord: nil,
                restoredAt: nil
            )
        ]
    }
}
