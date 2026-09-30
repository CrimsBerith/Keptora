import KeptoraCore
import AppKit
import Photos
import SwiftUI

@MainActor
private final class MacPhotosLibraryStore: ObservableObject {
    enum Phase: Equatable {
        case idle
        case scanning(Int, Int, String)
        case completed
        case failed(String)

        var isScanning: Bool {
            if case .scanning = self { return true }
            return false
        }
    }

    @Published var authorization: SourceAuthorization = .notDetermined
    @Published var phase: Phase = .idle
    @Published var assets: [UniversalMediaAsset] = []
    @Published var exactGroups: [UniversalExactGroup] = []
    @Published var similarityGroups: [UniversalSimilarityGroup] = []
    @Published var similarVideoGroups: [UniversalSimilarityGroup] = []
    @Published var selectedGroupID: String?
    @Published var selectedSimilarityGroupID: String?
    @Published var selectedAssetIDs: Set<String> = []
    @Published var selectedSimilarVideoAssetIDs: Set<String> = []
    @Published var skippedCloudItems = 0
    @Published var similarityProgress: (Int, Int)?
    @Published var videoSimilarityProgress: (Int, Int)?
    @Published var errorMessage: String?
    @Published var completedPhotosCleanupCount = 0

    private let adapter = PhotoLibrarySourceAdapter()
    private let scanner = UniversalExactScanner()
    private let similarity = VisualSimilarityAnalyzer()
    private let videoSimilarity = VideoSimilarityAnalyzer()
    private var task: Task<Void, Never>?
    private var lastScanAllowedNetwork = false
    private var scanFingerprintsByAssetID: [String: UniversalExactFingerprint] = [:]

    var selectedGroup: UniversalExactGroup? {
        exactGroups.first { $0.id == selectedGroupID } ?? exactGroups.first
    }

    var selectedSimilarityGroup: UniversalSimilarityGroup? {
        similarityGroups.first { $0.id == selectedSimilarityGroupID } ?? similarityGroups.first
    }

    var selectedAssets: [UniversalMediaAsset] {
        exactGroups.flatMap(\.safeCopies).filter { selectedAssetIDs.contains($0.id) }
    }

    var selectedBytes: Int64 { selectedAssets.reduce(0) { $0 + ($1.byteCount ?? 0) } }

    var selectedSimilarVideoAssets: [UniversalMediaAsset] {
        similarVideoGroups.flatMap(\.safeCandidates).filter { selectedSimilarVideoAssetIDs.contains($0.id) }
    }

    var selectedSimilarVideoBytes: Int64 {
        selectedSimilarVideoAssets.reduce(0) { $0 + ($1.byteCount ?? 0) }
    }

    func refreshAuthorization() async {
        authorization = await adapter.authorizationStatus()
    }

    func requestAccess() async {
        authorization = await adapter.authorizationStatus()
        if authorization == .denied {
            openPhotosSettings()
            return
        }
        guard authorization == .notDetermined else { return }
        authorization = await adapter.requestAuthorization()
    }

    func openPhotosSettings() {
        let candidateURLs = [
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos"),
            URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Photos"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security")
        ].compactMap { $0 }
        for url in candidateURLs {
            if NSWorkspace.shared.open(url) { return }
        }
    }

    func scan(allowNetwork: Bool = false) {
        task?.cancel()
        selectedAssetIDs.removeAll()
        selectedSimilarVideoAssetIDs.removeAll()
        lastScanAllowedNetwork = allowNetwork
        task = Task { [weak self] in
            guard let self else { return }
            do {
                let result = try await scanner.scan(
                    adapter: adapter,
                    allowNetwork: allowNetwork,
                    progress: { processed, total, current in
                        Task { @MainActor [weak self] in self?.phase = .scanning(processed, total, current) }
                    }
                )
                assets = result.assets
                exactGroups = result.groups
                scanFingerprintsByAssetID = result.fingerprintsByAssetID
                skippedCloudItems = result.skippedNetwork
                selectedGroupID = result.groups.first?.id
                phase = .completed
                similarityProgress = (0, result.assets.filter { $0.mediaKind == .image }.count)
                similarityGroups = try await similarity.analyze(
                    assets: result.assets,
                    provider: adapter,
                    allowNetwork: allowNetwork,
                    progress: { processed, total in
                        Task { @MainActor [weak self] in self?.similarityProgress = (processed, total) }
                    }
                )
                selectedSimilarityGroupID = similarityGroups.first?.id
                similarityProgress = nil
                let exactCopyIDs = Set(result.groups.flatMap { group in
                    group.assets.filter { $0.id != group.keeperID }.map(\.id)
                })
                let videoCandidates = result.assets
                    .filter { $0.mediaKind == .video && !exactCopyIDs.contains($0.id) }
                    .map { self.withScannedByteCount($0) }
                videoSimilarityProgress = (0, videoCandidates.count)
                similarVideoGroups = try await videoSimilarity.analyze(
                    assets: videoCandidates,
                    provider: adapter,
                    allowNetwork: allowNetwork,
                    progress: { processed, total in
                        Task { @MainActor [weak self] in self?.videoSimilarityProgress = (processed, total) }
                    }
                )
                videoSimilarityProgress = nil
            } catch is CancellationError {
                phase = .idle
                similarityProgress = nil
            } catch {
                phase = .failed(error.localizedDescription)
                errorMessage = error.localizedDescription
            }
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
        phase = .idle
    }

    func selectAllSafeCopies() {
        guard let selectedGroup else { return }
        selectedAssetIDs.formUnion(selectedGroup.safeCopies.map(\.id))
    }

    func selectAllSafeCopies(in group: UniversalExactGroup) {
        selectedAssetIDs.formUnion(group.safeCopies.map(\.id))
    }

    func selectAllSafeCopies(in groups: [UniversalExactGroup]) {
        selectedAssetIDs.formUnion(groups.flatMap(\.safeCopies).map(\.id))
    }

    func clearExactSelection() {
        selectedAssetIDs.removeAll()
    }

    func toggle(_ asset: UniversalMediaAsset, in group: UniversalExactGroup) {
        guard asset.id != group.keeperID, !asset.isProtectedFromGlobalSelection else { return }
        if !selectedAssetIDs.insert(asset.id).inserted { selectedAssetIDs.remove(asset.id) }
    }

    func selectAllSafeSimilarVideos(in groups: [UniversalSimilarityGroup]) {
        selectedSimilarVideoAssetIDs.formUnion(groups.flatMap(\.safeCandidates).map(\.id))
    }

    func clearSimilarVideoSelection() {
        selectedSimilarVideoAssetIDs.removeAll()
    }

    func toggleSimilarVideo(_ asset: UniversalMediaAsset, in group: UniversalSimilarityGroup) {
        guard group.mediaKind == .video,
              asset.id != group.keeperID,
              !asset.isProtectedFromGlobalSelection else { return }
        if !selectedSimilarVideoAssetIDs.insert(asset.id).inserted {
            selectedSimilarVideoAssetIDs.remove(asset.id)
        }
    }

    func removeSelectedFromPhotos() async {
        let selection = selectedAssets
        guard !selection.isEmpty else { return }
        do {
            let digestByAsset = Dictionary(exactGroups.flatMap { group in
                group.assets.map { ($0.id, group.digest) }
            }, uniquingKeysWith: { first, _ in first })
            for asset in selection {
                let fresh = try await adapter.exactFingerprint(
                    for: asset,
                    allowNetwork: lastScanAllowedNetwork,
                    progress: { _ in }
                )
                guard fresh.digest == digestByAsset[asset.id] else {
                    throw UniversalScanError.cleanupNotPermitted("A selected Photos item changed after review. Scan again before cleanup.")
                }
            }
            let identifiers = selection.compactMap { asset -> String? in
                guard case .photoLibrary(let identifier) = asset.reference else { return nil }
                return identifier
            }
            try await adapter.deleteExactAssets(localIdentifiers: identifiers)
            completedPhotosCleanupCount = selection.count
            selectedAssetIDs.removeAll()
            scan(allowNetwork: lastScanAllowedNetwork)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeSelectedSimilarVideosFromPhotos() async {
        let selection = selectedSimilarVideoAssets
        guard !selection.isEmpty else { return }
        do {
            for asset in selection {
                guard let expected = scanFingerprintsByAssetID[asset.id] else {
                    throw UniversalScanError.cleanupNotPermitted("A video could not be reverified. Scan again before cleanup.")
                }
                let fresh = try await adapter.exactFingerprint(
                    for: asset,
                    allowNetwork: lastScanAllowedNetwork,
                    progress: { _ in }
                )
                guard fresh == expected else {
                    throw UniversalScanError.cleanupNotPermitted("A selected video changed after review. Scan again before cleanup.")
                }
            }
            let identifiers = selection.compactMap { asset -> String? in
                guard case .photoLibrary(let identifier) = asset.reference else { return nil }
                return identifier
            }
            try await adapter.deleteSelectedAssets(localIdentifiers: identifiers)
            completedPhotosCleanupCount = selection.count
            selectedSimilarVideoAssetIDs.removeAll()
            scan(allowNetwork: lastScanAllowedNetwork)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func withScannedByteCount(_ asset: UniversalMediaAsset) -> UniversalMediaAsset {
        guard let fingerprint = scanFingerprintsByAssetID[asset.id] else { return asset }
        return UniversalMediaAsset(
            id: asset.id,
            sourceID: asset.sourceID,
            reference: asset.reference,
            displayName: asset.displayName,
            mediaKind: asset.mediaKind,
            byteCount: fingerprint.byteCount,
            pixelWidth: asset.pixelWidth,
            pixelHeight: asset.pixelHeight,
            duration: asset.duration,
            creationDate: asset.creationDate,
            modificationDate: asset.modificationDate,
            isFavorite: asset.isFavorite,
            isHidden: asset.isHidden,
            hasAdjustments: asset.hasAdjustments,
            isSharedLibraryAsset: asset.isSharedLibraryAsset,
            hasAlbumMembership: asset.hasAlbumMembership,
            requiresNetwork: asset.requiresNetwork
        )
    }
}

struct MacPhotosLibraryView: View {
    private enum Mode: Hashable { case exact, similar }
    private enum Media: Hashable { case photos, videos }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var entitlement: StoreEntitlementController
    @StateObject private var photos = MacPhotosLibraryStore()
    @State private var mode: Mode = .exact
    @State private var media: Media = .photos
    @State private var showNetworkConfirmation = false
    @State private var showCleanupConfirmation = false

    private var filteredExactGroups: [UniversalExactGroup] {
        photos.exactGroups.filter { $0.assets.first?.mediaKind == (media == .photos ? .image : .video) }
    }
    private var selectedExactGroup: UniversalExactGroup? {
        filteredExactGroups.first { $0.id == photos.selectedGroupID } ?? filteredExactGroups.first
    }
    private var filteredSimilarityGroups: [UniversalSimilarityGroup] {
        media == .photos ? photos.similarityGroups : photos.similarVideoGroups
    }
    private var selectedSimilarityGroup: UniversalSimilarityGroup? {
        filteredSimilarityGroups.first { $0.id == photos.selectedSimilarityGroupID } ?? filteredSimilarityGroups.first
    }
    private var isSimilarVideoMode: Bool { mode == .similar && media == .videos }
    private var cleanupCount: Int {
        isSimilarVideoMode ? photos.selectedSimilarVideoAssetIDs.count : photos.selectedAssetIDs.count
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 900, idealWidth: 1080, minHeight: 650, idealHeight: 760)
        .task { await photos.refreshAuthorization() }
        .keptoraOnChange(of: media) {
            photos.selectedGroupID = filteredExactGroups.first?.id
            photos.selectedSimilarityGroupID = filteredSimilarityGroups.first?.id
            photos.selectedAssetIDs.removeAll()
            photos.selectedSimilarVideoAssetIDs.removeAll()
        }
        .keptoraOnChange(of: scenePhase) { phase in
            if phase == .active { Task { await photos.refreshAuthorization() } }
        }
        .alert("Photos cleanup completed", isPresented: Binding(
            get: { photos.completedPhotosCleanupCount > 0 },
            set: { if !$0 { photos.completedPhotosCleanupCount = 0 } }
        )) {
            Button("OK", role: .cancel) { photos.completedPhotosCleanupCount = 0 }
        } message: {
            Text("Recover removed items from Recently Deleted in Apple Photos. With iCloud Photos, recovery syncs across your devices.")
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { photos.errorMessage != nil },
            set: { if !$0 { photos.errorMessage = nil } }
        )) { Button("OK", role: .cancel) { photos.errorMessage = nil } } message: {
            Text(photos.errorMessage ?? "")
        }
        .confirmationDialog("Download iCloud originals?", isPresented: $showNetworkConfirmation) {
            Button("Download and Scan") { photos.scan(allowNetwork: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This may use network data and disk space. You can cancel between Photos items.")
        }
        .confirmationDialog(isSimilarVideoMode ? "Remove selected similar videos from Photos?" : "Remove exact copies from Photos?", isPresented: $showCleanupConfirmation) {
            Button("Remove from Photos", role: .destructive) {
                let assetIDs = (isSimilarVideoMode ? photos.selectedSimilarVideoAssetIDs : photos.selectedAssetIDs).map { AssetID(rawValue: $0) }
                Task {
                    if isSimilarVideoMode { await photos.removeSelectedSimilarVideosFromPhotos() }
                    else { await photos.removeSelectedFromPhotos() }
                    entitlement.recordReviews(assetIDs)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if isSimilarVideoMode {
                Text("\(cleanupCount.formatted()) manually reviewed similar videos will move to Recently Deleted. The keeper stays protected. With iCloud Photos, removal syncs to your other devices.")
            } else {
                Text("\(cleanupCount.formatted()) verified exact copies will move to Recently Deleted. The keeper stays protected. With iCloud Photos, removal syncs to your other devices.")
            }
        }
    }

    private var header: some View {
        HStack(spacing: 14) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.title2).foregroundStyle(KeptoraDesign.accent)
                .frame(width: 42, height: 42)
                .background(KeptoraDesign.accentSubtle, in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text("Apple Photos").font(.title2.bold())
                Text("Exact photos and videos are verified byte for byte. Similar videos require manual review.")
                    .font(.callout).foregroundStyle(.secondary)
            }
            Spacer()
            if photos.authorization == .authorized || photos.authorization == .limited {
                scanControls
            } else if photos.authorization == .denied {
                Button("Open System Settings") { photos.openPhotosSettings() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Allow Photos Access") { Task { await photos.requestAccess() } }
                    .buttonStyle(.borderedProminent)
            }
            KeptoraSheetCloseButton(
                accessibilityLabel: "Close Apple Photos screen",
                accessibilityIdentifier: "mac.photos.close",
                action: { dismiss() }
            )
        }
        .padding(18)
    }

    @ViewBuilder
    private var scanControls: some View {
        if case .scanning = photos.phase {
            Button("Cancel") { photos.cancel() }
        } else {
            Button("Scan Photos") { photos.scan() }
                .buttonStyle(.borderedProminent)
            if photos.skippedCloudItems > 0 {
                Button("Scan iCloud Originals") { showNetworkConfirmation = true }
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if photos.authorization == .denied || photos.authorization == .restricted {
            MacPhotosEmptyState(
                title: photos.authorization == .restricted ? "Photos access is restricted" : "Photos access is off",
                detail: photos.authorization == .restricted
                    ? "Your Mac or organization profile restricts access to Apple Photos."
                    : "To find exact duplicates in your Photo Library, turn on Photos access in System Settings > Privacy & Security > Photos.",
                systemImage: "photo.badge.exclamationmark",
                actionTitle: photos.authorization == .denied ? "Open Privacy Settings…" : nil,
                action: photos.authorization == .denied ? { photos.openPhotosSettings() } : nil
            )
        } else if photos.authorization == .notDetermined {
            MacPhotosEmptyState(title: "Choose Apple Photos", detail: "Keptora asks only when you choose this source.", systemImage: "photo.stack")
        } else if case .scanning(let processed, let total, let current) = photos.phase {
            VStack(spacing: 12) {
                ProgressView(value: Double(processed), total: Double(max(total, 1))).frame(maxWidth: 460)
                Text("Scanning \(processed.formatted()) of \(total.formatted())")
                    .font(.headline.monospacedDigit())
                Text(current).foregroundStyle(.secondary).lineLimit(1)
            }
        } else if photos.assets.isEmpty {
            MacPhotosEmptyState(title: "Ready to scan Photos", detail: "iCloud-only originals remain untouched until you approve a network scan.", systemImage: "sparkle.magnifyingglass")
        } else {
            VStack(spacing: 0) {
                Picker("Review mode", selection: $mode) {
                    Text("Exact copies").tag(Mode.exact)
                    Text("Similar").tag(Mode.similar)
                }
                .pickerStyle(.segmented).frame(width: 250).padding(.top, 12)
                Picker("Media type", selection: $media) {
                    Label("Photos", systemImage: "photo").tag(Media.photos)
                    Label("Videos", systemImage: "video").tag(Media.videos)
                }
                .pickerStyle(.segmented).frame(width: 250).padding(.vertical, 10)
                Divider()
                if mode == .exact { exactWorkspace } else { similarityWorkspace }
            }
        }
    }

    private var exactWorkspace: some View {
        NavigationSplitView {
            List(filteredExactGroups, selection: $photos.selectedGroupID) { group in
                VStack(alignment: .leading, spacing: 3) {
                    Text(String(format: String(localized: "%@ exact copies"), group.assets.count.formatted())).font(.headline)
                    Text(ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file))
                        .font(.caption).foregroundStyle(.secondary)
                }.tag(group.id)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            if let group = selectedExactGroup {
                VStack(spacing: 0) {
                    HStack {
                        Label("SHA-256 verified", systemImage: "checkmark.seal.fill").foregroundStyle(.green)
                        Spacer()
                        if !photos.selectedAssetIDs.isEmpty {
                            Label(String(format: String(localized: "%@ selected"), photos.selectedAssetIDs.count.formatted()), systemImage: "checkmark.square.fill")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(KeptoraDesign.accent)
                            Button("Clear Selection") { photos.clearExactSelection() }
                                .accessibilityIdentifier("mac.photos.exact.clearSelection")
                        }
                        Button("Select This Group") {
                            photos.selectAllSafeCopies(in: group)
                        }
                        .accessibilityIdentifier("mac.photos.exact.selectGroup")
                        if media == .videos {
                            Button("Select All Safe Videos") {
                                photos.selectAllSafeCopies(in: filteredExactGroups)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("mac.photos.exact.selectAll")
                        } else {
                            Button("Select All Safe Photos") {
                                photos.selectAllSafeCopies(in: filteredExactGroups)
                            }
                            .buttonStyle(.borderedProminent)
                            .accessibilityIdentifier("mac.photos.exact.selectAll")
                        }
                        Button("Remove from Photos") {
                            let assetIDs = photos.selectedAssetIDs.map { AssetID(rawValue: $0) }
                            if entitlement.authorizeSafetyPlan(assetIDs: assetIDs) {
                                showCleanupConfirmation = true
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(photos.selectedAssetIDs.isEmpty)
                    }.padding(14)
                    Divider()
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
                            ForEach(group.assets) { asset in
                                MacPhotosAssetCard(asset: asset, group: group) { photos.toggle(asset, in: group) }
                                    .environmentObject(photos)
                            }
                        }.padding(16)
                    }
                }
            } else {
                MacPhotosEmptyState(title: "No exact copies", detail: "No byte-for-byte Photos copies were found.", systemImage: "checkmark.seal")
            }
        }
    }

    private var similarityWorkspace: some View {
        NavigationSplitView {
            List(filteredSimilarityGroups, selection: $photos.selectedSimilarityGroupID) { group in
                Label(
                    String(format: String(localized: "%1$@ %2$@"), group.assets.count.formatted(), media == .videos ? String(localized: "similar videos") : String(localized: "similar photos")),
                    systemImage: media == .videos ? "video.stack" : "sparkles.rectangle.stack"
                )
                    .tag(group.id)
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            if let group = selectedSimilarityGroup {
                VStack(spacing: 0) {
                    HStack {
                        Label(
                            media == .videos ? "Visual suggestion · manual selection only" : "Review-only · no cleanup actions",
                            systemImage: "eye"
                        )
                        .font(.headline)
                        Spacer()
                        if media == .videos {
                            if !photos.selectedSimilarVideoAssetIDs.isEmpty {
                                Label(String(format: String(localized: "%@ selected"), photos.selectedSimilarVideoAssetIDs.count.formatted()), systemImage: "checkmark.square.fill")
                                    .font(.callout.weight(.semibold))
                                    .foregroundStyle(KeptoraDesign.accent)
                                Button("Clear Selection") { photos.clearSimilarVideoSelection() }
                                    .accessibilityIdentifier("mac.photos.similarVideo.clearSelection")
                            }
                            Button("Select This Group") {
                                photos.selectAllSafeSimilarVideos(in: [group])
                            }
                            .accessibilityIdentifier("mac.photos.similarVideo.selectGroup")
                            Button("Select All Safe Videos") {
                                photos.selectAllSafeSimilarVideos(in: filteredSimilarityGroups)
                            }
                            .accessibilityIdentifier("mac.photos.similarVideo.selectAll")
                            Button("Remove from Photos") {
                                let assetIDs = photos.selectedSimilarVideoAssetIDs.map { AssetID(rawValue: $0) }
                                if entitlement.authorizeSafetyPlan(assetIDs: assetIDs) {
                                    showCleanupConfirmation = true
                                }
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(photos.selectedSimilarVideoAssetIDs.isEmpty)
                        }
                    }
                    .padding(14)
                    Divider()
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 240), spacing: 14)], spacing: 14) {
                            ForEach(group.assets) { asset in
                                if media == .videos {
                                    MacSimilarVideoCard(asset: asset, group: group) {
                                        photos.toggleSimilarVideo(asset, in: group)
                                    }
                                    .environmentObject(photos)
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        MacPhotosThumbnail(asset: asset).frame(height: 220).clipShape(RoundedRectangle(cornerRadius: 14))
                                        Text(asset.displayName).font(.headline).lineLimit(1)
                                    }.padding(10).background(KeptoraDesign.quiet, in: RoundedRectangle(cornerRadius: 16))
                                }
                            }
                        }.padding(16)
                    }
                }
            } else {
                MacPhotosEmptyState(
                    title: media == .videos ? "No similar videos" : "No similar photos",
                    detail: "No visual review suggestions were found for this media type.",
                    systemImage: media == .videos ? "video.badge.checkmark" : "sparkles.rectangle.stack"
                )
            }
        }
    }
}

private struct MacPhotosAssetCard: View {
    @EnvironmentObject private var photos: MacPhotosLibraryStore
    let asset: UniversalMediaAsset
    let group: UniversalExactGroup
    let action: () -> Void

    private var isKeeper: Bool { asset.id == group.keeperID }
    private var selected: Bool { photos.selectedAssetIDs.contains(asset.id) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                MacPhotosThumbnail(asset: asset)
                    .frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 13))
                Text(asset.displayName).font(.headline).lineLimit(1)
                if isKeeper {
                    Text("Protected keeper")
                        .font(.caption).foregroundStyle(.green)
                } else if asset.isProtectedFromGlobalSelection {
                    Text("Protected metadata")
                        .font(.caption).foregroundStyle(.green)
                } else {
                    Text("Exact copy")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .padding(10).background(KeptoraDesign.quiet, in: RoundedRectangle(cornerRadius: 16))
            .overlay { RoundedRectangle(cornerRadius: 16).stroke(selected ? KeptoraDesign.accent : Color.primary.opacity(0.06), lineWidth: selected ? 2 : 1) }
        }
        .buttonStyle(.plain)
        .disabled(isKeeper || asset.isProtectedFromGlobalSelection)
        .accessibilityLabel("\(asset.displayName), \(isKeeper ? "protected keeper" : "exact copy")")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .overlay(alignment: .topTrailing) {
            Button(action: action) {
                Image(systemName: isKeeper || asset.isProtectedFromGlobalSelection ? "lock.shield.fill" : (selected ? "checkmark.square.fill" : "square"))
                    .font(.title2)
                    .foregroundStyle(isKeeper || asset.isProtectedFromGlobalSelection ? .green : (selected ? KeptoraDesign.accent : .primary))
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isKeeper || asset.isProtectedFromGlobalSelection)
            .padding(8)
            .accessibilityLabel(selected ? "Deselect \(asset.displayName)" : "Select \(asset.displayName)")
            .accessibilityIdentifier("mac.photos.exact.checkbox.\(asset.id)")
        }
    }
}

private struct MacSimilarVideoCard: View {
    @EnvironmentObject private var photos: MacPhotosLibraryStore
    let asset: UniversalMediaAsset
    let group: UniversalSimilarityGroup
    let action: () -> Void

    private var isKeeper: Bool { asset.id == group.keeperID }
    private var isProtected: Bool { asset.isProtectedFromGlobalSelection }
    private var selected: Bool { photos.selectedSimilarVideoAssetIDs.contains(asset.id) }

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                MacPhotosThumbnail(asset: asset)
                    .frame(height: 220)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(alignment: .bottomLeading) {
                        Label(asset.formattedDuration, systemImage: "play.fill")
                            .font(.caption.bold()).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 5)
                            .background(.black.opacity(0.66), in: Capsule())
                            .padding(9)
                    }
                Text(asset.displayName).font(.headline).lineLimit(1)
                HStack {
                    Text(asset.byteCount.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—")
                    Spacer()
                    if isKeeper {
                        Text("Protected keeper")
                            .font(.caption).foregroundStyle(.green)
                    } else if isProtected {
                        Text("Protected metadata")
                            .font(.caption).foregroundStyle(.green)
                    } else {
                        Text("Review candidate")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(10)
            .background(KeptoraDesign.quiet, in: RoundedRectangle(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(selected ? KeptoraDesign.accent : Color.primary.opacity(0.06), lineWidth: selected ? 2 : 1)
            }
        }
        .buttonStyle(.plain)
        .disabled(isKeeper || isProtected)
        .accessibilityAddTraits(selected ? .isSelected : [])
        .overlay(alignment: .topTrailing) {
            Button(action: action) {
                Image(systemName: isKeeper || isProtected ? "lock.shield.fill" : (selected ? "checkmark.square.fill" : "square"))
                    .font(.title2)
                    .foregroundStyle(isKeeper || isProtected ? .green : (selected ? KeptoraDesign.accent : .primary))
                    .padding(8)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isKeeper || isProtected)
            .padding(8)
            .accessibilityLabel(selected ? "Deselect \(asset.displayName)" : "Select \(asset.displayName)")
            .accessibilityIdentifier("mac.photos.similarVideo.checkbox.\(asset.id)")
        }
    }
}

private struct MacPhotosThumbnail: View {
    let asset: UniversalMediaAsset
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Color.secondary.opacity(0.10)
            if let image { Image(nsImage: image).resizable().scaledToFill() }
            else { Image(systemName: asset.mediaKind == .video ? "video.fill" : "photo").font(.largeTitle).foregroundStyle(.secondary) }
        }
        .clipped()
        .task(id: asset.id) { await load() }
    }

    private func load() async {
        guard case .photoLibrary(let identifier) = asset.reference,
              let photo = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil).firstObject else { return }
        image = await withCheckedContinuation { continuation in
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isNetworkAccessAllowed = false
            PHImageManager.default().requestImage(
                for: photo,
                targetSize: NSSize(width: 600, height: 600),
                contentMode: .aspectFill,
                options: options
            ) { image, _ in continuation.resume(returning: image) }
        }
    }
}

private extension UniversalMediaAsset {
    var formattedDuration: String {
        let value = max(0, Int((duration ?? 0).rounded()))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}

private struct MacPhotosEmptyState: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey
    let systemImage: String
    var actionTitle: LocalizedStringKey? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage).font(.system(size: 42)).foregroundStyle(.secondary)
            Text(title).font(.title2.bold())
            Text(detail).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
            }
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
