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
    case onboarding
    case sourceSetup

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
        var sourceBookmark: Data? = nil
    }

    @Published private(set) var source: SourceSelection = .none
    @Published private(set) var authorization: SourceAuthorization = .notDetermined
    @Published var scanState: ScanState = .idle
    @Published private(set) var assets: [UniversalMediaAsset] = []
    @Published internal(set) var exactGroups: [UniversalExactGroup] = []
    @Published private(set) var similarityGroups: [UniversalSimilarityGroup] = []
    @Published internal(set) var similarVideoGroups: [UniversalSimilarityGroup] = []
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
    @Published var startupSourcesPrepared = false
    @Published private(set) var isRequestingPhotosAccess = false
    @Published var isShowingPhotosPermissionHelp = false
    @Published var errorMessage: String?
    @Published private(set) var isLoadingCatalogue = false
    @Published var catalogueError: String?
    @Published var skippedSimilarityPreviews = 0
    @Published var similarityError: String?
    @Published var videoSimilarityError: String?
    @Published var selectedLibraryIDs: Set<String> = []
    @Published var libraryCollectionIDs: Set<String>?
    @Published var libraryCollectionTitle: String?
    @Published var libraryCollectionSortBySize = false
    @Published var libraryCollectionKind: String?
    @Published var cleanupStatus: String?
    private var catalogueTask: Task<Void, Never>?
    private var catalogueGeneration = UUID()
    private var scanGeneration = UUID()
    private var manualSelectionIsLoaded = false
    private var photoObserver: MobilePhotoChangeObserver?


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
    @Published private(set) var connectedFolders: [LibrarySource] = []
    @Published private(set) var coverage: [LibrarySourceCoverage] = []
    @Published private(set) var connectionErrors: [String] = []
    @Published private(set) var scanSourceSelection = LibrarySourceSelection(excludedIDs: Set(UserDefaults.standard.stringArray(forKey: AppStorageKeys.iOSExcludedScanSources) ?? []))
    private var sourceCatalogue = LibrarySourceCatalogue()
    private var folderAdapters: [String: FolderSourceAdapter] = [:]
    private var folderScopes: [String: URL] = [:]
    private var folderBookmarks: [String: Data] = [:]
    private var photosConnected = false
    var connectedSources: [LibrarySource] { (photosConnected ? [.photos] : []) + connectedFolders }
    var libraryTitle: String { sourceSelectionState == .all ? String(localized: "All Connected Sources") : String(localized: "Selected Sources") }
    var selectedSourceIDs: Set<String> { scanSourceSelection.selectedIDs(in: connectedSources, coverage: coverage) }
    var scopedAssets: [UniversalMediaAsset] { sourceCatalogue.assets(in: connectedSources, selectedIDs: selectedSourceIDs, current: assets) }
    var sourceControlsDisabled: Bool { isCleaningUp || scanState.isScanning || isAnalyzing || isLoadingCatalogue || isRequestingPhotosAccess }
    var canScanSelectedSources: Bool { !sourceControlsDisabled && !selectedSourceIDs.isEmpty }
    var sourceSelectionState: LibrarySourceSelection.State { scanSourceSelection.state(in: connectedSources, coverage: coverage) }
    func toggleScanSource(_ id: String) {
        guard !sourceControlsDisabled, connectedSources.contains(where: { $0.id == id }),
              LibrarySourceSelection().selectedIDs(in: connectedSources, coverage: coverage).contains(id) else { return }
        scanSourceSelection.setSelected(!selectedSourceIDs.contains(id), id: id)
        scanSourcesChanged()
    }
    func toggleAllScanSources() {
        guard !sourceControlsDisabled else { return }
        scanSourceSelection.toggleAll(in: connectedSources, coverage: coverage)
        scanSourcesChanged()
    }
    private func scanSourcesChanged() {
        UserDefaults.standard.set(Array(scanSourceSelection.excludedIDs).sorted(), forKey: AppStorageKeys.iOSExcludedScanSources)
        exactGroups = []; similarityGroups = []; similarVideoGroups = []
        selectedAssetIDs = []; selectedSimilarVideoAssetIDs = []
        scanFingerprintsByAssetID = [:]; scanState = .idle
        skippedCloudItems = 0; similarityError = nil; videoSimilarityError = nil
        libraryCollectionIDs = nil; libraryCollectionTitle = nil; libraryCollectionKind = nil
        libraryCollectionSortBySize = false
        clearScanCheckpoint()
    }
    private var connectedAdapters: [any SourceAdapter] {
        var adapters: [any SourceAdapter] = []
        if photosConnected { adapters.append(photosAdapter) }
        adapters.append(contentsOf: connectedFolders.compactMap { folderAdapters[$0.id] })
        return adapters
    }
    var unifiedAdapter: UnifiedLibraryAdapter { UnifiedLibraryAdapter(adapters: connectedAdapters) }
    private var scanAdapter: UnifiedLibraryAdapter { UnifiedLibraryAdapter(adapters: connectedAdapters, selectedSourceIDs: selectedSourceIDs) }
    var reviewGroups: [LibraryReviewGroup] { LibraryReviewGroup.combined(exact: exactGroups, similar: similarityGroups + similarVideoGroups) }
    func sourceLabel(_ asset: UniversalMediaAsset) -> String {
        asset.sourceLabel(in: connectedSources)
    }
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
        if LaunchArguments.contains(LaunchArguments.resetSourceSetupUITesting) {
            UserDefaults.standard.removeObject(forKey: AppStorageKeys.iOSSourceSetupCompleted)
        }
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
        if LaunchArguments.contains(LaunchArguments.videoReviewUITesting) || LaunchArguments.contains(LaunchArguments.comprehensiveUITesting) || LaunchArguments.contains(LaunchArguments.thousandsStressUITesting) {
            connectedFolders = Set(assets.map(\.sourceID)).sorted().map { LibrarySource(id: $0, kind: .folder, displayName: "Test Library") }
            sourceCatalogue = LibrarySourceCatalogue(batches: Dictionary(grouping: assets, by: \.sourceID))
            coverage = connectedFolders.map { LibrarySourceCoverage(source: $0, authorization: .authorized, itemCount: sourceCatalogue.batches[$0.id]?.count ?? 0) }
        }
    }

    deinit {
        catalogueTask?.cancel()
        scanTask?.cancel()
        for url in folderScopes.values { url.stopAccessingSecurityScopedResource() }
    }

    var dashboard: DashboardSnapshot {
        DashboardSnapshot(scannedItems: assets.count, groups: exactGroups)
    }

    var selectedSafeAssets: [UniversalMediaAsset] {
        var unique: [String: UniversalMediaAsset] = [:]
        for asset in exactGroups.flatMap(\.assets) where selectedAssetIDs.contains(asset.id) {
            unique[asset.id] = asset
        }
        return Array(unique.values)
    }

    var selectedBytes: Int64 {
        selectedSafeAssets.reduce(0) { $0 + ($1.byteCount ?? 0) }
    }

    var selectedSimilarVideoAssets: [UniversalMediaAsset] {
        var unique: [String: UniversalMediaAsset] = [:]
        for asset in similarVideoGroups.flatMap(\.assets)
        where selectedSimilarVideoAssetIDs.contains(asset.id) {
            unique[asset.id] = asset
        }
        return Array(unique.values)
    }

    var selectedSimilarVideoBytes: Int64 {
        selectedSimilarVideoAssets.reduce(0) { $0 + ($1.byteCount ?? 0) }
    }

    var hasSelectedKeeper: Bool {
        exactGroups.contains { group in
            selectedAssetIDs.contains(group.keeperID)
        } || similarVideoGroups.contains { group in
            selectedSimilarVideoAssetIDs.contains(group.keeperID)
        }
    }

    var exactGroupsWithAllCopiesSelectedCount: Int {
        exactGroups.filter { group in
            !group.assets.isEmpty && group.assets.allSatisfy { selectedAssetIDs.contains($0.id) }
        }.count
    }

    var similarVideoGroupsWithAllCopiesSelectedCount: Int {
        similarVideoGroups.filter { group in
            !group.assets.isEmpty && group.assets.allSatisfy { selectedSimilarVideoAssetIDs.contains($0.id) }
        }.count
    }

    var hasAnyGroupWithAllCopiesSelected: Bool {
        exactGroupsWithAllCopiesSelectedCount > 0 || similarVideoGroupsWithAllCopiesSelectedCount > 0
    }

    var currentGroup: UniversalExactGroup? {
        guard exactGroups.indices.contains(currentGroupIndex) else { return nil }
        return exactGroups[currentGroupIndex]
    }

    func connectPhotos() async {
        guard !isCleaningUp, !scanState.isScanning, !isAnalyzing, !isRequestingPhotosAccess else { return }
        isRequestingPhotosAccess = true
        defer { isRequestingPhotosAccess = false }
        if photosConnected && (authorization == .authorized || authorization == .limited) { return }
        if isPhotosDeniedUITesting {
            authorization = .denied
            source = connectedFolders.first.flatMap { folderScopes[$0.id] }.map(SourceSelection.folder) ?? .none
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
            source = connectedFolders.first.flatMap { folderScopes[$0.id] }.map(SourceSelection.folder) ?? .none
            isShowingPhotosPermissionHelp = true
            return
        }

        guard authorization == .authorized || authorization == .limited else {
            source = connectedFolders.first.flatMap { folderScopes[$0.id] }.map(SourceSelection.folder) ?? .none
            isShowingPhotosPermissionHelp = true
            return
        }
        shouldConnectPhotosWhenAuthorized = false
        photosConnected = true
        source = .photos
        resetResults(clearCheckpoint: false)
        // Permission resolution must not keep the setup's Continue button locked
        // while a large catalogue is loading.
        isRequestingPhotosAccess = false
        await loadCatalogue()
    }

    func handleAppLaunchAuthorization() async {
        guard !isPhotosDeniedUITesting,
              !LaunchArguments.contains(LaunchArguments.comprehensiveUITesting),
              !LaunchArguments.contains(LaunchArguments.videoReviewUITesting),
              !LaunchArguments.contains(LaunchArguments.thousandsStressUITesting) else { return }
        
        
        let status = await photosAdapter.authorizationStatus()
        authorization = status
        
        if status == .authorized || status == .limited {
            photosConnected = true
            source = .photos
            await loadCatalogue()
        }
    }

    func refreshPhotosAuthorization() async {
        guard startupSourcesPrepared, !isRequestingPhotosAccess, !isPhotosDeniedUITesting,
              !LaunchArguments.contains(LaunchArguments.comprehensiveUITesting),
              !LaunchArguments.contains(LaunchArguments.videoReviewUITesting),
              !LaunchArguments.contains(LaunchArguments.thousandsStressUITesting) else { return }
        let latest = await photosAdapter.authorizationStatus()
        authorization = latest
        if latest != .authorized && latest != .limited {
            if photosConnected {
                photosConnected = false
                source = connectedFolders.first.flatMap { folderScopes[$0.id] }.map(SourceSelection.folder) ?? .none
                resetResults(clearCheckpoint: false)
                await loadCatalogue()
            }
            return
        }
        photosConnected = true
        source = .photos
        shouldConnectPhotosWhenAuthorized = false
        if !isCleaningUp && !scanState.isScanning && !isAnalyzing { await loadCatalogue() }
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
        guard !isCleaningUp, !scanState.isScanning, !isAnalyzing else { return }
        let adapter = FolderSourceAdapter(rootURL: url, cleanupAvailable: true)
        guard folderAdapters[adapter.source.id] == nil else { return }
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = String(localized: "Keptora could not access this folder."); return
        }
        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            folderScopes[adapter.source.id] = url
            folderAdapters[adapter.source.id] = adapter
            folderBookmarks[adapter.source.id] = bookmark
            connectedFolders.append(adapter.source)
            UserDefaults.standard.set(folderBookmarks, forKey: "Keptora.UnifiedFolderBookmarks.iOS")
            if !photosConnected { source = .folder(url) }
            resetResults(clearCheckpoint: false)
            Task { await loadCatalogue() }
        } catch { url.stopAccessingSecurityScopedResource(); errorMessage = error.localizedDescription }
    }

    func disconnectFolder(_ id: String) {
        guard !isCleaningUp, !scanState.isScanning, !isAnalyzing else { return }
        folderScopes.removeValue(forKey: id)?.stopAccessingSecurityScopedResource()
        folderAdapters.removeValue(forKey: id); folderBookmarks.removeValue(forKey: id)
        connectedFolders.removeAll { $0.id == id }
        UserDefaults.standard.set(folderBookmarks, forKey: "Keptora.UnifiedFolderBookmarks.iOS")
        source = photosConnected ? .photos : connectedFolders.first.flatMap { folderScopes[$0.id] }.map(SourceSelection.folder) ?? .none
        resetResults(clearCheckpoint: false)
        Task { await loadCatalogue() }
    }

    var librarySelection: [UniversalMediaAsset] {
        assets.filter { selectedLibraryIDs.contains($0.id) }
    }

    var albums: [MediaAlbum] {
        var unique: [String: MediaAlbum] = [:]
        for asset in scopedAssets { for album in asset.context?.albums ?? [] { unique[album.id] = album } }
        return unique.values.sorted { $0.title.localizedStandardCompare($1.title) == .orderedAscending }
    }

    private var librarySelectionKey: String { "Keptora.ManualSelection.unified.iOS" }

    func saveLibrarySelection() {
        guard manualSelectionIsLoaded, source != .none else { return }
        UserDefaults.standard.set(Array(selectedLibraryIDs).sorted(), forKey: librarySelectionKey)
    }

    func toggleLibrarySelection(_ asset: UniversalMediaAsset) {
        guard !isCleaningUp else { return }
        if !selectedLibraryIDs.insert(asset.id).inserted { selectedLibraryIDs.remove(asset.id) }
        saveLibrarySelection()
    }

    func openCollection(_ items: [UniversalMediaAsset], title: String, sortBySize: Bool = false, kind: String? = nil) {
        libraryCollectionIDs = Set(items.map(\.id))
        libraryCollectionTitle = title
        libraryCollectionSortBySize = sortBySize
        libraryCollectionKind = kind
        selectedTab = .library
    }

    func collectionContains(_ item: UniversalMediaAsset) -> Bool {
        switch libraryCollectionKind {
        case "Screenshots": return item.context?.isScreenshot == true
        case "Videos by Size": return item.mediaKind == .video
        case "Live Photos": return item.context?.isLivePhoto == true
        default: return libraryCollectionIDs == nil || libraryCollectionIDs!.contains(item.id)
        }
    }

    func loadCatalogue() async {
        guard source != .none, !isCleaningUp, !scanState.isScanning, !isAnalyzing else { return }
        catalogueTask?.cancel()
        let generation = UUID()
        catalogueGeneration = generation
        let requestedSource = source
        isLoadingCatalogue = true
        catalogueError = nil
        catalogueTask = Task { [weak self] in
            guard let self else { return }
            defer { if catalogueGeneration == generation { isLoadingCatalogue = false } }
            do {
                let adapter = unifiedAdapter
                let catalogue = try await adapter.enumerateAssets()
                let reports = await adapter.coverage
                guard !Task.isCancelled, requestedSource == source, catalogueGeneration == generation else { return }
                coverage = reports
                sourceCatalogue = await adapter.catalogue
                let previous = Dictionary(assets.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                if catalogue.contains(where: { item in previous[item.id]?.modificationDate != item.modificationDate }) || Set(previous.keys) != Set(catalogue.map(\.id)) {
                    exactGroups = []; similarityGroups = []; similarVideoGroups = []
                    scanFingerprintsByAssetID = [:]; scanState = .idle
                }
                assets = catalogue.sorted { ($0.creationDate ?? .distantPast) > ($1.creationDate ?? .distantPast) }
                if selectedLibraryIDs.isEmpty {
                    if UserDefaults.standard.object(forKey: librarySelectionKey) == nil {
                        selectedLibraryIDs.formUnion(UserDefaults.standard.stringArray(forKey: "Keptora.ManualSelection.photos") ?? [])
                        for url in folderScopes.values {
                            selectedLibraryIDs.formUnion(UserDefaults.standard.stringArray(forKey: "Keptora.ManualSelection." + StableDigest.fnv1a64(url.standardizedFileURL.path)) ?? [])
                        }
                    } else { selectedLibraryIDs = Set(UserDefaults.standard.stringArray(forKey: librarySelectionKey) ?? []) }
                }
                for item in catalogue {
                    if case .file(let url) = item.reference {
                        let legacyID = "file:" + StableDigest.fnv1a64(item.sourceID + "|" + url.standardizedFileURL.path)
                        if selectedLibraryIDs.remove(legacyID) != nil { selectedLibraryIDs.insert(item.id) }
                    }
                }
                selectedLibraryIDs.formIntersection(catalogue.map(\.id))
                manualSelectionIsLoaded = true
                saveLibrarySelection()
                for connected in connectedFolders {
                    guard let root = folderScopes[connected.id] else { continue }
                    let records = try await folderCleanup.recoveryRecords(root: root)
                    guard !Task.isCancelled, catalogueGeneration == generation else { return }
                    for record in records {
                        if let index = history.firstIndex(where: { $0.id == record.id }) {
                            history[index].folderRecord = record; history[index].restoredAt = record.restoredAt
                            continue
                        }
                        history.insert(CleanupHistoryEntry(id: record.id, kind: .folderQuarantine, createdAt: record.createdAt,
                            itemCount: record.operations.count, byteCount: 0, folderRecord: record, restoredAt: record.restoredAt,
                            sourceBookmark: folderBookmarks[connected.id]), at: 0)
                    }
                    persistHistory()
                }
                if photosConnected && photoObserver == nil {
                    photoObserver = MobilePhotoChangeObserver { [weak self] in
                        Task { @MainActor in await self?.loadCatalogue() }
                    }
                }
            } catch is CancellationError { }
            catch { if catalogueGeneration == generation { catalogueError = error.localizedDescription } }
        }
        await catalogueTask?.value
    }

    @discardableResult
    func cleanupLibrarySelection(expectedIDs: Set<String>) async -> Bool {
        guard selectedLibraryIDs == expectedIDs else {
            errorMessage = String(localized: "Your selection changed. Review it again before removing items.")
            return false
        }
        let snapshot = librarySelection
        guard snapshot.count == expectedIDs.count else { return false }
        return await executeCleanup(selection: snapshot,
            intent: .manualSelection,
            resolveFolderCandidates: { [weak self] in
                guard let self else { return [] }
                let adapter = unifiedAdapter
                var result: [(asset: UniversalMediaAsset, expectedDigest: String)] = []
                for item in snapshot.filter({ if case .file = $0.reference { return true }; return false }) {
                    let fingerprint = try await adapter.exactFingerprint(for: item, allowNetwork: false, progress: { _ in })
                    result.append((item, fingerprint.digest))
                }
                return result
            }, onSuccess: { [weak self] in self?.selectedLibraryIDs.removeAll(); self?.saveLibrarySelection() })
    }

    func restoreSavedSource() async {
        var saved = UserDefaults.standard.dictionary(forKey: "Keptora.UnifiedFolderBookmarks.iOS")?.compactMapValues { $0 as? Data } ?? [:]
        if saved.isEmpty, let legacy = UserDefaults.standard.data(forKey: bookmarkKey) { saved["legacy"] = legacy }
        folderBookmarks = saved
        connectionErrors.removeAll()
        for bookmark in saved.values {
            do {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
                connectFolder(url)
            } catch { connectionErrors.append(String(localized: "Reconnect an unavailable folder in Sources.")) }
        }
    }

    func startScan(allowNetwork: Bool = false) {
        guard canScanSelectedSources else { return }
        scanTask?.cancel()
        catalogueTask?.cancel()
        catalogueGeneration = UUID(); isLoadingCatalogue = false
        let generation = UUID(); scanGeneration = generation
        similarityError = nil
        videoSimilarityError = nil
        selectedAssetIDs.removeAll()
        selectedSimilarVideoAssetIDs.removeAll()
        let selectedSource = source
        guard selectedSource != .none else { return }
        print("[KeptoraScan] Starting scan for source: \(selectedSource), allowNetwork: \(allowNetwork)")
        lastScanAllowedNetwork = allowNetwork
        let checkpoint = loadScanCheckpoint(allowNetwork: allowNetwork)
        if checkpoint == nil { clearScanCheckpoint() }
        suspendedForBackground = false
        scanState = .scanning(processed: 0, total: max(scopedAssets.count, 1), current: String(localized: "Connecting to library…"))
        lastProgressUpdateTime = Date()
        UIApplication.shared.isIdleTimerDisabled = true
        scanTask = Task { [weak self] in
            guard let self else { return }
            defer {
                Task { @MainActor in
                    if self.scanGeneration == generation { UIApplication.shared.isIdleTimerDisabled = false }
                }
            }
            do {
                let adapter = scanAdapter
                let imageProvider = adapter
                let videoProvider = adapter
                print("[KeptoraScan] Calling scanner.scan...")
                let result = try await scanner.scan(
                    adapter: adapter,
                    allowNetwork: allowNetwork,
                    fingerprintAllAssets: true,
                    resuming: checkpoint,
                    checkpointUpdate: { [weak self] checkpoint in
                        Task { @MainActor in
                            guard let self, self.scanGeneration == generation else { return }
                            self.saveScanCheckpoint(checkpoint)
                        }
                    },
                    progress: { processed, total, current in
                        Task { @MainActor [weak self] in
                            guard let self, self.scanGeneration == generation else { return }
                            let now = Date()
                            if processed == 0 || processed == total || now.timeIntervalSince(self.lastProgressUpdateTime) >= 0.05 {
                                self.lastProgressUpdateTime = now
                                self.scanState = .scanning(processed: processed, total: total, current: current)
                                if processed % 100 == 0 || processed == total {
                                    print("[KeptoraScan] Progress: \(processed)/\(total) (\(current))")
                                }
                            }
                        }
                    }
                )
                guard !Task.isCancelled, scanGeneration == generation else { return }
                print("[KeptoraScan] Exact scan done: \(result.assets.count) assets, \(result.groups.count) exact duplicate groups, skippedNetwork: \(result.skippedNetwork)")
                sourceCatalogue.merge(await adapter.catalogue)
                let scanned = result.assets.map { asset in
                    guard let fingerprint = result.fingerprintsByAssetID[asset.id] else { return asset }
                    return asset.with(byteCount: .some(fingerprint.byteCount))
                }
                assets = sourceCatalogue.assets(in: connectedSources, selectedIDs: Set(connectedSources.map(\.id)), current: scanned + assets)
                selectedLibraryIDs.formIntersection(assets.map(\.id)); saveLibrarySelection()
                let reports = await adapter.coverage
                coverage = connectedSources.compactMap { source in reports.first { $0.id == source.id } ?? coverage.first { $0.id == source.id } }
                exactGroups = result.groups
                scanFingerprintsByAssetID = result.fingerprintsByAssetID
                skippedCloudItems = result.skippedNetwork
                currentGroupIndex = 0
                scanState = .completed
                clearScanCheckpoint()
                
                // Secondary visual similarity comparison (fail-safe enrichment)
                do {
                    similarityProgress = (0, result.assets.filter { $0.mediaKind == .image }.count)
                    let photoGroups = try await similarityAnalyzer.analyze(
                        assets: result.assets,
                        provider: imageProvider,
                        allowNetwork: allowNetwork,
                        progress: { processed, total in
                            Task { @MainActor [weak self] in
                                guard let self, self.scanGeneration == generation else { return }
                                self.similarityProgress = (processed, total)
                            }
                        }
                    )
                    guard !Task.isCancelled, scanGeneration == generation else { return }
                    similarityGroups = photoGroups
                    skippedSimilarityPreviews = await similarityAnalyzer.skippedPreviewCount
                    currentSimilarityGroupIndex = 0
                    print("[KeptoraScan] Visual similarity done: \(similarityGroups.count) groups")
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    print("[KeptoraScan] Visual similarity error: \(error)")
                    similarityGroups = []
                    similarityError = error.localizedDescription
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
                    let videoGroups = try await videoSimilarityAnalyzer.analyze(
                        assets: videoCandidates,
                        provider: videoProvider,
                        allowNetwork: allowNetwork,
                        progress: { processed, total in
                            Task { @MainActor [weak self] in
                                guard let self, self.scanGeneration == generation else { return }
                                self.videoSimilarityProgress = (processed, total)
                            }
                        }
                    )
                    guard !Task.isCancelled, scanGeneration == generation else { return }
                    similarVideoGroups = videoGroups
                    print("[KeptoraScan] Video similarity done: \(similarVideoGroups.count) groups")
                } catch is CancellationError {
                    throw CancellationError()
                } catch {
                    print("[KeptoraScan] Video similarity error: \(error)")
                    similarVideoGroups = []
                    videoSimilarityError = error.localizedDescription
                }
                videoSimilarityProgress = nil
            } catch is CancellationError {
                guard scanGeneration == generation else { return }
                print("[KeptoraScan] Scan was cancelled")
                scanState = suspendedForBackground ? .paused : .idle
                similarityProgress = nil
                videoSimilarityProgress = nil
            } catch {
                guard scanGeneration == generation else { return }
                print("[KeptoraScan] Scan failed: \(error)")
                scanState = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
    }

    /// True while the similarity passes are still running after the exact scan completed.
    var isAnalyzing: Bool { similarityProgress != nil || videoSimilarityProgress != nil }

    func cancelScan() {
        scanGeneration = UUID()
        scanTask?.cancel()
        scanTask = nil
        scanState = .idle
        similarityProgress = nil
        videoSimilarityProgress = nil
        clearScanCheckpoint()
        UIApplication.shared.isIdleTimerDisabled = false
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
        guard asset.id != group.keeperID, !asset.isProtectedFromGlobalSelection else {
            errorMessage = String(localized: "Use Library to select this item manually. Suggested cleanup keeps it out of bulk selection.")
            return true
        }
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
        guard group.mediaKind == .video else { return true }
        guard asset.id != group.keeperID, !asset.isProtectedFromGlobalSelection else {
            errorMessage = String(localized: "Use Library to select this item manually. Suggested cleanup keeps it out of bulk selection.")
            return true
        }
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
        intent: PhotosRemovalIntent = .suggestedCopies,
        resolveFolderCandidates: () async throws -> [(asset: UniversalMediaAsset, expectedDigest: String)],
        onSuccess: () -> Void
    ) async -> Bool {
        guard !isCleaningUp, !isLoadingCatalogue, !scanState.isScanning, !isAnalyzing else { return false }
        guard !selection.isEmpty else { return false }
        isCleaningUp = true
        cleanupStatus = String(localized: "Reviewing selected items…")
        defer { isCleaningUp = false; cleanupStatus = nil }
        do {
            try LibraryRevisionValidator.validate(selection)
            if case .suggestedCopies = intent { try await verifyUnchanged(selection) }
            var candidates: [(asset: UniversalMediaAsset, expectedDigest: String)] = []
            if selection.contains(where: { if case .file = $0.reference { return true }; return false }) {
                candidates = try await resolveFolderCandidates()
            }
            let batches = Dictionary(grouping: selection, by: \.sourceID)
            // Preflight every folder before the first operation. Photos confirmation
            // runs first so cancelling the system dialog leaves files untouched.
            for (id, batch) in batches where id != LibrarySource.photos.id {
                guard let root = folderScopes[id], await folderCleanup.preflight(root: root),
                      candidates.filter({ $0.asset.sourceID == id }).count == batch.count else {
                    throw UniversalScanError.cleanupNotPermitted("Review the selection again before cleanup.")
                }
            }
            var completedIDs: Set<String> = []
            defer { reconcileRemoved(completedIDs); persistHistory() }
            if let photosBatch = batches[LibrarySource.photos.id] {
                let ids = photosBatch.compactMap { item -> String? in if case .photoLibrary(let id) = item.reference { return id }; return nil }
                guard ids.count == photosBatch.count else { throw UniversalScanError.unsupportedReference }
                try await photosAdapter.deleteSelectedAssets(localIdentifiers: ids, intent: intent)
                history.insert(CleanupHistoryEntry(id: UUID(), kind: .photosRecentlyDeleted, createdAt: Date(), itemCount: photosBatch.count,
                    byteCount: MediaSelectionSummary(photosBatch).knownBytes, folderRecord: nil, restoredAt: nil), at: 0)
                completedIDs.formUnion(photosBatch.map(\.id))
            }
            for connected in connectedFolders {
                guard let batch = batches[connected.id], let root = folderScopes[connected.id] else { continue }
                let record = try await folderCleanup.quarantine(root: root, selections: candidates.filter { $0.asset.sourceID == connected.id })
                history.insert(CleanupHistoryEntry(id: record.id, kind: .folderQuarantine, createdAt: record.createdAt,
                    itemCount: record.operations.count, byteCount: MediaSelectionSummary(batch).knownBytes, folderRecord: record,
                    restoredAt: nil, sourceBookmark: folderBookmarks[connected.id]), at: 0)
                completedIDs.formUnion(batch.map(\.id))
            }
            onSuccess()
            return true
        } catch {
            guard !Self.isUserCancellation(error) else { return false }
            errorMessage = error.localizedDescription
            Task { await loadCatalogue() }
            return false
        }
    }

    private func reconcileRemoved(_ removedIDs: Set<String>) {
        guard !removedIDs.isEmpty else { return }
        exactGroups = exactGroups.compactMap { group in
            let remaining = group.assets.filter { !removedIDs.contains($0.id) }
            guard remaining.count > 1 else { return nil }
            let newKeeper = remaining.contains(where: { $0.id == group.keeperID }) ? group.keeperID : remaining.first?.id ?? ""
            return UniversalExactGroup(digest: group.digest, assets: remaining, keeperID: newKeeper)
        }
        similarVideoGroups = similarVideoGroups.compactMap { group in
            let remaining = group.assets.filter { !removedIDs.contains($0.id) }
            guard remaining.count > 1 else { return nil }
            let newKeeper = remaining.contains(where: { $0.id == group.keeperID }) ? group.keeperID : remaining.first?.id ?? ""
            return UniversalSimilarityGroup(
                id: group.id,
                assets: remaining,
                maximumDistance: group.maximumDistance,
                mediaKind: group.mediaKind,
                keeperID: newKeeper
            )
        }
        similarityGroups = similarityGroups.compactMap { group in
            let remaining = group.assets.filter { !removedIDs.contains($0.id) }
            guard remaining.count > 1 else { return nil }
            return UniversalSimilarityGroup(id: group.id, assets: remaining, maximumDistance: group.maximumDistance)
        }
        assets.removeAll { removedIDs.contains($0.id) }
        selectedLibraryIDs.subtract(removedIDs)
        saveLibrarySelection()
        for id in removedIDs {
            scanFingerprintsByAssetID.removeValue(forKey: id)
        }
        if currentGroupIndex >= exactGroups.count {
            currentGroupIndex = max(0, exactGroups.count - 1)
        }
        if currentSimilarityGroupIndex >= similarVideoGroups.count {
            currentSimilarityGroupIndex = max(0, similarVideoGroups.count - 1)
        }
        selectedAssetIDs.subtract(removedIDs)
        selectedSimilarVideoAssetIDs.subtract(removedIDs)
    }

    @discardableResult
    func cleanupSelection() async -> Bool {
        let selection = selectedSafeAssets
        return await executeCleanup(
            selection: selection,
            resolveFolderCandidates: { [weak self] in
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

    @discardableResult
    func cleanupSimilarVideoSelection() async -> Bool {
        let selection = selectedSimilarVideoAssets
        return await executeCleanup(
            selection: selection,
            resolveFolderCandidates: { [weak self] in
                guard let self else { return [] }
                let candidates = selection.compactMap { asset -> (asset: UniversalMediaAsset, expectedDigest: String)? in
                    guard let digest = self.scanFingerprintsByAssetID[asset.id]?.digest else { return nil }
                    return (asset, digest)
                }
                guard candidates.count == selection.count else {
                    throw UnifiedLibraryError.selectionChanged
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
        guard !isCleaningUp, !isLoadingCatalogue, !scanState.isScanning, !isAnalyzing else { return }
        guard let record = entry.folderRecord else { return }
        isCleaningUp = true; cleanupStatus = String(localized: "Restoring files…")
        defer { isCleaningUp = false; cleanupStatus = nil; Task { await loadCatalogue() } }
        do {
            var recoveryScope: URL?
            if let bookmark = entry.sourceBookmark {
                var stale = false
                let url = try URL(resolvingBookmarkData: bookmark, options: [], relativeTo: nil, bookmarkDataIsStale: &stale)
                if url.startAccessingSecurityScopedResource() { recoveryScope = url }
            }
            defer { recoveryScope?.stopAccessingSecurityScopedResource() }
            let restored = try await folderCleanup.restore(record)
            if let index = history.firstIndex(where: { $0.id == entry.id }) {
                history[index].folderRecord = restored
                history[index].restoredAt = restored.restoredAt
            }
            persistHistory()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteHistory(at offsets: IndexSet) {
        let removable = offsets.filter { index in
            history.indices.contains(index) && (history[index].kind != .folderQuarantine || history[index].restoredAt != nil)
        }
        if removable.count != offsets.count {
            errorMessage = String(localized: "Restore these files before removing their recovery record.")
        }
        history.remove(atOffsets: IndexSet(removable))
        persistHistory()
    }

    private func persistHistory() {
        guard let data = try? JSONEncoder().encode(history) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }

    private func resetResults(clearCheckpoint shouldClearCheckpoint: Bool = true) {
        catalogueTask?.cancel(); catalogueGeneration = UUID(); isLoadingCatalogue = false
        scanGeneration = UUID()
        photoObserver = nil
        manualSelectionIsLoaded = false
        selectedLibraryIDs.removeAll()
        libraryCollectionSortBySize = false
        libraryCollectionKind = nil
        libraryCollectionIDs = nil
        libraryCollectionTitle = nil
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

    nonisolated private func saveScanCheckpoint(_ checkpoint: UniversalScanCheckpoint) {
        guard let data = try? JSONEncoder().encode(checkpoint) else { return }
        if let fileURL = scanCheckpointFileURL {
            try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: fileURL, options: .atomic)
        }
        Task { @MainActor [weak self] in self?.hasScanCheckpoint = true }
    }

    private func loadScanCheckpoint(allowNetwork: Bool) -> UniversalScanCheckpoint? {
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
        let expectedSourceID = scanAdapter.source.id
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
                throw UnifiedLibraryError.selectionChanged
            }
            let fresh = try await unifiedAdapter.exactFingerprint(for: asset, allowNetwork: lastScanAllowedNetwork, progress: { _ in })
            guard fresh == expected else {
                throw UnifiedLibraryError.selectionChanged
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
            pixelHeight: 3024,
            isFavorite: true,
            context: MediaContext(captureDate: Date(timeIntervalSince1970: 1_786_000_000), captureTimeIsReliable: true)
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

private final class MobilePhotoChangeObserver: NSObject, PHPhotoLibraryChangeObserver, @unchecked Sendable {
    private let onChange: @Sendable () -> Void
    init(onChange: @escaping @Sendable () -> Void) {
        self.onChange = onChange
        super.init()
        PHPhotoLibrary.shared().register(self)
    }
    deinit { PHPhotoLibrary.shared().unregisterChangeObserver(self) }
    func photoLibraryDidChange(_ changeInstance: PHChange) { onChange() }
}
