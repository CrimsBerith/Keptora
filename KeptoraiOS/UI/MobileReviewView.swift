import KeptoraCore
import SwiftUI

struct MobileReviewView: View {
    private enum Mode: Hashable { case exact, similar }
    private enum Media: Hashable { case photos, videos }

    @EnvironmentObject private var store: MobileKeptoraStore
    @EnvironmentObject private var purchase: MobilePurchaseController
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var mode: Mode = .exact
    @State private var media: Media = .photos
    @State private var exactPage = 0
    @State private var similarPhotoPage = 0
    @State private var similarVideoPage = 0
    @State private var showCleanupConfirmation = false
    @State private var showPostCleanupNotice = false
    @State private var showClearSelectionConfirmation = false

    private var filteredExactGroups: [UniversalExactGroup] {
        store.exactGroups.filter { $0.assets.first?.mediaKind == (media == .photos ? .image : .video) }
    }

    private var isSimilarVideoMode: Bool { mode == .similar && media == .videos }
    private var selectedCount: Int {
        isSimilarVideoMode ? store.selectedSimilarVideoAssetIDs.count : store.selectedAssetIDs.count
    }
    private var selectedBytes: Int64 {
        isSimilarVideoMode ? store.selectedSimilarVideoBytes : store.selectedBytes
    }

    var body: some View {
        ZStack {
            MobileAuroraBackground()
            Group {
                if store.assets.isEmpty && (store.scanState.isScanning || store.isAnalyzing) {
                    VStack(spacing: 16) {
                        ProgressView()
                            .scaleEffect(1.2)
                            .tint(MobileKeptoraDesign.cyan)
                        if store.isAnalyzing {
                            Text("Analyzing similar items…")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.primary)
                        } else {
                            Text("Scanning library…")
                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        Text("Your review items will appear as soon as scanning finishes.")
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if store.assets.isEmpty {
                    ContentUnavailableView {
                        Label("Nothing to review yet", systemImage: "photo.stack")
                    } description: {
                        Text("Choose Apple Photos or a folder to find duplicates and declutter your library.")
                    } actions: {
                        Button {
                            store.selectedTab = .library
                        } label: {
                            Text("Go to Library")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MobileKeptoraDesign.accent)
                        .controlSize(.large)
                    }
                } else {
                    VStack(spacing: 6) {
                        Group {
                            if verticalSizeClass == .compact {
                                HStack(spacing: 10) {
                                    reviewModePicker
                                    mediaTypePicker
                                }
                            } else {
                                VStack(spacing: 8) {
                                    reviewModePicker
                                    mediaTypePicker
                                }
                            }
                        }
                        .padding(10)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .stroke(MobileKeptoraDesign.accent.opacity(0.18), lineWidth: 1)
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 6)

                        visibleSelectionActions
                        if mode == .exact { exactReview } else { similarReview }
                    }
                }
            }
        }
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: media) { _, _ in
            exactPage = 0
            similarPhotoPage = 0
            similarVideoPage = 0
        }
        .onChange(of: filteredExactGroups.map(\.id)) { _, ids in
            if exactPage >= ids.count {
                exactPage = max(0, ids.count - 1)
            }
        }
        .onChange(of: store.similarityGroups.map(\.id)) { _, ids in
            if similarPhotoPage >= ids.count {
                similarPhotoPage = max(0, ids.count - 1)
            }
        }
        .onChange(of: store.similarVideoGroups.map(\.id)) { _, ids in
            if similarVideoPage >= ids.count {
                similarVideoPage = max(0, ids.count - 1)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if selectedCount > 0 && (mode == .exact || isSimilarVideoMode) { cleanupBar }
        }
        .alert(
            cleanupTitle,
            isPresented: $showCleanupConfirmation
        ) {
            Button(cleanupButtonTitle, role: .destructive) {
                Task {
                    let success: Bool
                    if isSimilarVideoMode { success = await store.cleanupSimilarVideoSelection() }
                    else { success = await store.cleanupSelection() }
                    if success {
                        showPostCleanupNotice = true
                    }
                }
            }
            .accessibilityIdentifier("ios.cleanup.confirm")
            Button("Keep Reviewing", role: .cancel) {}
                .accessibilityIdentifier("ios.cleanup.cancel")
        } message: {
            Text(cleanupMessage)
        }
        .confirmationDialog(
            "Cleanup Completed",
            isPresented: $showPostCleanupNotice,
            titleVisibility: .visible
        ) {
            Button("View in History") {
                store.selectedTab = .history
            }
            Button("Done", role: .cancel) {}
        } message: {
            Text("Selected items moved safely to Recently Deleted and are restorable at any time.")
        }
        .confirmationDialog(
            String(format: String(localized: "Clear all %lld selections?"), Int64(selectedCount)),
            isPresented: $showClearSelectionConfirmation,
            titleVisibility: .visible
        ) {
            Button("Clear All Selections", role: .destructive) {
                if isSimilarVideoMode { store.clearSimilarVideoSelection() }
                else { store.clearExactSelection() }
            }
            Button("Keep Selections", role: .cancel) {}
        } message: {
            Text("This will deselect all currently chosen photos across all groups.")
        }
    }

    private var reviewModePicker: some View {
        Picker("Review mode", selection: $mode) {
            Text("Exact copies").tag(Mode.exact)
            Text("Similar").tag(Mode.similar)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("ios.review.mode")
    }

    private var mediaTypePicker: some View {
        Picker("Media type", selection: $media) {
            Label("Photos", systemImage: "photo").tag(Media.photos)
            Label("Videos", systemImage: "video").tag(Media.videos)
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("ios.review.media")
    }

    // MARK: – Visible Selection Actions

    @ViewBuilder
    private var visibleSelectionActions: some View {
        if mode == .exact, !filteredExactGroups.isEmpty {
            selectionActionScroller {
                Button {
                    let candidates = filteredExactGroups.flatMap(\.safeCopies)
                    if !store.selectAssets(candidates, isUnlocked: purchase.isUnlocked) {
                        store.present(.paywall)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        if media == .videos {
                            Text("Select All Safe Videos")
                        } else {
                            Text("Select All Safe Photos")
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MobileKeptoraDesign.violet)
                .controlSize(.regular)
                .accessibilityIdentifier("review.exact.selectAll")

                Button {
                    let group = filteredExactGroups.indices.contains(exactPage) ? filteredExactGroups[exactPage] : filteredExactGroups.first
                    if !store.selectAllSafeCopies(in: group, isUnlocked: purchase.isUnlocked) {
                        store.present(.paywall)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.dashed")
                        Text("Select Safe Copies in This Set")
                    }
                }
                .buttonStyle(.bordered)
                .tint(MobileKeptoraDesign.accent)
                .controlSize(.regular)
                .accessibilityIdentifier("review.exact.selectGroup")
            }
        } else if isSimilarVideoMode, !store.similarVideoGroups.isEmpty {
            selectionActionScroller {
                Button {
                    if !store.selectAllSafeSimilarVideos(isUnlocked: purchase.isUnlocked) {
                        store.present(.paywall)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                        Text("Select All Safe Videos")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(MobileKeptoraDesign.violet)
                .controlSize(.regular)
                .accessibilityIdentifier("review.similarVideo.selectAll")

                Button {
                    let group = store.similarVideoGroups.indices.contains(similarVideoPage) ? store.similarVideoGroups[similarVideoPage] : store.similarVideoGroups.first
                    if !store.selectAllSafeSimilarVideos(in: group, isUnlocked: purchase.isUnlocked) {
                        store.present(.paywall)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "square.dashed")
                        Text("Select Safe Videos in This Group")
                    }
                }
                .buttonStyle(.bordered)
                .tint(MobileKeptoraDesign.cyan)
                .controlSize(.regular)
                .accessibilityIdentifier("review.similarVideo.selectGroup")
            }
        }
    }

    private func selectionActionScroller<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 9) { content() }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
        }
        .accessibilityElement(children: .contain)
    }

    // MARK: – Exact Review Pages

    private var exactReview: some View {
        Group {
            if filteredExactGroups.isEmpty {
                ContentUnavailableView(
                    media == .videos ? "No exact videos" : "No exact photos",
                    systemImage: "checkmark.seal",
                    description: Text("Keptora did not find byte-for-byte copies for this media type.")
                )
            } else {
                GroupPager(items: filteredExactGroups, selection: $exactPage) { index, group in
                    ExactGroupPage(
                        group: group,
                        pageIndex: index,
                        totalPages: filteredExactGroups.count,
                        onPrevious: { if exactPage > 0 { if reduceMotion { exactPage -= 1 } else { withAnimation { exactPage -= 1 } } } },
                        onNext: { if exactPage < filteredExactGroups.count - 1 { if reduceMotion { exactPage += 1 } else { withAnimation { exactPage += 1 } } } },
                        onJumpTo: { target in if reduceMotion { exactPage = target } else { withAnimation { exactPage = target } } }
                    )
                }
            }
        }
    }

    // MARK: – Similar Review Pages

    private var similarReview: some View {
        Group {
            if media == .videos { similarVideoReview }
            else if let progress = store.similarityProgress {
                VStack(spacing: 16) {
                    ProgressView(value: Double(progress.processed), total: Double(max(progress.total, 1)))
                        .tint(MobileKeptoraDesign.cyan)
                    Text("Finding visually similar photos…")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                    Text("Review-only. Similarity never enables cleanup.")
                        .font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
                }
                .padding(28)
            } else if store.similarityGroups.isEmpty {
                ContentUnavailableView {
                    Label("No similar groups", systemImage: "sparkles.rectangle.stack")
                } description: {
                    Text("Visual suggestions are kept separate from exact cleanup and can never be selected for removal.")
                }
            } else {
                GroupPager(items: store.similarityGroups, selection: $similarPhotoPage) { index, group in
                    SimilarityGroupPage(
                        group: group,
                        pageIndex: index,
                        totalPages: store.similarityGroups.count,
                        onPrevious: { if similarPhotoPage > 0 { if reduceMotion { similarPhotoPage -= 1 } else { withAnimation { similarPhotoPage -= 1 } } } },
                        onNext: { if similarPhotoPage < store.similarityGroups.count - 1 { if reduceMotion { similarPhotoPage += 1 } else { withAnimation { similarPhotoPage += 1 } } } }
                    )
                }
            }
        }
    }

    private var similarVideoReview: some View {
        Group {
            if let progress = store.videoSimilarityProgress {
                VStack(spacing: 16) {
                    ProgressView(value: Double(progress.processed), total: Double(max(progress.total, 1)))
                        .tint(MobileKeptoraDesign.cyan)
                    Text("Finding visually similar videos…")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                    Text("Suggestions use sampled frames. Review every video before cleanup.")
                        .font(.system(.subheadline, design: .rounded)).foregroundStyle(.secondary)
                }
                .padding(28)
            } else if store.similarVideoGroups.isEmpty {
                ContentUnavailableView {
                    Label("No similar videos", systemImage: "video.badge.checkmark")
                } description: {
                    Text("Keptora did not find videos with matching duration, shape, and sampled frames.")
                }
            } else {
                GroupPager(items: store.similarVideoGroups, selection: $similarVideoPage) { index, group in
                    SimilarVideoGroupPage(
                        group: group,
                        pageIndex: index,
                        totalPages: store.similarVideoGroups.count,
                        onPrevious: { if similarVideoPage > 0 { if reduceMotion { similarVideoPage -= 1 } else { withAnimation { similarVideoPage -= 1 } } } },
                        onNext: { if similarVideoPage < store.similarVideoGroups.count - 1 { if reduceMotion { similarVideoPage += 1 } else { withAnimation { similarVideoPage += 1 } } } },
                        onJumpTo: { target in if reduceMotion { similarVideoPage = target } else { withAnimation { similarVideoPage = target } } }
                    )
                }
            }
        }
    }

    // MARK: – Bottom Floating Cleanup Bar

    private var cleanupBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(selectedCount.formatted()) selected")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                        .contentTransition(.numericText())
                    HStack(spacing: 5) {
                        Text(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))
                            .font(.system(.caption, design: .rounded).weight(.medium))
                            .foregroundStyle(.secondary)
                        Text("•")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                            Text("Restorable")
                        }
                        .font(.system(.caption2, design: .rounded).weight(.semibold))
                        .foregroundStyle(MobileKeptoraDesign.mint)
                    }
                }
                Spacer()
                Button {
                    if selectedCount > 1 {
                        showClearSelectionConfirmation = true
                    } else {
                        if isSimilarVideoMode { store.clearSimilarVideoSelection() }
                        else { store.clearExactSelection() }
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear Selection")
                .accessibilityIdentifier(isSimilarVideoMode ? "review.similarVideo.clearSelection" : "review.exact.clearSelection")

                Button("Review Cleanup") { showCleanupConfirmation = true }
                    .buttonStyle(MobilePrimaryButtonStyle())
                    .accessibilityIdentifier("ios.cleanup.review")
            }
            VStack(spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedCount.formatted()) selected")
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .contentTransition(.numericText())
                        HStack(spacing: 5) {
                            Text(ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file))
                                .font(.system(.caption, design: .rounded).weight(.medium))
                                .foregroundStyle(.secondary)
                            Text("•")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.uturn.backward.circle.fill")
                                Text("Restorable")
                            }
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                            .foregroundStyle(MobileKeptoraDesign.mint)
                        }
                    }
                    Spacer()
                    Button {
                        if selectedCount > 1 {
                            showClearSelectionConfirmation = true
                        } else {
                            if isSimilarVideoMode { store.clearSimilarVideoSelection() }
                            else { store.clearExactSelection() }
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear Selection")
                    .accessibilityIdentifier(isSimilarVideoMode ? "review.similarVideo.clearSelection" : "review.exact.clearSelection")
                }
                Button("Review Cleanup") { showCleanupConfirmation = true }
                    .buttonStyle(MobilePrimaryButtonStyle())
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("ios.cleanup.review")
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(MobileKeptoraDesign.brandGradient)
                .frame(height: 1.5)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 16, y: -4)
    }

    private var cleanupTitle: String {
        if isSimilarVideoMode {
            return store.source == .photos
                ? String(localized: "Remove selected similar videos from Photos?")
                : String(localized: "Move selected similar videos to Keptora Bin?")
        }
        switch store.source {
        case .photos: return String(localized: "Remove exact copies from Photos?")
        default: return String(localized: "Move exact copies to Keptora Bin?")
        }
    }

    private var cleanupButtonTitle: String {
        switch store.source {
        case .photos: return String(localized: "Remove from Photos")
        default: return String(localized: "Move to Bin")
        }
    }

    private var cleanupMessage: String {
        let kind = isSimilarVideoMode ? String(localized: "manually reviewed similar videos") : String(localized: "verified exact copies")
        let format = String(localized: "%1$lld %2$@ · %3$@.")
        let summary = String(
            format: format,
            locale: .current,
            Int64(selectedCount),
            kind,
            ByteCountFormatter.string(fromByteCount: selectedBytes, countStyle: .file)
        )
        let zeroCount = isSimilarVideoMode ? store.similarVideoGroupsWithAllCopiesSelectedCount : store.exactGroupsWithAllCopiesSelectedCount
        let zeroWarning = zeroCount > 0
            ? "\n\n🚨 " + String(format: String(localized: "DANGER: In %1$lld set(s), ALL copies including the original are selected. You will lose this media completely!"), Int64(zeroCount))
            : ""
        let keeperWarning = store.hasSelectedKeeper ? "\n\n⚠️ " + String(localized: "Includes original (keeper) photo/video. It will also be deleted.") : ""
        switch store.source {
        case .photos:
            let baseNotice = store.hasSelectedKeeper
                ? String(localized: "✓ Restorable at any time: Deleted items (including originals) move to Recently Deleted for up to 30 days.")
                : String(localized: "✓ Restorable at any time: Protected keepers stay intact. Removed photos move to Recently Deleted for up to 30 days.")
            return summary + zeroWarning + keeperWarning + "\n\n" + baseNotice
        default:
            let baseNotice = store.hasSelectedKeeper
                ? String(localized: "✓ Restorable at any time: Deleted items (including originals) move safely to Keptora Safe Bin.")
                : String(localized: "✓ Restorable at any time: Protected keepers stay intact. Copies move safely to Keptora Safe Bin.")
            return summary + zeroWarning + keeperWarning + "\n\n" + baseNotice
        }
    }
}

// MARK: – Generic Group Pager

private struct GroupPager<Item: Identifiable, PageContent: View>: View {
    let items: [Item]
    @Binding var selection: Int
    @ViewBuilder let content: (Int, Item) -> PageContent

    var body: some View {
        TabView(selection: $selection) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                content(index, item)
                    .tag(index)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
    }
}

// MARK: – Exact Group Page

private struct ExactGroupPage: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    let group: UniversalExactGroup
    let pageIndex: Int
    let totalPages: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onJumpTo: (Int) -> Void

    @State private var activeInspectorAsset: UniversalMediaAsset?
    @State private var activeSafetyAsset: UniversalMediaAsset?

    private var isAllCopiesSelected: Bool {
        !group.assets.isEmpty && group.assets.allSatisfy { store.selectedAssetIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if totalPages > 1 {
                    HStack(alignment: .center) {
                        Menu {
                            ForEach(0..<min(totalPages, 50), id: \.self) { targetIndex in
                                Button(String(format: String(localized: "Set %1$lld of %2$lld"), Int64(targetIndex + 1), Int64(totalPages))) {
                                    onJumpTo(targetIndex)
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "photo.stack")
                                    .font(.system(size: 11, weight: .bold))
                                Text(String(format: String(localized: "Set %1$lld of %2$lld"), Int64(pageIndex + 1), Int64(totalPages)))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(MobileKeptoraDesign.accent)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(MobileKeptoraDesign.accent.opacity(0.12), in: Capsule())
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(format: String(localized: "Set %1$lld of %2$lld"), Int64(pageIndex + 1), Int64(totalPages)))

                        Spacer()

                        HStack(spacing: 8) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onPrevious()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(pageIndex > 0 ? Color.primary : Color.secondary.opacity(0.35))
                                    .frame(width: 30, height: 30)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .padding(7)
                                    .contentShape(Rectangle())
                                    .padding(-7)
                            }
                            .buttonStyle(.plain)
                            .disabled(pageIndex == 0)
                            .accessibilityLabel("Previous set")

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onNext()
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(pageIndex < totalPages - 1 ? Color.primary : Color.secondary.opacity(0.35))
                                    .frame(width: 30, height: 30)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .padding(7)
                                    .contentShape(Rectangle())
                                    .padding(-7)
                            }
                            .buttonStyle(.plain)
                            .disabled(pageIndex >= totalPages - 1)
                            .accessibilityLabel("Next set")
                        }
                    }
                    .padding(.horizontal, 4)
                }

                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStringKey("Exact set"))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        Text(String(format: String(localized: "%@ copies · %@ safe to review"), group.assets.count.formatted(), ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file)))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    MobilePillBadge(title: "Verified", systemImage: "checkmark.seal.fill", tint: MobileKeptoraDesign.mint)
                }
                .padding(.horizontal, 4)

                if isAllCopiesSelected {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundStyle(MobileKeptoraDesign.danger)
                        Text(LocalizedStringKey("All copies selected — no copy will remain!"))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(MobileKeptoraDesign.danger)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MobileKeptoraDesign.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 4)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(group.assets) { asset in
                        MobileAssetCard(
                            asset: asset,
                            group: group,
                            onInspect: { activeInspectorAsset = asset },
                            onSafetyDetails: { activeSafetyAsset = asset }
                        )
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 40)
        }
        .fullScreenCover(item: $activeInspectorAsset) { asset in
            MobilePhotoInspectorSheet(asset: asset)
        }
        .sheet(item: $activeSafetyAsset) { asset in
            SafetyDetailsSheet(asset: asset, isKeeper: asset.id == group.keeperID)
        }
    }
}

// MARK: – Safety Details Sheet

private struct SafetyDetailsSheet: View {
    @Environment(\.dismiss) private var dismiss
    let asset: UniversalMediaAsset
    let isKeeper: Bool

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("Status", value: isKeeper ? String(localized: "Protected keeper") : String(localized: "Byte-for-byte exact copy"))
                LabeledContent("Name", value: asset.displayName)
                LabeledContent("Size", value: asset.byteCount.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—")
                LabeledContent("Resolution", value: "\(asset.pixelWidth) × \(asset.pixelHeight)")
                if let date = asset.creationDate { LabeledContent("Created", value: date.formatted()) }
                Section {
                    Text("Keptora verified this item byte for byte. It can be selected because another protected copy remains in this exact group.")
                } header: { Text("Why this is safe") }
            }
            .navigationTitle("Asset Details")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close Asset Details screen")
                        .accessibilityIdentifier("ios.assetDetails.close")
                }
            }
        }
    }
}

// MARK: – Mobile Asset Card

private struct MobileAssetCard: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @EnvironmentObject private var purchase: MobilePurchaseController
    let asset: UniversalMediaAsset
    let group: UniversalExactGroup
    let onInspect: () -> Void
    let onSafetyDetails: () -> Void

    private var isKeeper: Bool { asset.id == group.keeperID }
    private var isSelected: Bool { store.selectedAssetIDs.contains(asset.id) }

    private var checkboxFillColor: Color {
        if isSelected {
            return isKeeper ? MobileKeptoraDesign.amber : MobileKeptoraDesign.violet
        }
        if isKeeper {
            return MobileKeptoraDesign.mint.opacity(0.85)
        }
        if asset.isProtectedFromGlobalSelection {
            return MobileKeptoraDesign.amber.opacity(0.85)
        }
        return Color.black.opacity(0.40)
    }

    private var checkboxIconName: String {
        if isSelected { return "checkmark" }
        if isKeeper || asset.isProtectedFromGlobalSelection { return "shield.fill" }
        return ""
    }

    @ViewBuilder
    private var thumbnailView: some View {
        Button(action: toggle) {
            ZStack(alignment: .bottomLeading) {
                MobileAssetThumbnail(asset: asset)
                    .frame(height: 106)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                if asset.mediaKind == .video {
                    Label(asset.formattedDuration, systemImage: "play.fill")
                        .font(.system(.caption2, design: .rounded).weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.68), in: Capsule())
                        .padding(5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "%@ photo"), asset.displayName))
        .accessibilityIdentifier("review.exact.asset.\(asset.id)")
    }

    private var inspectButton: some View {
        Button(action: onInspect) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.52))
                    .frame(width: 26, height: 26)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .padding(4)
            .contentShape(Rectangle())
            .padding(-4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "Inspect %@ full screen"), asset.displayName))
        .accessibilityIdentifier("review.exact.inspect.\(asset.id)")
    }

    private var checkboxButton: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .fill(checkboxFillColor)
                    .frame(width: 24, height: 24)
                
                Image(systemName: checkboxIconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .padding(4)
            .contentShape(Rectangle())
            .padding(-4)
            .shadow(radius: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "Toggle selection for %@"), asset.displayName))
        .accessibilityIdentifier("review.exact.checkbox.\(asset.id)")
    }

    private var cardDetailsView: some View {
        Button(action: toggle) {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: asset.displayName)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .lineLimit(1)

                HStack {
                    Text(verbatim: asset.byteCount.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—")
                        .font(.system(.caption2, design: .rounded).weight(.medium))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                    
                    assetStatusBadge
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }

    private var cardBorderShape: some ShapeStyle {
        if isSelected {
            return isKeeper ? AnyShapeStyle(MobileKeptoraDesign.amber) : AnyShapeStyle(MobileKeptoraDesign.brandGradient)
        } else {
            return AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(0.30), Color.primary.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .top) {
                thumbnailView
                HStack {
                    inspectButton
                    Spacer()
                    checkboxButton
                }
            }
            cardDetailsView
        }
        .padding(7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .background(
            (isSelected ? MobileKeptoraDesign.violet : MobileKeptoraDesign.accent).opacity(isSelected ? 0.10 : 0.02),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(cardBorderShape, lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: isSelected ? (isKeeper ? MobileKeptoraDesign.amber.opacity(0.24) : MobileKeptoraDesign.violet.opacity(0.24)) : Color.black.opacity(0.04), radius: 12, y: 6)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(String(format: String(localized: "%1$@, %2$@"), asset.displayName, isKeeper ? String(localized: "protected keeper") : String(localized: "exact copy")))
        .accessibilityIdentifier("review.exact.container.\(asset.id)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button {
                onInspect()
            } label: {
                Label("Inspect Photo", systemImage: "arrow.up.left.and.arrow.down.right")
            }
            
            Button {
                onSafetyDetails()
            } label: {
                Label("Why this is safe", systemImage: "shield.lefthalf.filled")
            }
            .accessibilityIdentifier("ios.assetDetails.open")
        }
    }

    private var badgeTitle: LocalizedStringKey {
        if isKeeper {
            return isSelected ? "Keeper (Delete)" : "Keeper"
        } else if asset.isProtectedFromGlobalSelection {
            return isSelected ? "Protected (Delete)" : "Protected"
        } else {
            return "Copy"
        }
    }

    private var badgeColor: Color {
        if isKeeper {
            return isSelected ? MobileKeptoraDesign.amber : MobileKeptoraDesign.mint
        } else if asset.isProtectedFromGlobalSelection {
            return MobileKeptoraDesign.amber
        } else {
            return MobileKeptoraDesign.cyan
        }
    }

    private var assetStatusBadge: some View {
        Text(badgeTitle)
            .font(.system(.caption2, design: .rounded).weight(.bold))
            .textCase(.uppercase)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .foregroundStyle(badgeColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.14), in: Capsule())
    }

    private func toggle() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if !store.toggleSelection(asset, in: group, isUnlocked: purchase.isUnlocked) {
            store.present(.paywall)
        }
    }
}

// MARK: – Similar Video Group Page

private struct SimilarVideoGroupPage: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    let group: UniversalSimilarityGroup
    let pageIndex: Int
    let totalPages: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    let onJumpTo: (Int) -> Void

    @State private var activeInspectorAsset: UniversalMediaAsset?

    private var isAllCopiesSelected: Bool {
        !group.assets.isEmpty && group.assets.allSatisfy { store.selectedSimilarVideoAssetIDs.contains($0.id) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if totalPages > 1 {
                    HStack(alignment: .center) {
                        Menu {
                            ForEach(0..<min(totalPages, 50), id: \.self) { targetIndex in
                                Button(String(format: String(localized: "Set %1$lld of %2$lld"), Int64(targetIndex + 1), Int64(totalPages))) {
                                    onJumpTo(targetIndex)
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: "video.fill")
                                    .font(.system(size: 11, weight: .bold))
                                Text(String(format: String(localized: "Set %1$lld of %2$lld"), Int64(pageIndex + 1), Int64(totalPages)))
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 9, weight: .bold))
                            }
                            .foregroundStyle(MobileKeptoraDesign.cyan)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .background(MobileKeptoraDesign.cyan.opacity(0.12), in: Capsule())
                        }
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(format: String(localized: "Set %1$lld of %2$lld"), Int64(pageIndex + 1), Int64(totalPages)))

                        Spacer()

                        HStack(spacing: 8) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onPrevious()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(pageIndex > 0 ? Color.primary : Color.secondary.opacity(0.35))
                                    .frame(width: 30, height: 30)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .padding(7)
                                    .contentShape(Rectangle())
                                    .padding(-7)
                            }
                            .buttonStyle(.plain)
                            .disabled(pageIndex == 0)
                            .accessibilityLabel("Previous set")

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onNext()
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(pageIndex < totalPages - 1 ? Color.primary : Color.secondary.opacity(0.35))
                                    .frame(width: 30, height: 30)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .padding(7)
                                    .contentShape(Rectangle())
                                    .padding(-7)
                            }
                            .buttonStyle(.plain)
                            .disabled(pageIndex >= totalPages - 1)
                            .accessibilityLabel("Next set")
                        }
                    }
                    .padding(.horizontal, 4)
                }

                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStringKey("Similar videos"))
                            .font(.system(.title2, design: .rounded).weight(.bold))
                        Text(LocalizedStringKey("A visual suggestion, not an exact match. Tap a card or its checkbox to choose it."))
                            .font(.system(.subheadline, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    MobilePillBadge(title: "Review first", systemImage: "eye.fill", tint: MobileKeptoraDesign.cyan)
                }
                .padding(.horizontal, 4)

                if isAllCopiesSelected {
                    HStack(spacing: 8) {
                        Image(systemName: "exclamationmark.octagon.fill")
                            .foregroundStyle(MobileKeptoraDesign.danger)
                        Text(LocalizedStringKey("All videos selected — no copy will remain!"))
                            .font(.system(.caption, design: .rounded).weight(.bold))
                            .foregroundStyle(MobileKeptoraDesign.danger)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(MobileKeptoraDesign.danger.opacity(0.12), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(.horizontal, 4)
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(group.assets) { asset in
                        SimilarVideoAssetCard(
                            asset: asset,
                            group: group,
                            onInspect: { activeInspectorAsset = asset }
                        )
                    }
                }

                HStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.headline)
                        .foregroundStyle(MobileKeptoraDesign.accent)
                    Text("Before cleanup, Keptora verifies every selected video's original bytes again. The keeper is never selected.")
                        .font(.system(.footnote, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(12)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).stroke(MobileKeptoraDesign.accent.opacity(0.14), lineWidth: 1) }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 40)
        }
        .fullScreenCover(item: $activeInspectorAsset) { asset in
            MobilePhotoInspectorSheet(asset: asset)
        }
    }
}

// MARK: – Similar Video Asset Card

private struct SimilarVideoAssetCard: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @EnvironmentObject private var purchase: MobilePurchaseController
    let asset: UniversalMediaAsset
    let group: UniversalSimilarityGroup
    let onInspect: () -> Void

    private var isKeeper: Bool { asset.id == group.keeperID }
    private var isProtected: Bool { asset.isProtectedFromGlobalSelection }
    private var isSelected: Bool { store.selectedSimilarVideoAssetIDs.contains(asset.id) }

    private var statusBadgeColor: Color {
        if isSelected { return MobileKeptoraDesign.amber }
        if isKeeper || isProtected { return MobileKeptoraDesign.mint }
        return MobileKeptoraDesign.cyan
    }

    private var checkboxFillColor: Color {
        if isSelected {
            return isKeeper ? MobileKeptoraDesign.amber : MobileKeptoraDesign.violet
        }
        if isKeeper {
            return MobileKeptoraDesign.mint.opacity(0.85)
        }
        if isProtected {
            return MobileKeptoraDesign.amber.opacity(0.85)
        }
        return Color.black.opacity(0.40)
    }

    private var checkboxIconName: String {
        if isSelected { return "checkmark" }
        if isKeeper || isProtected { return "shield.fill" }
        return ""
    }

    private var videoThumbnail: some View {
        ZStack(alignment: .bottomLeading) {
            MobileAssetThumbnail(asset: asset)
                .frame(height: 106)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

            Label(asset.formattedDuration, systemImage: "play.fill")
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 5)
                .padding(.vertical, 3)
                .background(.black.opacity(0.68), in: Capsule())
                .padding(5)
        }
    }

    private var videoInfoRow: some View {
        HStack {
            Text(verbatim: asset.byteCount.map { ByteCountFormatter.string(fromByteCount: $0, countStyle: .file) } ?? "—")
                .font(.system(.caption2, design: .rounded).weight(.medium))
                .monospacedDigit()
                .foregroundStyle(.secondary)
            
            Spacer()
            
            Text(statusLabel)
                .font(.system(.caption2, design: .rounded).weight(.bold))
                .textCase(.uppercase)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .foregroundStyle(statusBadgeColor)
                .padding(.horizontal, 4)
                .padding(.vertical, 1.5)
                .background(statusBadgeColor.opacity(0.14), in: Capsule())
        }
    }

    private var cardBorderShape: some ShapeStyle {
        if isSelected {
            return isKeeper ? AnyShapeStyle(MobileKeptoraDesign.amber) : AnyShapeStyle(MobileKeptoraDesign.brandGradient)
        } else {
            return AnyShapeStyle(LinearGradient(colors: [MobileKeptoraDesign.cyan.opacity(0.24), Color.primary.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            videoThumbnail

            Text(verbatim: asset.displayName)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .lineLimit(1)

            videoInfoRow
        }
        .padding(7)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .background(
            (isSelected ? MobileKeptoraDesign.violet : MobileKeptoraDesign.cyan).opacity(isSelected ? 0.10 : 0.02),
            in: RoundedRectangle(cornerRadius: 15, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(cardBorderShape, lineWidth: isSelected ? 2 : 1)
        }
        .shadow(color: isSelected ? (isKeeper ? MobileKeptoraDesign.amber.opacity(0.22) : MobileKeptoraDesign.violet.opacity(0.22)) : Color.black.opacity(0.04), radius: 12, y: 6)
    }

    private var inspectButton: some View {
        Button(action: onInspect) {
            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.52))
                    .frame(width: 26, height: 26)
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .padding(4)
            .contentShape(Rectangle())
            .padding(-4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "Inspect %@ video full screen"), asset.displayName))
        .accessibilityIdentifier("review.similarVideo.inspect.\(asset.id)")
    }

    private var checkboxButton: some View {
        Button(action: toggle) {
            ZStack {
                Circle()
                    .fill(checkboxFillColor)
                    .frame(width: 24, height: 24)
                
                Image(systemName: checkboxIconName)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.white)
            }
            .frame(width: 36, height: 36)
            .padding(4)
            .contentShape(Rectangle())
            .padding(-4)
            .shadow(radius: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "Toggle selection for %@"), asset.displayName))
        .accessibilityIdentifier("review.similarVideo.checkbox.\(asset.id)")
    }

    var body: some View {
        Button {
            toggle()
        } label: {
            cardContent
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(format: String(localized: "%1$@, %2$@"), asset.displayName, isKeeper ? String(localized: "protected keeper") : String(localized: "similar video candidate")))
        .accessibilityIdentifier("review.similarVideo.asset.\(asset.id)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .contextMenu {
            Button {
                onInspect()
            } label: {
                Label("Inspect Video", systemImage: "arrow.up.left.and.arrow.down.right")
            }
        }
        .overlay(alignment: .top) {
            HStack {
                inspectButton
                Spacer()
                checkboxButton
            }
        }
    }

    private func toggle() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        if !store.toggleSimilarVideoSelection(asset, in: group, isUnlocked: purchase.isUnlocked) {
            store.present(.paywall)
        }
    }

    private var statusLabel: LocalizedStringKey {
        if isKeeper { return isSelected ? "Keeper (Delete)" : "Keeper" }
        if isProtected { return isSelected ? "Protected (Delete)" : "Protected" }
        return "Review"
    }
}

// MARK: – Similarity Group Page

private enum SimilarityCompareModal: Identifiable {
    case sideBySide
    case splitLoupe
    var id: Int { hashValue }
}

private struct SimilarityGroupPage: View {
    let group: UniversalSimilarityGroup
    let pageIndex: Int
    let totalPages: Int
    let onPrevious: () -> Void
    let onNext: () -> Void
    @State private var activeCompareModal: SimilarityCompareModal?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if totalPages > 1 {
                    HStack(alignment: .center) {
                        HStack(spacing: 6) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 11, weight: .bold))
                            Text(String(format: String(localized: "Set %1$lld of %2$lld"), Int64(pageIndex + 1), Int64(totalPages)))
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(MobileKeptoraDesign.violet)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(MobileKeptoraDesign.violet.opacity(0.12), in: Capsule())
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel(String(format: String(localized: "Set %1$lld of %2$lld"), Int64(pageIndex + 1), Int64(totalPages)))

                        Spacer()

                        HStack(spacing: 8) {
                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onPrevious()
                            }) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(pageIndex > 0 ? Color.primary : Color.secondary.opacity(0.35))
                                    .frame(width: 30, height: 30)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .padding(7)
                                    .contentShape(Rectangle())
                                    .padding(-7)
                            }
                            .buttonStyle(.plain)
                            .disabled(pageIndex == 0)
                            .accessibilityLabel("Previous set")

                            Button(action: {
                                UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                                onNext()
                            }) {
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(pageIndex < totalPages - 1 ? Color.primary : Color.secondary.opacity(0.35))
                                    .frame(width: 30, height: 30)
                                    .background(.ultraThinMaterial, in: Circle())
                                    .padding(7)
                                    .contentShape(Rectangle())
                                    .padding(-7)
                            }
                            .buttonStyle(.plain)
                            .disabled(pageIndex >= totalPages - 1)
                            .accessibilityLabel("Next set")
                        }
                    }
                    .padding(.horizontal, 4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Similar photos")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text("Compare these suggestions. No cleanup actions are available.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                HStack(spacing: 10) {
                    Button { activeCompareModal = .sideBySide } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "rectangle.split.2x1")
                                .font(.system(size: 15, weight: .semibold))
                            Text("Side by Side")
                        }
                        .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(MobilePrimaryButtonStyle())
                    .accessibilityIdentifier("ios.similarityComparison.open")

                    if group.assets.count >= 2 {
                        Button { activeCompareModal = .splitLoupe } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "slider.horizontal.below.rectangle")
                                    .font(.system(size: 15, weight: .semibold))
                                Text("Split Loupe")
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(MobileKeptoraDesign.cyan)
                        .accessibilityIdentifier("ios.similaritySplitComparison.open")
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 10)], spacing: 10) {
                    ForEach(group.assets) { asset in
                        VStack(alignment: .leading, spacing: 6) {
                            MobileAssetThumbnail(asset: asset)
                                .frame(height: 106)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            Text(verbatim: asset.displayName)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .lineLimit(1)

                            HStack {
                                Label("Review only", systemImage: "eye")
                                    .font(.system(.caption2, design: .rounded).weight(.medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(7)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 15, style: .continuous)
                                .stroke(MobileKeptoraDesign.cyan.opacity(0.20), lineWidth: 1)
                        }
                        .shadow(color: MobileKeptoraDesign.cyan.opacity(0.08), radius: 12, y: 6)
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 40)
        }
        .fullScreenCover(item: $activeCompareModal) { modal in
            switch modal {
            case .sideBySide:
                MobileSimilarityCompareView(group: group)
            case .splitLoupe:
                if group.assets.count >= 2 {
                    MobileSplitComparisonView(assetA: group.assets[0], assetB: group.assets[1])
                }
            }
        }
    }
}

// MARK: – Mobile Similarity Compare View

private struct MobileSimilarityCompareView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    let group: UniversalSimilarityGroup
    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            GeometryReader { proxy in
                Group {
                    if proxy.size.width > proxy.size.height {
                        HStack(spacing: 2) { comparisonAssets }
                    } else {
                        VStack(spacing: 2) { comparisonAssets }
                    }
                }
                .background(Color.black)
                .clipped()
                .simultaneousGesture(
                    MagnificationGesture()
                        .onChanged { scale = min(max(lastScale * $0, 1), 5) }
                        .onEnded { _ in lastScale = scale }
                )
                .simultaneousGesture(
                    DragGesture()
                        .onChanged { value in
                            offset = CGSize(width: lastOffset.width + value.translation.width, height: lastOffset.height + value.translation.height)
                        }
                        .onEnded { _ in lastOffset = offset }
                )
            }
            .safeAreaInset(edge: .bottom) {
                if verticalSizeClass != .compact {
                    HStack(spacing: 8) {
                        Image(systemName: "eye.fill")
                            .font(.system(size: 13, weight: .bold))
                        Text("Review-only comparison")
                            .font(.system(.footnote, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(MobileKeptoraDesign.cyan)
                    .frame(maxWidth: .infinity, minHeight: 46)
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle("Similar Comparison")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close Similar Comparison screen")
                        .accessibilityIdentifier("ios.similarityComparison.close")
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        scale = 1
                        lastScale = 1
                        offset = .zero
                        lastOffset = .zero
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                    .accessibilityLabel("Reset Zoom")
                    .accessibilityIdentifier("ios.similarityComparison.reset")
                }
            }
        }
        .onDisappear {
            scale = 1
            lastScale = 1
            offset = .zero
            lastOffset = .zero
        }
    }

    @ViewBuilder
    private var comparisonAssets: some View {
        ForEach(Array(group.assets.prefix(2))) { asset in
            MobileAssetThumbnail(asset: asset, pixelSize: 1600, contentMode: .fit)
                .scaleEffect(scale)
                .offset(offset)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .accessibilityLabel(asset.displayName)
        }
    }
}

private extension UniversalMediaAsset {
    var formattedDuration: String {
        let value = max(0, Int((duration ?? 0).rounded()))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
