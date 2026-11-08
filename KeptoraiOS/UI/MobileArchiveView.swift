import KeptoraCore
import SwiftUI
import TipKit

// MARK: – Filter Criteria Model

struct MobileLibraryFilterCriteria: Equatable {
    var finding: LibraryFindingFilter = .all
    var media: Int = 0 // 0: All, 1: Photos, 2: Videos
    var albumID: String = ""
    var favouritesOnly: Bool = false
    var oldestFirst: Bool = false
    var largestFirst: Bool = false
    var grouping: Int = 2 // 0: All Items, 1: Day, 2: Month
    var smartOrder: Bool = true
    var dateRangeEnabled: Bool = false
    var fromDate: Date = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    var toDate: Date = Date()

    var activeFilterBadgeCount: Int {
        var count = 0
        if finding != .all { count += 1 }
        if media != 0 { count += 1 }
        if !albumID.isEmpty { count += 1 }
        if favouritesOnly { count += 1 }
        if dateRangeEnabled { count += 1 }
        if largestFirst { count += 1 }
        if oldestFirst { count += 1 }
        return count
    }

    var hasActiveFilters: Bool {
        activeFilterBadgeCount > 0
    }

    mutating func reset() {
        finding = .all
        media = 0
        albumID = ""
        favouritesOnly = false
        oldestFirst = false
        largestFirst = false
        grouping = 2
        smartOrder = true
        dateRangeEnabled = false
    }
}

// MARK: – Liquid Glass Filter Button

struct LiquidGlassFilterButton: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    let activeFilterCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal.decrease.circle.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(activeFilterCount > 0 ? MobileKeptoraDesign.accent : MobileKeptoraDesign.ink)

                Text(L10n.tr("Filters"))
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(MobileKeptoraDesign.ink)

                if activeFilterCount > 0 {
                    Text(verbatim: "\(activeFilterCount)")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(MobileKeptoraDesign.accentFill))
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                if reduceTransparency {
                    Capsule()
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    colorScheme == .dark ? Color.white.opacity(0.28) : Color.black.opacity(0.18),
                                    lineWidth: 1
                                )
                        )
                } else {
                    Capsule()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            Capsule()
                                .strokeBorder(
                                    LinearGradient(
                                        colors: [
                                            colorScheme == .dark ? Color.white.opacity(0.35) : Color.white.opacity(0.70),
                                            colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.03)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ),
                                    lineWidth: 1
                                )
                        )
                        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 3)
                }
            }
            .frame(minWidth: MobileKeptoraDesign.minimumTouchTarget, minHeight: MobileKeptoraDesign.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("archive.filtersButton")
        .accessibilityLabel(
            activeFilterCount > 0
                ? L10n.plural("%lld active filters", activeFilterCount)
                : L10n.tr("Filters")
        )
        .accessibilityHint(L10n.tr("Double-tap to open filter criteria"))
    }
}

// MARK: – Mobile Library Filter Sheet

struct MobileLibraryFilterSheet: View {
    @Binding var criteria: MobileLibraryFilterCriteria
    let albums: [MediaAlbum]
    let scopeIDs: Set<String>
    let reviewGroups: [LibraryReviewGroup]
    let qualityAssessments: [String: QualityAssessment]
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme

    @State private var draft: MobileLibraryFilterCriteria = MobileLibraryFilterCriteria()

    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text(L10n.tr("Finding Mode"))) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(LibraryFindingFilter.allCases) { option in
                                let count = option.ids(groups: reviewGroups, quality: qualityAssessments)?.intersection(scopeIDs).count
                                Button {
                                    draft.finding = option
                                } label: {
                                    HStack(spacing: 5) {
                                        Text(Self.shortTitle(option))
                                        if let count, count > 0 {
                                            Text(count.formatted(.number.locale(L10n.currentLocale)))
                                                .foregroundStyle(MobileKeptoraDesign.secondaryInk)
                                        }
                                    }
                                    .font(.subheadline.weight(.semibold))
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        draft.finding == option
                                            ? AnyShapeStyle(MobileKeptoraDesign.accent.opacity(reduceTransparency ? 0.28 : 0.18))
                                            : (reduceTransparency ? AnyShapeStyle(Color(uiColor: .secondarySystemGroupedBackground)) : AnyShapeStyle(.ultraThinMaterial)),
                                        in: Capsule()
                                    )
                                    .overlay(
                                        Capsule().stroke(
                                            draft.finding == option
                                                ? AnyShapeStyle(MobileKeptoraDesign.accent)
                                                : (reduceTransparency ? AnyShapeStyle(Color.secondary.opacity(0.35)) : AnyShapeStyle(Color.white.opacity(colorScheme == .dark ? 0.30 : 0.65))),
                                            lineWidth: 1
                                        )
                                    )
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(Text(LocalizedStringKey(option.titleKey)))
                                .accessibilityAddTraits(draft.finding == option ? .isSelected : [])
                                .accessibilityIdentifier("archive.finding." + option.rawValue)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
                .mobileGlassRow()

                Section(header: Text(L10n.tr("Media Type"))) {
                    Picker("Media type", selection: $draft.media) {
                        Text("All").tag(0)
                        Text("Photos").tag(1)
                        Text("Videos").tag(2)
                    }
                    .pickerStyle(.segmented)
                }
                .mobileGlassRow()

                if !albums.isEmpty {
                    Section(header: Text("Album")) {
                        Picker("Album", selection: $draft.albumID) {
                            Text("All Albums").tag("")
                            ForEach(albums) { album in
                                Text(album.title).tag(album.id)
                            }
                        }
                    }
                    .mobileGlassRow()
                }

                Section(header: Text(L10n.tr("Options"))) {
                    Toggle("Favorites Only", isOn: $draft.favouritesOnly)
                    Toggle(isOn: $draft.smartOrder) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Keep Related Shots Together")
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)
                            Text(L10n.tr("Organizes photo series and burst sequences together."))
                                .font(.caption)
                                .foregroundStyle(MobileKeptoraDesign.secondaryInk)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Toggle("Oldest First", isOn: $draft.oldestFirst)
                    Toggle("Largest First", isOn: $draft.largestFirst)
                    Picker("Group by", selection: $draft.grouping) {
                        Text("All Items").tag(0)
                        Text("Day").tag(1)
                        Text("Month").tag(2)
                    }
                }
                .mobileGlassRow()

                Section(header: Text("Date Range")) {
                    Toggle("Filter by Date", isOn: $draft.dateRangeEnabled)
                    if draft.dateRangeEnabled {
                        DatePicker("From", selection: $draft.fromDate, in: ...draft.toDate, displayedComponents: .date)
                        DatePicker("To", selection: $draft.toDate, in: draft.fromDate..., displayedComponents: .date)
                    }
                }
                .mobileGlassRow()

                Section {
                    Button(role: .destructive) {
                        draft.reset()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Reset Filters")
                            Spacer()
                        }
                    }
                    .accessibilityIdentifier("archive.resetFilters")
                }
                .mobileGlassRow()
            }
            .scrollContentBackground(.hidden)
            .background(MobileAuroraBackground())
            .navigationTitle(L10n.tr("Filters"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("Apply")) {
                        criteria = draft
                        dismiss()
                    }
                    .bold()
                    .accessibilityIdentifier("archive.filterSheet.done")
                }
            }
            .onAppear {
                draft = criteria
            }
        }
    }

    private static func shortTitle(_ option: LibraryFindingFilter) -> LocalizedStringKey {
        switch option {
        case .all: return "All"
        case .copies: return "Copies"
        case .verySimilar: return "Very Similar"
        case .bursts: return "Bursts"
        case .review: return "Review"
        }
    }
}

// MARK: – Main Library View

struct MobileLibraryView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @EnvironmentObject private var purchase: MobilePurchaseController
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var visibleAnchor: String?
    @State private var filterCriteria = MobileLibraryFilterCriteria()
    @State private var isFilterSheetPresented = false
    @State private var search = ""
    @State private var cloudScan = false
    @State private var sources = false
    @State private var pendingFolderPicker = false
    @State private var reviewSelection = false
    @State private var previewAsset: UniversalMediaAsset?

    /// Holds the visible list for one render pass. `body` clears it, so each redraw filters and sorts the
    /// library once instead of once per section that reads it (measured ~28 ms per pass at 50,000 items).
    private final class VisibleMemo { var value: [UniversalMediaAsset]? }
    @State private var visibleMemo = VisibleMemo()

    private var visible: [UniversalMediaAsset] {
        if let cached = visibleMemo.value { return cached }
        let computed = computeVisible()
        visibleMemo.value = computed
        return computed
    }

    private func computeVisible() -> [UniversalMediaAsset] {
        let findingIDs = filterCriteria.finding.ids(groups: store.reviewGroups, quality: store.qualityAssessments)
        return store.scopedAssets.filter { asset in
            (findingIDs?.contains(asset.id) ?? true) &&
            (filterCriteria.media == 0 || (filterCriteria.media == 1 ? asset.mediaKind == .image : asset.mediaKind == .video)) &&
            (filterCriteria.albumID.isEmpty || asset.context?.albums.contains { $0.id == filterCriteria.albumID } == true) &&
            (!filterCriteria.favouritesOnly || asset.isFavorite) &&
            store.collectionContains(asset) &&
            (!filterCriteria.dateRangeEnabled || dateMatches(asset)) &&
            (search.isEmpty || asset.displayName.localizedCaseInsensitiveContains(search) ||
             asset.context?.camera?.localizedCaseInsensitiveContains(search) == true)
        }.sorted {
            if filterCriteria.largestFirst || store.libraryCollectionSortBySize {
                let a = $0.byteCount ?? -1, b = $1.byteCount ?? -1
                if a != b { return a > b }
            }
            let a = $0.context?.captureDate ?? $0.creationDate ?? .distantPast
            let b = $1.context?.captureDate ?? $1.creationDate ?? .distantPast
            return a == b ? $0.id < $1.id : (filterCriteria.oldestFirst ? a < b : a > b)
        }
    }

    private var sections: [(date: Date, assets: [UniversalMediaAsset])] {
        let calendar = Calendar.current
        if filterCriteria.largestFirst || store.libraryCollectionSortBySize || filterCriteria.grouping == 0 {
            return [(date: .distantFuture, assets: visible)]
        }
        let grouped = Dictionary(grouping: visible) {
            guard let date = $0.context?.captureDate ?? $0.creationDate else { return Date.distantPast }
            return calendar.dateInterval(of: filterCriteria.grouping == 1 ? .day : .month, for: date)?.start ?? .distantPast
        }
        return grouped.map { (date: $0.key, assets: $0.value) }.sorted { filterCriteria.oldestFirst ? $0.date < $1.date : $0.date > $1.date }
    }

    var body: some View {
        let _ = { visibleMemo.value = nil }()
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                libraryContent
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 16)
        }
        .scrollPosition(id: $visibleAnchor, anchor: .top)
        .refreshable { await store.loadCatalogue() }
        .background {
            MobileAuroraBackground()
        }
        .navigationTitle(store.libraryCollectionKind.map { L10n.tr(String.LocalizationValue($0)) } ?? store.libraryCollectionTitle ?? L10n.tr("Photo Library"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search filenames or camera")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Sources") { sources = true }
                    Button("Settings", systemImage: "gearshape") { store.present(.settings) }.accessibilityIdentifier("ios.library.settings")
                    Button("Refresh Library", systemImage: "arrow.clockwise") { Task { await store.loadCatalogue() } }
                } label: { Image(systemName: "ellipsis.circle").frame(minWidth: 44, minHeight: 44) }
                .accessibilityLabel("Library options").accessibilityIdentifier("ios.library.options")
            }
            ToolbarItem(placement: .topBarTrailing) {
                if purchase.isUnlocked {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(MobileKeptoraDesign.accent)
                        Text("PRO")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(MobileKeptoraDesign.accent)
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(MobileKeptoraDesign.accent.opacity(0.12), in: Capsule())
                    .accessibilityLabel("Keptora Pro Unlocked")
                    .accessibilityIdentifier("ios.topbar.proBadge")
                } else {
                    Button {
                        store.present(.paywall)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 12, weight: .bold))
                            Text("PRO")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .padding(.vertical, 6)
                        .background(MobileKeptoraDesign.brandGradient, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: 44, minHeight: 44)
                    .accessibilityLabel("Unlock Keptora Pro")
                    .accessibilityIdentifier("ios.topbar.proButton")
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.selectedLibraryIDs.isEmpty || store.canUndoLibrarySelection {
                selectionBar
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.snappy(duration: 0.28), value: store.selectedLibraryIDs.isEmpty && !store.canUndoLibrarySelection)
        .confirmationDialog("Download cloud originals?", isPresented: $cloudScan) {
            Button("Download and Scan") { store.startScan(allowNetwork: true) }
        } message: { Text("This may use network data and device storage. You can cancel the scan at any time.") }
        .sheet(isPresented: $sources, onDismiss: { if pendingFolderPicker { pendingFolderPicker = false; store.present(.filePicker) } }) {
            NavigationStack {
                MobileSourceLibraryView(onChooseFolder: { pendingFolderPicker = true; sources = false })
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { sources = false } } }
            }
        }
        .sheet(isPresented: $reviewSelection) { MobileSelectionReviewSheet() }
        .fullScreenCover(item: $previewAsset) { asset in
            MobileFullAssetViewer(
                asset: asset,
                sourceLabel: store.sourceLabel(asset),
                isSelected: store.selectedLibraryIDs.contains(asset.id),
                onToggleSelection: { store.toggleLibrarySelection(asset) },
                onDismiss: { previewAsset = nil }
            )
        }
        .sheet(isPresented: $isFilterSheetPresented) {
            MobileLibraryFilterSheet(
                criteria: $filterCriteria,
                albums: store.albums,
                scopeIDs: Set(store.scopedAssets.map(\.id)),
                reviewGroups: store.reviewGroups,
                qualityAssessments: store.qualityAssessments
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: store.scanSourceSelection) { _, _ in filterCriteria.reset(); search = "" }
        .onChange(of: store.connectedFolders) { _, _ in filterCriteria.albumID = ""; filterCriteria.media = 0; search = ""; filterCriteria.dateRangeEnabled = false; filterCriteria.favouritesOnly = false }
        .onChange(of: store.source) { _, _ in filterCriteria.dateRangeEnabled = false; filterCriteria.albumID = ""; search = "" }
        .onChange(of: store.libraryCollectionIDs) { _, ids in
            if ids != nil { filterCriteria.albumID = ""; search = ""; filterCriteria.media = 0; filterCriteria.favouritesOnly = false; filterCriteria.dateRangeEnabled = false; filterCriteria.largestFirst = false }
        }
        .sensoryFeedback(.selection, trigger: store.selectedLibraryIDs)
        .sensoryFeedback(.impact(weight: .medium), trigger: store.decisions)
        .alert("Photos Access Needed", isPresented: Binding(get: { store.isShowingPhotosPermissionHelp && !sources }, set: { if !$0 { DispatchQueue.main.async { store.isShowingPhotosPermissionHelp = false } } })) {
            if store.canOpenPhotosSettings { Button("Open Settings") { store.openPhotosSettings() }.accessibilityIdentifier("ios.photosPermission.openSettings") }
            Button("Not Now", role: .cancel) { }.accessibilityIdentifier("ios.photosPermission.notNow")
        } message: { Text(store.photosPermissionHelpMessage) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ios.page.archive")
    }

    @ViewBuilder private var libraryContent: some View {
        if store.source == .none {
            welcome
        } else {
            catalogueHeader
            if let error = store.catalogueError {
                ContentUnavailableView {
                    Label("Library could not be loaded", systemImage: "exclamationmark.triangle")
                } description: { Text(error) } actions: {
                    Button("Try Again") { Task { await store.loadCatalogue() } }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent))
                }
            } else if store.isLoadingCatalogue && store.assets.isEmpty {
                ProgressView("Loading your library…").frame(maxWidth: .infinity, minHeight: 180)
            } else if store.selectedSourceIDs.isEmpty {
                ContentUnavailableView {
                    Label("Select at least one source", systemImage: "checklist")
                } description: { Text("Open Sources and select at least one source.") }
                actions: { Button("Sources") { sources = true }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent)) }
            } else if visible.isEmpty {
                if store.scanState.isScanning || store.isAnalyzing {
                    Text("Results appear as they become available.").foregroundStyle(MobileKeptoraDesign.secondaryInk).padding(.vertical, 40)
                } else {
                    ContentUnavailableView {
                        Label(search.isEmpty ? "No items in this view" : "No results for \"\(search)\"", systemImage: search.isEmpty ? "photo" : "magnifyingglass")
                    } description: {
                        Text(search.isEmpty ? "Change the filters or choose another source." : "Check the spelling or try searching another camera or date.")
                    } actions: {
                        if !search.isEmpty {
                            Button("Clear Search") { search = "" }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent))
                        }
                        Button("Reset Filters") { resetFilters() }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent)).accessibilityIdentifier("archive.resetFilters")
                    }
                }
            } else if filterCriteria.finding != .all {
                unifiedReviewGallery
            } else if filterCriteria.smartOrder {
                smartBlocksGallery
            } else {
                dateSectionsGallery
            }
        }
    }

    private var galleryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 150 : 106), spacing: 4, alignment: .top)]
    }

    @ViewBuilder private var unifiedReviewGallery: some View {
        let candidatesByGroup = store.decisions.candidatesByGroup(store.reviewGroups)
        let visibleIDs = Set(visible.map(\.id))
        var membership: [String: [LibraryReviewGroup]] = [:]
        let _ = {
            for group in store.reviewGroups {
                for asset in group.assets {
                    membership[asset.id, default: []].append(group)
                }
            }
        }()
        let keeperBadges = store.decisions.keeperBadgeKeys(in: store.reviewGroups)
        let blocks = LibraryReviewBlock.make(assets: visible, groups: store.reviewGroups, quality: store.qualityAssessments, smart: true)
        let orderedAssets = blocks.flatMap(\.assets)
        let groups = blocks.flatMap(\.groups)
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(filterCriteria.finding.titleKey)).font(.headline)
            LazyVGrid(columns: galleryColumns, alignment: .leading, spacing: 4) {
                ForEach(orderedAssets) { asset in
                    cell(asset, groups: membership[asset.id] ?? [], keeperBadge: keeperBadges[asset.id]).id(asset.id)
                }
            }.scrollTargetLayout()
            ForEach(groups) { group in
                groupActions(group, candidates: (candidatesByGroup[group.id] ?? []).filter { visibleIDs.contains($0.id) }, itemCount: group.assets.filter { visibleIDs.contains($0.id) }.count)
            }
        }
    }

    @ViewBuilder private var smartBlocksGallery: some View {
        let candidatesByGroup = store.decisions.candidatesByGroup(store.reviewGroups)
        let visibleIDs = Set(visible.map(\.id))
        let blocks = LibraryReviewBlock.make(assets: visible, groups: store.reviewGroups, quality: store.qualityAssessments, smart: true)
        ForEach(blocks) { block in
            let membership = block.groupsByAsset
            let keeperBadges = store.decisions.keeperBadgeKeys(in: block.groups)
            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey(block.titleKey)).font(.headline)
                LazyVGrid(columns: galleryColumns, alignment: .leading, spacing: 4) {
                    ForEach(block.assets) { asset in
                        cell(asset, groups: membership[asset.id] ?? [], keeperBadge: keeperBadges[asset.id]).id(asset.id)
                    }
                }.scrollTargetLayout()
                ForEach(block.groups) { group in
                    groupActions(group, candidates: (candidatesByGroup[group.id] ?? []).filter { visibleIDs.contains($0.id) }, itemCount: group.assets.filter { visibleIDs.contains($0.id) }.count)
                }
            }
        }
    }

    @ViewBuilder private var dateSectionsGallery: some View {
        ForEach(sections, id: \.date) { section in
            sectionHeader(section)
            LazyVGrid(columns: galleryColumns, alignment: .leading, spacing: 4) {
                ForEach(section.assets) { asset in cell(asset).id(asset.id) }
            }.scrollTargetLayout()
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image("onboarding_privacy").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
            Text("Your Photos").font(.largeTitle.bold())
            Text("Browse every photo, select what you no longer need, and review before removing anything.").foregroundStyle(MobileKeptoraDesign.secondaryInk)
            Button("Open Photos") { Task { await store.connectPhotos() } }
                .accessibilityIdentifier("library.source.photos")
                .buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true))
            Button("Choose a Folder") { store.present(.filePicker) }.accessibilityIdentifier("library.source.files").buttonStyle(MobileActionButtonStyle(fillsWidth: true))
            Text("Private processing on your device. No account required.").font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk)
        }.padding(8)
    }

    // Header: one status card, one liquid glass filter button, and active filter chips only when active.
    private var catalogueHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            statusCard
            if store.authorization == .limited {
                limitedAccessBanner
            }
            filterBar
            if hasActiveFilters {
                activeFilterChips
            }
            if filterCriteria.finding == .copies { exactBatchSelection }
            if hasActiveFilters && filterCriteria.finding == .all { selectListButton }
            attentionRows
            TipView(PreviewPhotoTip())
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            LiquidGlassFilterButton(activeFilterCount: filterCriteria.activeFilterBadgeCount) {
                isFilterSheetPresented = true
            }
            Spacer()
            if hasActiveFilters {
                Button(action: resetFilters) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                        Text(L10n.tr("Reset Filters"))
                            .font(.system(.caption, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(MobileKeptoraDesign.secondaryInk)
                    .padding(.horizontal, 10)
                    .frame(minWidth: MobileKeptoraDesign.minimumTouchTarget, minHeight: MobileKeptoraDesign.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(L10n.tr("Reset Filters"))
                .accessibilityHint(L10n.tr("Clears active filters and restores full list view"))
                .accessibilityIdentifier("archive.resetFilters")
            }
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            (typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8)) : AnyLayout(HStackLayout(alignment: .center, spacing: 10))) {
                Button { sources = true } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(store.connectedSources.filter { store.selectedSourceIDs.contains($0.id) }.map(\.localizedScanTitle).joined(separator: " · "))
                                .font(.subheadline.weight(.semibold)).lineLimit(typeSize.isAccessibilitySize ? 3 : 1)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                        }
                        catalogueCount
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("Sources"))
                .accessibilityValue(Text(L10n.format("%lld selected", store.selectedSourceIDs.count)))
                .accessibilityIdentifier("archive.sourcesSummary")
                HStack(spacing: 8) { scanButtons }
                    .disabled(store.isCleaningUp || store.isLoadingCatalogue)
            }
            if case .scanning(let processed, let total, let current) = store.scanState {
                ProgressView(value: Double(processed), total: Double(max(total, 1)))
                    .accessibilityValue(Text(current))
                Text("Scanning your photos. You can select ready results.").font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
            } else if store.isAnalyzing {
                Text("Scanning your photos. You can select ready results.").font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
            } else if case .paused = store.scanState {
                Text("Scan paused.").font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
            } else if store.scanState == .completed && store.sessionProgress.isComplete {
                scanResults
            }
        }
        .padding(14)
        .keptoraMobileGlass(cornerRadius: 16, tint: MobileKeptoraDesign.accent)
    }

    private var scanResults: some View {
        let scope = Set(store.scopedAssets.map(\.id))
        let extraCopies = store.exactSuggestionCandidates(visibleIDs: scope)
        let extraBytes = extraCopies.reduce(Int64(0)) { $0 + ($1.byteCount ?? 0) }
        let anyFinding = !extraCopies.isEmpty || !store.reviewGroups.isEmpty || store.qualityAssessments.values.contains { $0.needsReview }
        return VStack(alignment: .leading, spacing: 4) {
            Label("Scan complete. Choose what to keep.", systemImage: "checkmark.circle.fill").font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
            if !anyFinding {
                Text("No copies or similar photos found.").font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
            }
            if !extraCopies.isEmpty {
                Button { filterCriteria.finding = .copies } label: {
                    HStack {
                        Label(L10n.format("Extra copies: %lld · %@", extraCopies.count, ByteCountFormatter.string(fromByteCount: extraBytes, countStyle: .file)), systemImage: "square.on.square")
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(MobileKeptoraDesign.accent)
                .font(.subheadline.weight(.semibold))
                .accessibilityIdentifier("archive.results.copies")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("archive.results")
    }

    @ViewBuilder private var scanButtons: some View {
        if store.scanState.isScanning || store.isAnalyzing {
            Button("Pause Scan") { store.suspendScanForBackground() }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent))
            Menu { Button("Cancel Scan") { store.cancelScan() } } label: {
                Image(systemName: "ellipsis.circle").frame(width: 44, height: 44).contentShape(Rectangle())
            }.accessibilityLabel("Scan Options")
        } else if store.scanState == .paused {
            Button("Resume Scan") { store.startScan(allowNetwork: store.lastScanAllowedNetwork) }
                .buttonStyle(MobilePrimaryButtonStyle()).disabled(!store.canScanSelectedSources)
        } else {
            if store.scanState == .completed {
                Button("Scan Again") { store.startScan() }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent))
                    .accessibilityIdentifier("archive.scanAll").disabled(!store.canScanSelectedSources)
            } else {
                Button("Start Scan") { store.startScan() }.buttonStyle(MobilePrimaryButtonStyle())
                    .accessibilityIdentifier("archive.scanAll").disabled(!store.canScanSelectedSources)
            }
            if store.skippedCloudItems > 0 {
                Menu { Button("Include Cloud Originals") { cloudScan = true } } label: {
                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Scan Options").disabled(!store.canScanSelectedSources)
            }
        }
    }

    private var catalogueCount: some View {
        HStack {
            Text(L10n.plural("In this list: %lld items", visible.count))
                .font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk).accessibilityIdentifier("archive.visibleCount")
                .contentTransition(.numericText())
                .animation(.snappy, value: visible.count)
            if store.isLoadingCatalogue { ProgressView() }
        }
    }

    private var selectListButton: some View {
        Button { store.selectLibraryItems(visible) } label: { Text(L10n.format("Select This List (%lld)", visible.count)) }
            .buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent))
            .disabled(visible.isEmpty || store.isCleaningUp).accessibilityIdentifier("archive.selectAll")
    }

    private var activeFilterChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
            if filterCriteria.finding != .all {
                filterChip(Self.shortTitle(filterCriteria.finding), id: "finding") {
                    filterCriteria.finding = .all
                }
            }
            if filterCriteria.media != 0 {
                filterChip(L10n.tr(filterCriteria.media == 1 ? "Photos" : "Videos"), id: "media") {
                    filterCriteria.media = 0
                }
            }
            if !filterCriteria.albumID.isEmpty {
                filterChip(store.albums.first { $0.id == filterCriteria.albumID }?.title ?? L10n.tr("Album"), id: "album") {
                    filterCriteria.albumID = ""
                }
            }
            if filterCriteria.favouritesOnly {
                filterChip(L10n.tr("Favorites Only"), id: "favorites") {
                    filterCriteria.favouritesOnly = false
                }
            }
            if filterCriteria.dateRangeEnabled {
                filterChip(L10n.tr("Date Range"), id: "date") {
                    filterCriteria.dateRangeEnabled = false
                }
            }
            if !search.isEmpty {
                filterChip(L10n.format("Search: %@", search), id: "search") {
                    search = ""
                }
            }
            if filterCriteria.largestFirst || store.libraryCollectionSortBySize {
                filterChip(L10n.tr("Largest First"), id: "size") {
                    filterCriteria.largestFirst = false
                    store.libraryCollectionSortBySize = false
                }
            }
            if filterCriteria.oldestFirst {
                filterChip(L10n.tr("Oldest First"), id: "oldest") {
                    filterCriteria.oldestFirst = false
                }
            }
            if store.libraryCollectionIDs != nil {
                filterChip(store.libraryCollectionTitle ?? L10n.tr("Suggestions"), id: "collection") {
                    store.libraryCollectionIDs = nil
                    store.libraryCollectionTitle = nil
                    store.libraryCollectionKind = nil
                    store.libraryCollectionSortBySize = false
                }
            }
        }
    }

    private var hasActiveFilters: Bool {
        filterCriteria.hasActiveFilters || !search.isEmpty || store.libraryCollectionSortBySize || store.libraryCollectionIDs != nil
    }

    private func filterChip(_ title: String, id: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack {
                Text(title)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 4)
                Image(systemName: "xmark.circle.fill")
            }
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(minWidth: 44, minHeight: 44)
            .background(MobileKeptoraDesign.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
            .contentShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(L10n.format("Remove Filter: %@", title)))
        .accessibilityIdentifier("archive.filter.remove." + id)
    }

    private func dateMatches(_ asset: UniversalMediaAsset) -> Bool {
        guard let date = asset.context?.captureDate ?? asset.creationDate else { return false }
        let lower = Calendar.current.startOfDay(for: filterCriteria.fromDate)
        let upper = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: filterCriteria.toDate)) ?? filterCriteria.toDate
        return date >= lower && date < upper
    }

    private func resetFilters() {
        filterCriteria.reset()
        search = ""
        store.libraryCollectionIDs = nil
        store.libraryCollectionTitle = nil
        store.libraryCollectionKind = nil
        store.libraryCollectionSortBySize = false
    }

    private static func shortTitle(_ option: LibraryFindingFilter) -> String {
        switch option {
        case .all: return L10n.tr("All")
        case .copies: return L10n.tr("Copies")
        case .verySimilar: return L10n.tr("Very Similar")
        case .bursts: return L10n.tr("Bursts")
        case .review: return L10n.tr("Review")
        }
    }

    @ViewBuilder private var attentionRows: some View {
        if let error = store.similarityError ?? store.videoSimilarityError {
            Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(MobileKeptoraDesign.warning)
        }
        if store.skippedCloudItems > 0 {
            Text(L10n.format("%lld originals could not be analyzed. They remain in the library.", store.skippedCloudItems)).font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
        }
        if store.scanState == .completed && store.sessionProgress.isFinished && !store.sessionProgress.isComplete {
            Label("Analysis partially completed. Some items need attention.", systemImage: "exclamationmark.triangle").font(.caption)
        }
        if !store.analysisIssues.isEmpty {
            DisclosureGroup("Items needing attention") {
                ForEach(AnalysisIssueReason.allCases, id: \.rawValue) { reason in
                    let count = Set(store.analysisIssues.filter { $0.reason == reason }.map(\.assetID)).count
                    if count > 0 { HStack { Text(LocalizedStringKey(reason.titleKey)); Spacer(); Text(count.formatted()) }.font(.caption) }
                }
            }
        }
        if store.authorization == .limited {
            Button("Limited Photos access · Manage Access") { store.manageLimitedPhotosAccess() }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent))
        }
    }

    private var exactBatchSelection: some View {
        let scope = Set(visible.map(\.id))
        let candidates = store.exactSuggestionCandidates(visibleIDs: scope)
        let remaining = candidates.filter { !store.selectedLibraryIDs.contains($0.id) }.count
        return Group {
            if !candidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button {
                        if !store.selectExactSuggestions(isUnlocked: purchase.isUnlocked, visibleIDs: scope) { store.present(.paywall) }
                    } label: {
                        if remaining == 0 { Text("Extra Copies Selected") }
                        else { Text(L10n.format("Select Extra Copies (%lld)", remaining)) }
                    }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent)).disabled(remaining == 0)
                        .accessibilityIdentifier("archive.selectExtraCopies")
                    Text("Items suggested to keep and protected items stay unselected.").font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                }
            }
        }.disabled(store.isCleaningUp || store.isLoadingCatalogue || store.scanState.isScanning || store.isAnalyzing)
    }

    private func sectionHeader(_ section: (date: Date, assets: [UniversalMediaAsset])) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: MobileKeptoraDesign.actionSpacing) { sectionHeaderContents(section) }
            VStack(alignment: .leading, spacing: MobileKeptoraDesign.stackedActionSpacing) { sectionHeaderContents(section) }
        }
    }

    @ViewBuilder private func sectionHeaderContents(_ section: (date: Date, assets: [UniversalMediaAsset])) -> some View {
        Text(section.date == .distantFuture ? L10n.tr(filterCriteria.largestFirst || store.libraryCollectionSortBySize ? "Largest First" : "All Items") : section.date == .distantPast ? L10n.tr("Date unknown") : (filterCriteria.grouping == 1 ? section.date.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: L10n.currentLocale)) : section.date.formatted(.dateTime.locale(L10n.currentLocale).month(.wide).year())))
            .font(.headline)
        Button(section.date == .distantFuture ? "Select All in This View" : filterCriteria.grouping == 1 ? "Select Day" : "Select Month") { store.selectLibraryItems(section.assets) }
            .buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent))
    }

    private func cell(_ asset: UniversalMediaAsset, groups: [LibraryReviewGroup] = [], keeperBadge: String? = nil) -> some View {
        let selected = store.selectedLibraryIDs.contains(asset.id)
        let kept = !selected && keeperBadge != nil
        let keeperLabel = keeperBadge ?? "Suggested Keep"
        var spoken = [asset.displayName, store.sourceLabel(asset)]
        if let finding = store.qualityAssessments[asset.id]?.findings.first { spoken.append(L10n.tr(String.LocalizationValue(finding.titleKey))) }
        if kept { spoken.append(L10n.tr(String.LocalizationValue(keeperLabel))) }
        if store.decisions.protectedIDs.contains(asset.id) { spoken.append(L10n.tr("Protected")) }

        return ZStack(alignment: .bottomLeading) {
            Button {
                MobileTips.recordSelectionChange()
                store.toggleLibrarySelection(asset)
            } label: {
                selectionThumbnail(asset, selected: selected, keeperLabel: kept ? keeperLabel : nil)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spoken.joined(separator: ", "))
            .accessibilityValue(Text(selected ? LocalizedStringKey("Selected") : LocalizedStringKey("Not selected")))
            .accessibilityHint(L10n.tr("Tap to change selection"))
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("archive.asset.\(asset.id)")

            if !groups.isEmpty && !kept {
                Button {
                    store.keep(asset, in: groups)
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8, weight: .bold))
                        Text("Keep This")
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .foregroundStyle(MobileKeptoraDesign.mint)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.ultraThinMaterial, in: Capsule())
                    .overlay(Capsule().stroke(MobileKeptoraDesign.mint.opacity(0.35), lineWidth: 0.8))
                    .frame(minHeight: MobileKeptoraDesign.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(4)
                .disabled(store.scanState.isScanning || store.isAnalyzing)
                .accessibilityIdentifier("archive.keep.\(asset.id)")
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(minWidth: 0, maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .clipped()
        .disabled(store.isCleaningUp)
        .contextMenu {
            Button(LocalizedStringKey("View Large"), systemImage: "arrow.up.left.and.arrow.down.right") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    previewAsset = asset
                }
            }
            if !groups.isEmpty && !kept {
                Button("Keep This", systemImage: "star.fill") {
                    store.keep(asset, in: groups)
                }
            }
            if store.decisions.protectedIDs.contains(asset.id) {
                Button("Unprotect and Select", systemImage: "lock.open") {
                    MobileTips.recordSelectionChange()
                    store.unprotectAndSelect(asset)
                }
            } else {
                Button(selected ? "Deselect" : "Select", systemImage: selected ? "circle" : "checkmark.circle") {
                    PreviewPhotoTip().invalidate(reason: .actionPerformed)
                    MobileTips.recordSelectionChange()
                    store.toggleLibrarySelection(asset)
                }
            }
            Button(store.decisions.protectedIDs.contains(asset.id) ? "Unprotect Photo" : "Protect Photo",
                   systemImage: store.decisions.protectedIDs.contains(asset.id) ? "lock.open" : "lock") { store.toggleProtection(asset) }
            ForEach(groups) { group in
                Button("Protect Group", systemImage: "lock.rectangle.stack") { store.protect(group) }
            }
        } preview: {
            Button {
                previewAsset = asset
            } label: {
                MobileAssetPreview(asset: asset, sourceLabel: store.sourceLabel(asset))
            }
            .buttonStyle(.plain)
        }
    }

    private var limitedAccessBanner: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "photo.badge.exclamationmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(MobileKeptoraDesign.warning)
                Text(LocalizedStringKey("Limited Photos Access"))
                    .font(.subheadline.weight(.semibold))
            }
            Text(LocalizedStringKey("Allow Keptora full access to find duplicate and similar shots across your whole library."))
                .font(.caption)
                .foregroundStyle(MobileKeptoraDesign.secondaryInk)
            HStack(spacing: 10) {
                Button(LocalizedStringKey("Allow Full Access")) {
                    store.openPhotosSettings()
                }
                .buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent))

                Button(LocalizedStringKey("Select More Photos")) {
                    store.manageLimitedPhotosAccess()
                }
                .buttonStyle(MobileSleekActionButtonStyle(tint: Color.secondary))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keptoraMobileGlass(cornerRadius: 16, tint: MobileKeptoraDesign.warning)
    }

    private func selectionThumbnail(_ asset: UniversalMediaAsset, selected: Bool, keeperLabel: String?) -> some View {
        let isKeeper = keeperLabel != nil
        return ZStack(alignment: .bottomTrailing) {
            Color(uiColor: .secondarySystemFill)
            MobileAssetThumbnail(asset: asset, contentMode: .fill, showsRetryButton: false)
                .accessibilityHidden(true)
                .overlay(selected ? Color.black.opacity(0.28) : .clear)
                .allowsHitTesting(false)
            thumbnailBadges(asset, keeperLabel: keeperLabel).allowsHitTesting(false)
            thumbnailSelectionIndicator(asset, selected: selected).allowsHitTesting(false)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipped()
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selected ? MobileKeptoraDesign.accent : (isKeeper ? MobileKeptoraDesign.mint.opacity(0.55) : Color.white.opacity(0.12)),
                        lineWidth: selected ? 3 : (isKeeper ? 2 : 1))
        )
    }

    private func thumbnailBadges(_ asset: UniversalMediaAsset, keeperLabel: String?) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(LocalizedStringKey(asset.sourceBadgeKey(in: store.connectedSources)), systemImage: asset.sourceBadgeSymbol(in: store.connectedSources))
                .font(.caption2.weight(.semibold)).lineLimit(1).padding(.horizontal, 5).padding(.vertical, 3)
                .foregroundStyle(.white).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4))
            if let issue = store.qualityAssessments[asset.id]?.findings.first {
                Label(LocalizedStringKey(issue.titleKey), systemImage: issue.symbol).font(.caption2).lineLimit(1).padding(4)
                    .foregroundStyle(.white).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4))
            }
            if store.decisions.protectedIDs.contains(asset.id) { Image(systemName: "lock.fill").foregroundStyle(.white) }
            if let keeperLabel {
                Label(LocalizedStringKey(keeperLabel), systemImage: "bookmark.fill")
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(4)
                    .foregroundStyle(.white)
                    .background(MobileKeptoraDesign.mintFill.opacity(0.94), in: RoundedRectangle(cornerRadius: 4))
            }
            Spacer()
        }.padding(5).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func thumbnailSelectionIndicator(_ asset: UniversalMediaAsset, selected: Bool) -> some View {
        HStack {
            if asset.isFavorite || asset.mediaKind == .video {
                HStack(spacing: 4) {
                    if asset.isFavorite { Image(systemName: "heart.fill") }
                    if asset.mediaKind == .video { Label(asset.formattedDuration, systemImage: "play.fill") }
                }
            }
            Spacer()
            Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title2)
                .foregroundStyle(selected ? MobileKeptoraDesign.accent : .white)
        }
        .font(.caption2.weight(.semibold)).foregroundStyle(.white)
        .padding(8).background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
    }

    private func groupActions(_ group: LibraryReviewGroup, candidates: [UniversalMediaAsset], itemCount: Int) -> some View {
        let remaining = candidates.filter { !store.selectedLibraryIDs.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 8) {
            Text(L10n.format("%@ · %lld items", L10n.tr(String.LocalizationValue(group.titleKey)), itemCount)).font(.caption.weight(.semibold))
            Text(LocalizedStringKey(store.decisions.keeperReason(in: group, quality: store.qualityAssessments))).font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: MobileKeptoraDesign.actionSpacing) { groupButtons(group, candidates: candidates, remaining: remaining) }
                VStack(alignment: .leading, spacing: MobileKeptoraDesign.stackedActionSpacing) { groupButtons(group, candidates: candidates, remaining: remaining) }
            }
        }.disabled(store.isCleaningUp || store.scanState.isScanning || store.isAnalyzing)
    }

    @ViewBuilder private func groupButtons(_ group: LibraryReviewGroup, candidates: [UniversalMediaAsset], remaining: Int) -> some View {
        Button {
            if !store.selectOthers(in: group, isUnlocked: purchase.isUnlocked, visibleIDs: Set(candidates.map(\.id))) { store.present(.paywall) }
        } label: {
            if candidates.isEmpty { Text("No Other Items to Select") }
            else if remaining == 0 { Text("Others Selected") }
            else { Text(L10n.format("Select Others (%lld)", remaining)) }
        }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent)).disabled(remaining == 0).accessibilityIdentifier("archive.others.\(group.id)")
    }

    private var selectionBar: some View {
        VStack(spacing: 10) {
            let summaryLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            summaryLayout {
                let summary = MediaSelectionSummary(store.librarySelection)
                VStack(alignment: .leading, spacing: 4) {
                    Text(typeSize.isAccessibilitySize ? L10n.format("%lld selected", store.selectedLibraryIDs.count)
                         : L10n.format("Selected items: %lld", store.selectedLibraryIDs.count)).font(.headline)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: store.selectedLibraryIDs.count)
                    if !typeSize.isAccessibilitySize {
                        Text(L10n.format("Photos: %lld · Videos: %lld", summary.photos, summary.videos)).font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                    }
                    let hidden = store.selectedLibraryIDs.subtracting(visible.map(\.id)).count
                    if hidden > 0 { Text(L10n.format("%lld selected outside this view", hidden)).font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk) }
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                    Text(ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file)).font(.subheadline.weight(.semibold))
                        .contentTransition(.numericText())
                        .animation(.snappy, value: summary.knownBytes)
                    if !typeSize.isAccessibilitySize {
                        Text("Space is not freed right away").font(.caption2).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                        if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.caption2).foregroundStyle(MobileKeptoraDesign.secondaryInk) }
                    }
                }
            }
            if typeSize.isAccessibilitySize {
                VStack(spacing: MobileKeptoraDesign.stackedActionSpacing) { secondarySelectionButtons }
            } else {
                HStack(spacing: MobileKeptoraDesign.actionSpacing) { secondarySelectionButtons }
            }
            Button { reviewSelection = true } label: { Text(L10n.format("Review Selection (%lld)", store.selectedLibraryIDs.count)) }
                .buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true)).disabled(store.selectedLibraryIDs.isEmpty)
                .accessibilityIdentifier("archive.reviewSelection")
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            LinearGradient(
                colors: [Color.white.opacity(0.30), Color.white.opacity(0.04)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 1)
        }
        .shadow(color: Color.black.opacity(0.06), radius: 14, y: -4)
        .disabled(store.isCleaningUp)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("archive.selectionBar")
    }

    @ViewBuilder private var secondarySelectionButtons: some View {
        if store.canUndoLibrarySelection {
            Button {
                UndoSelectionTip().invalidate(reason: .actionPerformed)
                store.undoLibrarySelection()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                    Text(typeSize.isAccessibilitySize ? LocalizedStringKey("Undo") : LocalizedStringKey("Undo Selection"))
                }
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
            }
            .buttonStyle(MobileSleekActionButtonStyle(fillsWidth: true, tint: MobileKeptoraDesign.accent))
            .accessibilityIdentifier("archive.undoSelection")
            .popoverTip(UndoSelectionTip())
        }
        Button {
            store.replaceLibrarySelection([])
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "xmark.circle")
                    .font(.system(.caption, design: .rounded).weight(.bold))
                Text(typeSize.isAccessibilitySize ? LocalizedStringKey("Clear") : LocalizedStringKey("Clear All Selections"))
            }
            .font(.system(.subheadline, design: .rounded).weight(.semibold))
        }
        .buttonStyle(MobileSleekActionButtonStyle(fillsWidth: true, tint: MobileKeptoraDesign.secondaryInk))
        .disabled(store.selectedLibraryIDs.isEmpty)
        .accessibilityIdentifier("archive.clearSelection")
    }
}

struct MobileSelectionReviewSheet: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @State private var confirm = false
    @State private var capturedIDs: Set<String> = []
    @State private var completed = false
    @State private var review = FrozenSelectionReview()
    @State private var captured = false
    @State private var leaveLinkedFiles = false
    @State private var isExecutingCleanup = false
    private var reviewedItems: [UniversalMediaAsset] { review.items }
    private var summary: MediaSelectionSummary { MediaSelectionSummary(reviewedItems) }
    private var hasUnavailableSelection: Bool {
        !store.unresolvedSelectionIDs.intersection(store.selectedLibraryIDs).isEmpty
            || store.pendingSelection.contains { store.selectedLibraryIDs.contains($0.id) }
    }
    var body: some View {
        NavigationStack {
            List {
                // Order: what is selected, anything blocking removal, the items themselves, then where they go.
                Section {
                    Text(L10n.format("Photos: %lld · Videos: %lld", summary.photos, summary.videos)).font(.title2.bold())
                    Text(ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file) + " · " + L10n.tr("Space is not freed right away")).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                    if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.footnote) }
                    if summary.personalItems > 0 { Label("Includes favorites, hidden, edited or shared items you selected manually.", systemImage: "exclamationmark.triangle").font(.footnote) }
                    let reviewedIDs = Set(reviewedItems.map(\.id))
                    if store.exactGroups.contains(where: { $0.assets.allSatisfy { reviewedIDs.contains($0.id) } }) {
                        Label("Every item in a known duplicate group is selected.", systemImage: "exclamationmark.triangle")
                    }
                }
                .mobileGlassRow()

                if hasUnavailableSelection {
                    Section("Unavailable Selected Items") {
                        Text("Reconnect unavailable sources or remove their items from your selection.")
                        Button("Remove Unavailable Items from Selection") {
                            review.discard(Set(store.pendingSelection.map(\.id)).union(store.unresolvedSelectionIDs))
                            store.discardPendingSelection()
                        }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.danger))
                    }
                    .mobileGlassRow(tint: MobileKeptoraDesign.danger)
                }

                if !LibraryFileFamilies.omittedCompanions(for: reviewedItems).isEmpty {
                    Section("Linked Files") {
                        Text("Linked files remain outside your selection. Review them before removing this photo.")
                        ForEach(LibraryFileFamilies.omittedCompanions(for: reviewedItems), id: \.self) { url in Text(url.lastPathComponent).font(.caption) }
                        Toggle("Remove only my selected items and leave linked files in place", isOn: $leaveLinkedFiles)
                    }
                    .mobileGlassRow()
                }

                Section("Selected Items") {
                    Text("Removing an item from this list keeps it in your library.").font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                    if reviewedItems.isEmpty { Text("No items selected.").foregroundStyle(MobileKeptoraDesign.secondaryInk) }
                    ForEach(reviewedItems) { asset in
                        reviewRow(asset)
                    }
                }
                .mobileGlassRow()

                Section("Removal by Source") {
                    ForEach(store.connectedSources) { source in
                        let items = reviewedItems.filter { $0.sourceID == source.id }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.localizedScanTitle + " · " + items.count.formatted(.number.locale(L10n.currentLocale)))
                                Text(source.kind == .photos ? LocalizedStringKey("Recently Deleted in Photos") : LocalizedStringKey("Recovery Folder")).font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                            }
                        }
                    }
                    DisclosureGroup("Recovery Details") {
                        Text("Photos items move to Recently Deleted and iCloud changes sync across devices. Files move to a recovery folder on the same storage; this does not free disk space. Completed steps appear in History if cleanup stops partway.").font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                    }
                }
                .mobileGlassRow()
            }
            .scrollContentBackground(.hidden)
            .background(MobileAuroraBackground())
            .disabled(store.isCleaningUp)
            .navigationTitle("Review Selection").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(store.isCleaningUp).accessibilityIdentifier("archive.review.close") } }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if store.isCleaningUp { ProgressView(store.cleanupStatus ?? L10n.tr("Removing selected items…")) }
                    Text(L10n.format("Selected items: %lld", reviewedItems.count)).font(.headline)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: reviewedItems.count)
                    if review.canUndoRemoval {
                        Button("Undo Review Change") {
                            if let asset = review.undoRemoval() { store.replaceLibrarySelection(store.selectedLibraryIDs.union([asset.id])) }
                        }.buttonStyle(MobileSleekActionButtonStyle(fillsWidth: true, tint: MobileKeptoraDesign.accent)).disabled(store.isCleaningUp).accessibilityIdentifier("archive.review.undo")
                    }
                    Button(role: .destructive) {
                        capturedIDs = Set(reviewedItems.map(\.id)); confirm = true
                    } label: { Text(L10n.plural("Remove %lld Items", reviewedItems.count)) }
                        .buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true, tint: MobileKeptoraDesign.dangerFill)).accessibilityIdentifier("archive.review.remove")
                        .disabled((!leaveLinkedFiles && !LibraryFileFamilies.omittedCompanions(for: reviewedItems).isEmpty) || reviewedItems.isEmpty || hasUnavailableSelection || store.isCleaningUp || store.scanState.isScanning || store.isAnalyzing)
                    if store.scanState.isScanning || store.isAnalyzing { Text("Wait for analysis to finish or cancel it before cleanup.").font(.footnote) }
                    else if hasUnavailableSelection { Text("Remove unavailable items from your selection to continue.").font(.footnote) }
                    else if !reviewedItems.isEmpty && !leaveLinkedFiles && !LibraryFileFamilies.omittedCompanions(for: reviewedItems).isEmpty {
                        Text("Review the linked files above to continue.").font(.footnote)
                    }
                }
                .padding(16)
                .background {
                    if reduceTransparency {
                        Color(uiColor: .systemBackground)
                    } else {
                        Rectangle().fill(.ultraThinMaterial)
                    }
                }
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.28 : 0.60), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 1)
                }
                .accessibilityElement(children: .contain).accessibilityIdentifier("archive.review.actions")
            }
            .onChange(of: reviewedItems) { _, _ in leaveLinkedFiles = false }
            .onAppear { if !captured { review = FrozenSelectionReview(store.librarySelection); captured = true } }
            .interactiveDismissDisabled(store.isCleaningUp)
            .alert(Text(store.errorAlertParts.title), isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { DispatchQueue.main.async { store.errorMessage = nil } } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { if let detail = store.errorAlertParts.detail { Text(detail) } }
            .alert("Remove selected items?", isPresented: $confirm) {
                Button(role: .destructive) {
                    guard !isExecutingCleanup else { return }
                    isExecutingCleanup = true
                    Task {
                        defer { isExecutingCleanup = false }
                        completed = await store.cleanupLibrarySelection(expectedIDs: capturedIDs, reviewedAssets: reviewedItems, allowPartialFamilies: leaveLinkedFiles)
                    }
                } label: { Text(L10n.plural("Remove %lld Items", capturedIDs.count)) }
                .disabled(isExecutingCleanup)
                Button("Cancel", role: .cancel) { }
            } message: { Text("Only the items listed here will be removed. Review the destination and recovery conditions before continuing.") }
            .alert("Cleanup Completed", isPresented: $completed) {
                Button("View in History") { store.selectedTab = .history; dismiss() }
                Button("Done") { dismiss() }
            } message: {
                Text("Photos items move to Recently Deleted and iCloud changes sync across devices. Files move to a recovery folder on the same storage; this does not free disk space. Completed steps appear in History if cleanup stops partway.")
            }
            .sensoryFeedback(.success, trigger: completed) { _, new in new == true }
        }
    }
    @ViewBuilder private func reviewRow(_ asset: UniversalMediaAsset) -> some View {
        if typeSize.isAccessibilitySize {
            VStack(alignment: .leading, spacing: 12) { reviewDetails(asset); excludeButton(asset) }
        } else {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { reviewDetails(asset); excludeButton(asset) }
                VStack(alignment: .leading, spacing: 12) { reviewDetails(asset); excludeButton(asset) }
            }
        }
    }
    private func reviewDetails(_ asset: UniversalMediaAsset) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MobileAssetThumbnail(asset: asset, showsRetryButton: false).frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(asset.displayName).lineLimit(1).truncationMode(.middle)
                Text(store.sourceLabel(asset)).font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                if let date = asset.captureDateDescription { Text(date).font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk) }
            }
        }
    }
    private func excludeButton(_ asset: UniversalMediaAsset) -> some View {
        Button {
            if review.remove(asset.id) { store.replaceLibrarySelection(store.selectedLibraryIDs.subtracting([asset.id])) }
        } label: {
            // The standard iOS remove icon leaves the row's width to the file name.
            Image(systemName: "minus.circle.fill").font(.title2).foregroundStyle(MobileKeptoraDesign.danger)
                .frame(minWidth: 48, minHeight: 48).contentShape(Rectangle())
        }
            .buttonStyle(.plain).accessibilityLabel("Remove from selection")
            .accessibilityHint("This item will stay in your library.")
            .accessibilityIdentifier("archive.review.exclude." + asset.id)
    }
}

struct MobileCleanupHubView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.dynamicTypeSize) private var typeSize
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // The navigation title already names the screen; one short line explains it.
                Text("Open a category to choose photos.").foregroundStyle(MobileKeptoraDesign.secondaryInk)
                if store.connectedSources.isEmpty {
                    NavigationLink { MobileSourceLibraryView() } label: {
                        Label("Connect your library", systemImage: "folder.badge.plus")
                    }.buttonStyle(MobilePrimaryButtonStyle())
                } else {
                    NavigationLink { MobileSourceLibraryView() } label: { Label("Sources", systemImage: "checklist") }.buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.accent))
                }
                if store.scanState.isScanning || store.isAnalyzing {
                    ProgressView("Analyzing your library…")
                    HStack(spacing: 8) {
                        Button("Pause Scan") { store.suspendScanForBackground() }.buttonStyle(MobileSleekActionButtonStyle(fillsWidth: true, tint: MobileKeptoraDesign.accent))
                        Menu { Button("Cancel Scan") { store.cancelScan() } } label: { Label("Cancel", systemImage: "xmark.circle") }
                            .buttonStyle(MobileSleekActionButtonStyle(tint: MobileKeptoraDesign.danger))
                    }
                } else if store.scanState == .paused {
                    Text("Scan paused.").font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                    Button("Resume Scan") { store.startScan(allowNetwork: store.lastScanAllowedNetwork) }.buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true))
                } else if store.scanState == .completed {
                    // Results exist; scanning again is a secondary action.
                    Button("Scan Again") { store.startScan() }
                        .buttonStyle(MobileSleekActionButtonStyle(fillsWidth: true, tint: MobileKeptoraDesign.accent)).disabled(!store.canScanSelectedSources)
                } else {
                    Button("Start Scan") { store.startScan() }
                        .buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true)).disabled(!store.canScanSelectedSources)
                }
                collection("Screenshots", icon: "viewfinder", items: store.scopedAssets.filter { $0.context?.isScreenshot == true })
                collection("Screen Recordings", icon: "record.circle", items: store.scopedAssets.filter { $0.mediaKind == .video && ($0.displayName.localizedCaseInsensitiveContains("screen recording") || $0.displayName.localizedCaseInsensitiveContains("screen_recording") || $0.displayName.localizedCaseInsensitiveContains("RPReplay") || $0.context?.isScreenshot == true) })
                collection("Videos by Size", icon: "video", items: store.scopedAssets.filter { $0.mediaKind == .video }.sorted { ($0.byteCount ?? 0) > ($1.byteCount ?? 0) })
                if store.scopedAssets.contains(where: { $0.mediaKind == .video && $0.byteCount == nil }) { Text("Items with unknown size appear after measured items.").font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk) }
                collection("Rapid Bursts", icon: "square.stack.3d.down.right.fill", items: UnifiedLibraryAdapter.uniqueReferences(store.burstGroups.flatMap { $0.assets }), needsScan: true)
                collection("Live Photos", icon: "livephoto", items: store.scopedAssets.filter { $0.context?.isLivePhoto == true })
                collection("Duplicates & Similar Photos", icon: "square.on.square", items: UnifiedLibraryAdapter.uniqueReferences(store.reviewGroups.flatMap { $0.assets }), needsScan: true)
                collection("Worth Reviewing", icon: "camera.metering.center.weighted", items: store.scopedAssets.filter { store.qualityAssessments[$0.id]?.needsReview == true }, needsScan: true)
                if store.skippedSimilarityPreviews > 0 {
                    Text(L10n.format("%lld previews could not be analyzed. Results cover only accessible items.", store.skippedSimilarityPreviews)).font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                }
                if let error = store.similarityError ?? store.videoSimilarityError {
                    Label("Some analysis could not be completed", systemImage: "exclamationmark.triangle").font(.headline)
                    Text(error).font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                }
            }.padding(18)
        }
        .background {
            MobileAuroraBackground()
        }
        .navigationTitle("Suggestions")
    }
    /// Scan-based categories stay empty until analysis runs; say so instead of showing a bare 0.
    private var hasAnalysisResults: Bool {
        store.scanState == .completed || store.scanState.isScanning || store.isAnalyzing || !store.reviewGroups.isEmpty || !store.qualityAssessments.isEmpty
    }
    private func collectionSubtitle(_ count: Int, needsScan: Bool) -> String {
        if count > 0 { return count.formatted(.number.locale(L10n.currentLocale)) }
        return needsScan && !hasAnalysisResults ? L10n.tr("Start a scan to find these.") : L10n.tr("None found")
    }
    private func collection(_ title: String, icon: String, items: [UniversalMediaAsset], needsScan: Bool = false) -> some View {
        Button { store.openCollection(items, title: L10n.tr(String.LocalizationValue(title)), sortBySize: title == "Videos by Size", kind: title) } label: {
            HStack(spacing: 14) {
                // At accessibility sizes the icon would squeeze long titles into mid-word breaks.
                if !typeSize.isAccessibilitySize {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(items.isEmpty ? Color.secondary.opacity(0.12) : MobileKeptoraDesign.accent.opacity(0.14))
                        Image(systemName: icon)
                            .font(.system(.title3, design: .rounded).weight(.semibold))
                            .foregroundStyle(items.isEmpty ? Color.secondary : MobileKeptoraDesign.accent)
                    }
                    .frame(width: 38, height: 38)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title)).font(.headline)
                    Text(collectionSubtitle(items.count, needsScan: needsScan)).font(.subheadline).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                }
                Spacer(); if !items.isEmpty { Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(MobileKeptoraDesign.secondaryInk) }
            }
            .padding(16)
            .frame(maxWidth: .infinity)
            .keptoraMobileGlass(cornerRadius: 18, tint: MobileKeptoraDesign.accent)
        }.buttonStyle(.plain).disabled(store.isCleaningUp || items.isEmpty).accessibilityIdentifier("cleanup.collection." + title)
    }
}
