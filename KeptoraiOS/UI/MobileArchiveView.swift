import KeptoraCore
import SwiftUI

struct MobileLibraryView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @EnvironmentObject private var purchase: MobilePurchaseController
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var visibleAnchor: String?
    @State private var media = 0
    @State private var albumID = ""
    @State private var search = ""
    @State private var oldestFirst = false
    @State private var largestFirst = false
    @State private var grouping = 2
    @State private var finding: LibraryFindingFilter = .all
    @State private var smartOrder = true
    @State private var cloudScan = false
    @State private var dateFilters = false
    @State private var dateRangeEnabled = false
    @State private var fromDate = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
    @State private var toDate = Date()
    @State private var sources = false
    @State private var pendingFolderPicker = false
    @State private var reviewSelection = false
    @State private var favouritesOnly = false

    private var visible: [UniversalMediaAsset] {
        let findingIDs = finding.ids(groups: store.reviewGroups, quality: store.qualityAssessments)
        return store.scopedAssets.filter { asset in
            (findingIDs == nil || findingIDs!.contains(asset.id)) &&
            (media == 0 || (media == 1 ? asset.mediaKind == .image : asset.mediaKind == .video)) &&
            (albumID.isEmpty || asset.context?.albums.contains { $0.id == albumID } == true) &&
            (!favouritesOnly || asset.isFavorite) &&
            store.collectionContains(asset) &&
            (!dateRangeEnabled || dateMatches(asset)) &&
            (search.isEmpty || asset.displayName.localizedCaseInsensitiveContains(search) ||
             asset.context?.camera?.localizedCaseInsensitiveContains(search) == true)
        }.sorted {
            if largestFirst || store.libraryCollectionSortBySize {
                let a = $0.byteCount ?? -1, b = $1.byteCount ?? -1
                if a != b { return a > b }
            }
            let a = $0.context?.captureDate ?? $0.creationDate ?? .distantPast
            let b = $1.context?.captureDate ?? $1.creationDate ?? .distantPast
            return a == b ? $0.id < $1.id : (oldestFirst ? a < b : a > b)
        }
    }

    private var sections: [(date: Date, assets: [UniversalMediaAsset])] {
        let calendar = Calendar.current
        if largestFirst || store.libraryCollectionSortBySize || grouping == 0 { return [(date: .distantFuture, assets: visible)] }
        let grouped = Dictionary(grouping: visible) {
            guard let date = $0.context?.captureDate ?? $0.creationDate else { return Date.distantPast }
            return calendar.dateInterval(of: grouping == 1 ? .day : .month, for: date)?.start ?? .distantPast
        }
        return grouped.map { (date: $0.key, assets: $0.value) }.sorted { oldestFirst ? $0.date < $1.date : $0.date > $1.date }
    }

    var body: some View {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 18) {
                    libraryContent
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .scrollPosition(id: $visibleAnchor, anchor: .top)
            .refreshable { await store.loadCatalogue() }
        .background(MobileKeptoraDesign.canvas)
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
        }
        .safeAreaInset(edge: .bottom) {
            if !store.selectedLibraryIDs.isEmpty || store.canUndoLibrarySelection { selectionBar }
        }
        .confirmationDialog("Download cloud originals?", isPresented: $cloudScan) {
            Button("Download and Scan") { store.startScan(allowNetwork: true) }
        } message: { Text("This may use network data and device storage. You can cancel the scan at any time.") }
        .sheet(isPresented: $sources, onDismiss: { if pendingFolderPicker { pendingFolderPicker = false; store.present(.filePicker) } }) { NavigationStack { MobileSourceLibraryView(onChooseFolder: { pendingFolderPicker = true; sources = false }).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { sources = false } } } } }
        .sheet(isPresented: $reviewSelection) { MobileSelectionReviewSheet() }
        .sheet(isPresented: $dateFilters) {
            NavigationStack {
                Form {
                    Toggle("Filter by Date", isOn: $dateRangeEnabled)
                    DatePicker("From", selection: $fromDate, in: ...toDate, displayedComponents: .date)
                    DatePicker("To", selection: $toDate, in: fromDate..., displayedComponents: .date)
                    Text("Dates use capture information when available, otherwise file creation dates.").font(.footnote).foregroundStyle(.secondary)
                }.navigationTitle("Date Range").toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dateFilters = false } } }
            }
        }
        .onChange(of: store.scanSourceSelection) { _, _ in finding = .all; albumID = ""; media = 0; search = ""; dateRangeEnabled = false; favouritesOnly = false; largestFirst = false }
        .onChange(of: store.connectedFolders) { _, _ in albumID = ""; media = 0; search = ""; dateRangeEnabled = false; favouritesOnly = false }
        .onChange(of: store.source) { _, _ in dateRangeEnabled = false; albumID = ""; search = "" }
        .onChange(of: store.libraryCollectionIDs) { _, ids in
            if ids != nil { albumID = ""; search = ""; media = 0; favouritesOnly = false; dateRangeEnabled = false; largestFirst = false }
        }
        .onChange(of: store.selectedLibraryIDs) { _, _ in store.saveLibrarySelection() }
        .sensoryFeedback(.selection, trigger: store.selectedLibraryIDs)
        .alert("Photos Access Needed", isPresented: Binding(get: { store.isShowingPhotosPermissionHelp && !sources }, set: { if !$0 { store.isShowingPhotosPermissionHelp = false } })) {
            if store.canOpenPhotosSettings { Button("Open Settings") { store.openPhotosSettings() }.accessibilityIdentifier("ios.photosPermission.openSettings") }
            Button("Not Now", role: .cancel) { store.isShowingPhotosPermissionHelp = false }.accessibilityIdentifier("ios.photosPermission.notNow")
        } message: { Text(store.photosPermissionHelpMessage) }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("ios.page.archive")
    }

    @ViewBuilder private var libraryContent: some View {
        if store.source == .none {
            welcome
        } else {
            catalogueHeader
            filters
            if let error = store.catalogueError {
                ContentUnavailableView {
                    Label("Library could not be loaded", systemImage: "exclamationmark.triangle")
                } description: { Text(error) } actions: {
                    Button("Try Again") { Task { await store.loadCatalogue() } }.buttonStyle(MobileActionButtonStyle())
                }
            } else if store.isLoadingCatalogue && store.assets.isEmpty {
                ProgressView("Loading your library…").frame(maxWidth: .infinity, minHeight: 180)
            } else if store.selectedSourceIDs.isEmpty {
                ContentUnavailableView {
                    Label("Select at least one source", systemImage: "checklist")
                } description: { Text("Open Sources and select at least one source.") }
                actions: { Button("Sources") { sources = true }.buttonStyle(MobileActionButtonStyle()) }
            } else if visible.isEmpty {
                if store.scanState.isScanning || store.isAnalyzing { Text("Results appear as they become available.").foregroundStyle(.secondary).padding(.vertical, 40) }
                else {
                ContentUnavailableView("No items in this view", systemImage: "photo", description: Text("Change the filters or choose another source."))
                Button("Reset Filters") { resetFilters() }.buttonStyle(MobileActionButtonStyle()).accessibilityIdentifier("archive.resetFilters")
                }
            } else if smartOrder {
                smartBlocksGallery
            } else {
                dateSectionsGallery
            }
        }
    }

    private var galleryColumns: [GridItem] {
        [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 150 : 106), spacing: 4)]
    }

    // Split out of `body` so newer Swift compilers can type-check the gallery in reasonable time.
    @ViewBuilder private var smartBlocksGallery: some View {
        let candidatesByGroup = store.decisions.candidatesByGroup(store.reviewGroups)
        let visibleIDs = Set(visible.map(\.id))
        let blocks = LibraryReviewBlock.make(assets: visible, groups: store.reviewGroups, quality: store.qualityAssessments, smart: true)
        ForEach(blocks) { block in
            let membership = block.groupsByAsset
            let keeperBadges = store.decisions.keeperBadgeKeys(in: block.groups)
            VStack(alignment: .leading, spacing: 10) {
                Text(LocalizedStringKey(block.titleKey)).font(.headline)
                LazyVGrid(columns: galleryColumns, spacing: 4) {
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
            LazyVGrid(columns: galleryColumns, spacing: 4) {
                ForEach(section.assets) { asset in cell(asset).id(asset.id) }
            }.scrollTargetLayout()
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image("onboarding_privacy").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
            Text("Your photos. Your choice.").font(.largeTitle.bold())
            Text("Browse every photo, select what you no longer need, and review before removing anything.").foregroundStyle(.secondary)
            Button("Open Photos") { Task { await store.connectPhotos() } }
                .accessibilityIdentifier("library.source.photos")
                .buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true))
            Button("Choose a Folder") { store.present(.filePicker) }.accessibilityIdentifier("library.source.files").buttonStyle(MobileActionButtonStyle(fillsWidth: true))
            Text("Private processing on your device. No account required.").font(.footnote).foregroundStyle(.secondary)
        }.padding(8)
    }

    private var catalogueHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Selecting a whole list only makes sense for a narrowed list; on the full library it is a risky one-tap action.
            if hasActiveFilters {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: MobileKeptoraDesign.actionSpacing) { catalogueCount; selectListButton }
                    VStack(alignment: .leading, spacing: MobileKeptoraDesign.stackedActionSpacing) { catalogueCount; selectListButton }
                }
            } else {
                catalogueCount
            }
            Button { sources = true } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Sources", systemImage: "checklist")
                        Text(store.connectedSources.filter { store.selectedSourceIDs.contains($0.id) }.map(\.localizedScanTitle).joined(separator: " · "))
                            .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                    }
                    Spacer()
                    Text(L10n.format("%lld selected", store.selectedSourceIDs.count)).font(.caption)
                    Image(systemName: "chevron.right")
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.accessibilityIdentifier("archive.sourcesSummary")
            // Per-source counts and access live in the Sources sheet; here only a problem is shown.
            if store.coverage.contains(where: { $0.error != nil }) || !store.connectionErrors.isEmpty {
                Label("Some sources need attention.", systemImage: "exclamationmark.triangle").font(.caption)
                Button("Manage Source Access") { sources = true }.buttonStyle(MobileActionButtonStyle())
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: MobileKeptoraDesign.actionSpacing) { scanButtons }
                VStack(alignment: .leading, spacing: MobileKeptoraDesign.stackedActionSpacing) { scanButtons }
            }.disabled(store.isCleaningUp || store.isLoadingCatalogue)
            if case .scanning(let processed, let total, let current) = store.scanState {
                ProgressView(value: Double(processed), total: Double(max(total, 1)))
                    .accessibilityValue(Text(current))
            }
            if store.scanState.isScanning || store.isAnalyzing { Text("Scanning your photos. You can select ready results.").font(.caption).foregroundStyle(.secondary) }
            if let error = store.similarityError ?? store.videoSimilarityError { Label(error, systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(MobileKeptoraDesign.warning) }
            if store.skippedCloudItems > 0 {
                Text(String(format: L10n.tr("%lld originals could not be analyzed. They remain in the library."), store.skippedCloudItems)).font(.caption).foregroundStyle(.secondary)
            }
            if case .paused = store.scanState {
                Text("Scan paused.").font(.caption).foregroundStyle(.secondary)
            } else if store.scanState == .completed && store.sessionProgress.isComplete {
                scanResults
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
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8),
                                         count: typeSize.isAccessibilitySize ? 1 : 2), spacing: 8) {
                    ForEach(LibraryFindingFilter.allCases) { option in
                        Button { finding = option } label: {
                            Text(LocalizedStringKey(option.titleKey)).font(.subheadline.weight(.semibold)).multilineTextAlignment(.center)
                                .padding(.horizontal, 8).padding(.vertical, 8).frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                        }.background(finding == option ? MobileKeptoraDesign.accent.opacity(0.16) : Color.clear, in: Capsule())
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(finding == option ? .isSelected : [])
                        .accessibilityIdentifier("archive.finding." + option.rawValue)
                    }
                }.accessibilityIdentifier("archive.resultMode")
            if finding == .copies { exactBatchSelection }
            if store.authorization == .limited {
                Button("Limited Photos access · Manage Access") { store.manageLimitedPhotosAccess() }.buttonStyle(MobileActionButtonStyle())
            }
            if store.libraryCollectionIDs != nil {
                Button("Show Entire Library") { store.libraryCollectionIDs = nil; store.libraryCollectionTitle = nil; store.libraryCollectionSortBySize = false; store.libraryCollectionKind = nil }.buttonStyle(MobileActionButtonStyle())
            }
            if store.selectedLibraryIDs.isEmpty {
                Text("Tap a photo to select it. Touch and hold to see it larger.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }
    /// What the finished scan found, with one tap into each result.
    private var scanResults: some View {
        let scope = Set(store.scopedAssets.map(\.id))
        let extraCopies = store.exactSuggestionCandidates(visibleIDs: scope)
        let extraBytes = extraCopies.reduce(Int64(0)) { $0 + ($1.byteCount ?? 0) }
        let similarGroups = store.reviewGroups.filter { $0.kind == .verySimilar }.count
        let worthReviewing = store.scopedAssets.filter { store.qualityAssessments[$0.id]?.needsReview == true }.count
        return VStack(alignment: .leading, spacing: 8) {
            Label("Scan complete. Choose what to keep.", systemImage: "checkmark.circle.fill").font(.subheadline.weight(.semibold))
            if extraCopies.isEmpty && similarGroups == 0 && worthReviewing == 0 {
                Text("No copies or similar photos found.").font(.caption).foregroundStyle(.secondary)
            }
            if !extraCopies.isEmpty {
                resultButton(L10n.format("Extra copies: %lld · %@", extraCopies.count, ByteCountFormatter.string(fromByteCount: extraBytes, countStyle: .file)),
                             icon: "square.on.square", filter: .copies, id: "archive.results.copies")
            }
            if similarGroups > 0 {
                resultButton(L10n.format("Very similar groups: %lld", similarGroups), icon: "photo.on.rectangle.angled", filter: .verySimilar, id: "archive.results.verySimilar")
            }
            if worthReviewing > 0 {
                resultButton(L10n.format("Worth reviewing: %lld", worthReviewing), icon: "camera.metering.center.weighted", filter: .review, id: "archive.results.review")
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MobileKeptoraDesign.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("archive.results")
    }
    private func resultButton(_ title: String, icon: String, filter: LibraryFindingFilter, id: String) -> some View {
        Button { finding = filter } label: {
            HStack {
                Label(title, systemImage: icon).multilineTextAlignment(.leading)
                Spacer(minLength: 8)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
            }.frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .foregroundStyle(MobileKeptoraDesign.accent)
        .font(.subheadline.weight(.semibold))
        .accessibilityIdentifier(id)
    }
    @ViewBuilder private var scanButtons: some View {
        if store.scanState.isScanning || store.isAnalyzing {
            Button("Pause Scan") { store.suspendScanForBackground() }.buttonStyle(MobileActionButtonStyle())
            Menu { Button("Cancel Scan") { store.cancelScan() } } label: {
                Label("Scan Options", systemImage: "ellipsis.circle")
            }.buttonStyle(MobileActionButtonStyle())
        } else if store.scanState == .paused {
            Button("Resume Scan") { store.startScan(allowNetwork: store.lastScanAllowedNetwork) }
                .buttonStyle(MobilePrimaryButtonStyle()).disabled(!store.canScanSelectedSources)
        } else {
            Button(store.scanState == .completed ? "Scan Again" : "Start Scan") { store.startScan() }.buttonStyle(MobilePrimaryButtonStyle())
                .accessibilityIdentifier("archive.scanAll").disabled(!store.canScanSelectedSources)
            if store.skippedCloudItems > 0 {
                Menu { Button("Include Cloud Originals") { cloudScan = true } } label: {
                    Image(systemName: "ellipsis.circle").frame(width: 44, height: 44).contentShape(Rectangle())
                }.accessibilityLabel("Scan Options").disabled(!store.canScanSelectedSources)
            }
        }
    }
    private var catalogueCount: some View {
        HStack {
            Label(L10n.format("In this list: %lld items", visible.count), systemImage: "photo.stack")
                .font(.subheadline.weight(.semibold)).accessibilityIdentifier("archive.visibleCount")
            if store.isLoadingCatalogue { ProgressView() }
        }
    }
    private var selectListButton: some View {
        Button { store.selectLibraryItems(visible) } label: { Text(L10n.format("Select This List (%lld)", visible.count)) }
            .buttonStyle(MobileActionButtonStyle())
            .disabled(visible.isEmpty || store.isCleaningUp).accessibilityIdentifier("archive.selectAll")
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: MobileKeptoraDesign.actionSpacing) { filterControls }
                VStack(alignment: .leading, spacing: MobileKeptoraDesign.stackedActionSpacing) { filterControls }
            }
            if hasActiveFilters {
                activeFilterChips
            }
        }
    }
    @ViewBuilder private var filterControls: some View {
        Picker("Media type", selection: $media) {
            Text("All").tag(0); Text("Photos").tag(1); Text("Videos").tag(2)
        }.pickerStyle(.segmented)
        Menu {
            Picker("Album", selection: $albumID) {
                Text("All Albums").tag("")
                ForEach(store.albums) { Text($0.title).tag($0.id) }
            }
            Toggle("Favorites Only", isOn: $favouritesOnly)
            Toggle("Oldest First", isOn: $oldestFirst)
            Toggle("Largest First", isOn: $largestFirst)
            Toggle("Keep Related Shots Together", isOn: $smartOrder)
            Picker("Group by", selection: $grouping) { Text("All Items").tag(0); Text("Day").tag(1); Text("Month").tag(2) }
            Button("Date Range") { dateFilters = true }
            Button("Reset Filters") { resetFilters() }
        } label: { Label("Filters", systemImage: "line.3.horizontal.decrease.circle") }
        .buttonStyle(MobileActionButtonStyle())
        .accessibilityLabel("Filter and sort library")
    }
    private var activeFilterChips: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
            if finding != .all { filterChip(L10n.tr(String.LocalizationValue(finding.titleKey)), id: "finding") { finding = .all } }
            if media != 0 { filterChip(L10n.tr(media == 1 ? "Photos" : "Videos"), id: "media") { media = 0 } }
            if !albumID.isEmpty { filterChip(store.albums.first { $0.id == albumID }?.title ?? L10n.tr("Album"), id: "album") { albumID = "" } }
            if favouritesOnly { filterChip(L10n.tr("Favorites Only"), id: "favorites") { favouritesOnly = false } }
            if dateRangeEnabled { filterChip(L10n.tr("Date Range"), id: "date") { dateRangeEnabled = false } }
            if !search.isEmpty { filterChip(L10n.format("Search: %@", search), id: "search") { search = "" } }
            if largestFirst || store.libraryCollectionSortBySize {
                filterChip(L10n.tr("Largest First"), id: "size") { largestFirst = false; store.libraryCollectionSortBySize = false }
            }
            if oldestFirst { filterChip(L10n.tr("Oldest First"), id: "oldest") { oldestFirst = false } }
            if store.libraryCollectionIDs != nil {
                filterChip(store.libraryCollectionTitle ?? L10n.tr("Suggestions"), id: "collection") {
                    store.libraryCollectionIDs = nil; store.libraryCollectionTitle = nil; store.libraryCollectionKind = nil; store.libraryCollectionSortBySize = false
                }
            }
        }
    }
    private var hasActiveFilters: Bool {
        finding != .all || media != 0 || !albumID.isEmpty || favouritesOnly || dateRangeEnabled || !search.isEmpty || largestFirst || oldestFirst || store.libraryCollectionSortBySize || store.libraryCollectionIDs != nil
    }
    private func filterChip(_ title: String, id: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack { Text(title).multilineTextAlignment(.leading); Spacer(minLength: 4); Image(systemName: "xmark.circle.fill") }
                .font(.caption.weight(.semibold)).padding(.horizontal, 10).padding(.vertical, 8).frame(minWidth: 44, minHeight: 44)
                .background(MobileKeptoraDesign.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                .contentShape(RoundedRectangle(cornerRadius: 10))
        }.buttonStyle(.plain).accessibilityLabel(Text(L10n.format("Remove Filter: %@", title)))
            .accessibilityIdentifier("archive.filter.remove." + id)
    }

    private func dateMatches(_ asset: UniversalMediaAsset) -> Bool {
        guard let date = asset.context?.captureDate ?? asset.creationDate else { return false }
        let lower = Calendar.current.startOfDay(for: fromDate)
        let upper = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: toDate)) ?? toDate
        return date >= lower && date < upper
    }
    private func resetFilters() {
        finding = .all; media = 0; albumID = ""; favouritesOnly = false; dateRangeEnabled = false; search = ""
        oldestFirst = false; largestFirst = false; grouping = 2; smartOrder = true
        store.libraryCollectionIDs = nil; store.libraryCollectionTitle = nil; store.libraryCollectionKind = nil; store.libraryCollectionSortBySize = false
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
                    }.buttonStyle(MobileActionButtonStyle()).disabled(remaining == 0)
                        .accessibilityIdentifier("archive.selectExtraCopies")
                    Text("Items suggested to keep and protected items stay unselected.").font(.caption).foregroundStyle(.secondary)
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
        Text(section.date == .distantFuture ? L10n.tr(largestFirst || store.libraryCollectionSortBySize ? "Largest First" : "All Items") : section.date == .distantPast ? L10n.tr("Date unknown") : (grouping == 1 ? section.date.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: L10n.currentLocale)) : section.date.formatted(.dateTime.locale(L10n.currentLocale).month(.wide).year())))
            .font(.headline)
        Button(section.date == .distantFuture ? "Select All in This View" : grouping == 1 ? "Select Day" : "Select Month") { store.selectLibraryItems(section.assets) }
            .buttonStyle(MobileActionButtonStyle())
    }

    private func cell(_ asset: UniversalMediaAsset, groups: [LibraryReviewGroup] = [], keeperBadge: String? = nil) -> some View {
        let selected = store.selectedLibraryIDs.contains(asset.id)
        let kept = !selected && keeperBadge != nil
        let keeperLabel = keeperBadge ?? "Suggested Keep"
        var spoken = [asset.displayName, store.sourceLabel(asset)]
        if let finding = store.qualityAssessments[asset.id]?.findings.first { spoken.append(L10n.tr(String.LocalizationValue(finding.titleKey))) }
        if kept { spoken.append(L10n.tr(String.LocalizationValue(keeperLabel))) }
        if store.decisions.protectedIDs.contains(asset.id) { spoken.append(L10n.tr("Protected")) }
        return VStack(spacing: 6) {
            Button { store.toggleLibrarySelection(asset) } label: {
                selectionThumbnail(asset, selected: selected, keeperLabel: kept ? keeperLabel : nil)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spoken.joined(separator: ", "))
            .accessibilityValue(Text(selected ? LocalizedStringKey("Selected") : LocalizedStringKey("Not selected")))
            .accessibilityHint("Tap to change selection")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("archive.asset.\(asset.id)")
          if let findings = store.qualityAssessments[asset.id]?.findings, findings.count > 1 {
              Menu {
                  ForEach(Array(findings.dropFirst()), id: \.rawValue) { finding in Label(LocalizedStringKey(finding.titleKey), systemImage: finding.symbol) }
              } label: { Text(L10n.format("More Findings (%lld)", findings.count - 1)) }
                  .buttonStyle(MobileActionButtonStyle(fillsWidth: true))
          }
          // The suggested or chosen keeper already shows its badge; the button would do nothing there.
          if !groups.isEmpty && !kept {
              Button("Keep This") { store.keep(asset, in: groups) }
                  .buttonStyle(MobileActionButtonStyle(fillsWidth: true)).disabled(store.scanState.isScanning || store.isAnalyzing)
                  .accessibilityIdentifier("archive.keep.\(asset.id)")
          }
        }.disabled(store.isCleaningUp)
            .contextMenu {
                Button(selected ? "Deselect" : "Select", systemImage: selected ? "circle" : "checkmark.circle") { store.toggleLibrarySelection(asset) }
                Button(store.decisions.protectedIDs.contains(asset.id) ? "Unprotect Photo" : "Protect Photo",
                       systemImage: store.decisions.protectedIDs.contains(asset.id) ? "lock.open" : "lock") { store.toggleProtection(asset) }
                ForEach(groups) { group in
                    Button("Protect Group", systemImage: "lock.rectangle.stack") { store.protect(group) }
                }
            } preview: {
                MobileAssetPreview(asset: asset, sourceLabel: store.sourceLabel(asset))
            }
    }

    private func selectionThumbnail(_ asset: UniversalMediaAsset, selected: Bool, keeperLabel: String?) -> some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                MobileAssetThumbnail(asset: asset, showsRetryButton: false)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .accessibilityHidden(true)
                    .overlay(selected ? Color.black.opacity(0.28) : .clear)
                    .allowsHitTesting(false)
                thumbnailBadges(asset, keeperLabel: keeperLabel).allowsHitTesting(false)
                thumbnailSelectionIndicator(asset, selected: selected).allowsHitTesting(false)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? MobileKeptoraDesign.accent : .clear, lineWidth: 3))
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
                Label(LocalizedStringKey(keeperLabel), systemImage: "bookmark.fill").font(.caption2.weight(.semibold)).lineLimit(1).padding(4)
                    .foregroundStyle(.white).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4))
            }
            Spacer()
        }.padding(5).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func thumbnailSelectionIndicator(_ asset: UniversalMediaAsset, selected: Bool) -> some View {
        HStack {
            if asset.isFavorite { Image(systemName: "heart.fill") }
            if asset.mediaKind == .video { Label(asset.formattedDuration, systemImage: "play.fill") }
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
            Text(LocalizedStringKey(store.decisions.keeperReason(in: group, quality: store.qualityAssessments))).font(.caption).foregroundStyle(.secondary)
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
        }.buttonStyle(MobileActionButtonStyle()).disabled(remaining == 0).accessibilityIdentifier("archive.others.\(group.id)")
    }

    private var selectionBar: some View {
        VStack(spacing: 8) {
            // Counts on the left, size on the right, so the bar leaves more room for the gallery.
            let summaryLayout = typeSize.isAccessibilitySize ? AnyLayout(VStackLayout(alignment: .leading, spacing: 6)) : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
            summaryLayout {
                let summary = MediaSelectionSummary(store.librarySelection)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: L10n.tr("Selected items: %lld"), store.selectedLibraryIDs.count)).font(.headline)
                    Text(String(format: L10n.tr("Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.caption).foregroundStyle(.secondary)
                    let hidden = store.selectedLibraryIDs.subtracting(visible.map(\.id)).count
                    if hidden > 0 { Text(String(format: L10n.tr("%lld selected outside this view"), hidden)).font(.caption).foregroundStyle(.secondary) }
                }
                if !typeSize.isAccessibilitySize { Spacer(minLength: 8) }
                VStack(alignment: typeSize.isAccessibilitySize ? .leading : .trailing, spacing: 2) {
                    Text(ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file)).font(.subheadline.weight(.semibold))
                    Text("Space is not freed right away").font(.caption2).foregroundStyle(.secondary)
                    if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.caption2).foregroundStyle(.secondary) }
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
        }.padding(14).background(.bar).disabled(store.isCleaningUp)
            .accessibilityElement(children: .contain).accessibilityIdentifier("archive.selectionBar")
    }
    @ViewBuilder private var secondarySelectionButtons: some View {
        if store.canUndoLibrarySelection {
            Button("Undo Selection") { store.undoLibrarySelection() }.buttonStyle(MobileActionButtonStyle(fillsWidth: true)).accessibilityIdentifier("archive.undoSelection")
        }
        Button("Clear All Selections") { store.replaceLibrarySelection([]) }.buttonStyle(MobileActionButtonStyle(fillsWidth: true)).disabled(store.selectedLibraryIDs.isEmpty).accessibilityIdentifier("archive.clearSelection")
    }
}

struct MobileSelectionReviewSheet: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var confirm = false
    @State private var capturedIDs: Set<String> = []
    @State private var completed = false
    @State private var review = FrozenSelectionReview()
    @State private var captured = false
    @State private var leaveLinkedFiles = false
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
                    Text(String(format: L10n.tr("Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.title2.bold())
                    Text(ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file) + " · " + L10n.tr("Space is not freed right away")).foregroundStyle(.secondary)
                    if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.footnote) }
                    if summary.personalItems > 0 { Label("Includes favorites, hidden, edited or shared items you selected manually.", systemImage: "exclamationmark.triangle").font(.footnote) }
                    let reviewedIDs = Set(reviewedItems.map(\.id))
                    if store.exactGroups.contains(where: { $0.assets.allSatisfy { reviewedIDs.contains($0.id) } }) {
                        Label("Every item in a known duplicate group is selected.", systemImage: "exclamationmark.triangle")
                    }
                }
                if hasUnavailableSelection {
                    Section("Unavailable Selected Items") {
                        Text("Reconnect unavailable sources or remove their items from your selection.")
                        Button("Remove Unavailable Items from Selection") {
                            review.discard(Set(store.pendingSelection.map(\.id)).union(store.unresolvedSelectionIDs))
                            store.discardPendingSelection()
                        }.buttonStyle(MobileActionButtonStyle())
                    }
                }
                if !LibraryFileFamilies.omittedCompanions(for: reviewedItems).isEmpty {
                    Section("Linked Files") {
                        Text("Linked files remain outside your selection. Review them before removing this photo.")
                        ForEach(LibraryFileFamilies.omittedCompanions(for: reviewedItems), id: \.self) { url in Text(url.lastPathComponent).font(.caption) }
                        Toggle("Remove only my selected items and leave linked files in place", isOn: $leaveLinkedFiles)
                    }
                }
                Section("Selected Items") {
                    Text("Removing an item from this list keeps it in your library.").font(.footnote).foregroundStyle(.secondary)
                    if reviewedItems.isEmpty { Text("No items selected.").foregroundStyle(.secondary) }
                    ForEach(reviewedItems) { asset in
                        reviewRow(asset)
                    }
                }
                Section("Removal by Source") {
                    ForEach(store.connectedSources) { source in
                        let items = reviewedItems.filter { $0.sourceID == source.id }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.localizedScanTitle + " · " + items.count.formatted(.number.locale(L10n.currentLocale)))
                                Text(source.kind == .photos ? LocalizedStringKey("Recently Deleted in Photos") : LocalizedStringKey("Recovery Folder")).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                    DisclosureGroup("Recovery Details") {
                        Text("Photos items move to Recently Deleted and iCloud changes sync across devices. Files move to a recovery folder on the same storage; this does not free disk space. Completed steps appear in History if cleanup stops partway.").font(.footnote).foregroundStyle(.secondary)
                    }
                }
            }
            .disabled(store.isCleaningUp)
            .navigationTitle("Review Selection").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(store.isCleaningUp).accessibilityIdentifier("archive.review.close") } }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if store.isCleaningUp { ProgressView(store.cleanupStatus ?? L10n.tr("Removing selected items…")) }
                    Text(L10n.format("Selected items: %lld", reviewedItems.count)).font(.headline)
                    if review.canUndoRemoval {
                        Button("Undo Review Change") {
                            if let asset = review.undoRemoval() { store.replaceLibrarySelection(store.selectedLibraryIDs.union([asset.id])) }
                        }.buttonStyle(MobileActionButtonStyle(fillsWidth: true)).disabled(store.isCleaningUp).accessibilityIdentifier("archive.review.undo")
                    }
                    Button(role: .destructive) {
                        capturedIDs = Set(reviewedItems.map(\.id)); confirm = true
                    } label: { Text(L10n.format("Remove %lld Items", reviewedItems.count)) }
                        .buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true, tint: MobileKeptoraDesign.dangerFill)).accessibilityIdentifier("archive.review.remove")
                        .disabled((!leaveLinkedFiles && !LibraryFileFamilies.omittedCompanions(for: reviewedItems).isEmpty) || reviewedItems.isEmpty || hasUnavailableSelection || store.isCleaningUp || store.scanState.isScanning || store.isAnalyzing)
                    if store.scanState.isScanning || store.isAnalyzing { Text("Wait for analysis to finish or cancel it before cleanup.").font(.footnote) }
                    else if hasUnavailableSelection { Text("Remove unavailable items from your selection to continue.").font(.footnote) }
                    else if !reviewedItems.isEmpty && !leaveLinkedFiles && !LibraryFileFamilies.omittedCompanions(for: reviewedItems).isEmpty {
                        Text("Review the linked files above to continue.").font(.footnote)
                    }
                }.padding(16).background(.bar)
                    .accessibilityElement(children: .contain).accessibilityIdentifier("archive.review.actions")
            }
            .onChange(of: reviewedItems) { _, _ in leaveLinkedFiles = false }
            .onAppear { if !captured { review = FrozenSelectionReview(store.librarySelection); captured = true } }
            .interactiveDismissDisabled(store.isCleaningUp)
            .alert("Something went wrong", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .alert("Remove selected items?", isPresented: $confirm) {
                Button(role: .destructive) {
                    Task { completed = await store.cleanupLibrarySelection(expectedIDs: capturedIDs, reviewedAssets: reviewedItems, allowPartialFamilies: leaveLinkedFiles) }
                } label: { Text(L10n.format("Remove %lld Items", capturedIDs.count)) }
                Button("Cancel", role: .cancel) { }
            } message: { Text("Only the items listed here will be removed. Review the destination and recovery conditions before continuing.") }
            .alert("Cleanup Completed", isPresented: $completed) {
                Button("View in History") { store.selectedTab = .history; dismiss() }
                Button("Done") { dismiss() }
            } message: {
                Text("Photos items move to Recently Deleted and iCloud changes sync across devices. Files move to a recovery folder on the same storage; this does not free disk space. Completed steps appear in History if cleanup stops partway.")
            }
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
                Text(asset.displayName).lineLimit(2)
                Text(store.sourceLabel(asset)).font(.caption).foregroundStyle(.secondary)
                if let date = asset.captureDateDescription { Text(date).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
    private func excludeButton(_ asset: UniversalMediaAsset) -> some View {
        Button {
            if review.remove(asset.id) { store.replaceLibrarySelection(store.selectedLibraryIDs.subtracting([asset.id])) }
        } label: { Label("Remove from selection", systemImage: "minus.circle") }
            .buttonStyle(MobileActionButtonStyle()).accessibilityLabel("Remove from selection")
            .accessibilityHint("This item will stay in your library.")
            .accessibilityIdentifier("archive.review.exclude." + asset.id)
    }
}

struct MobileCleanupHubView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Choose where to start.").font(.title.bold())
                Text("Open a category to choose photos.").foregroundStyle(.secondary)
                if store.connectedSources.isEmpty {
                    NavigationLink { MobileSourceLibraryView() } label: {
                        Label("Connect your library", systemImage: "folder.badge.plus")
                    }.buttonStyle(MobilePrimaryButtonStyle())
                } else {
                    NavigationLink { MobileSourceLibraryView() } label: { Label("Sources", systemImage: "checklist") }.buttonStyle(MobileActionButtonStyle())
                }
                if store.scanState.isScanning || store.isAnalyzing {
                    ProgressView("Analyzing your library…")
                    Button("Pause Scan") { store.suspendScanForBackground() }.buttonStyle(MobileActionButtonStyle())
                    Menu { Button("Cancel Scan") { store.cancelScan() } } label: { Label("Scan Options", systemImage: "ellipsis.circle") }
                        .buttonStyle(MobileActionButtonStyle())
                } else if store.scanState == .paused {
                    Text("Scan paused.").font(.footnote).foregroundStyle(.secondary)
                    Button("Resume Scan") { store.startScan(allowNetwork: store.lastScanAllowedNetwork) }.buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true))
                } else if store.scanState == .completed {
                    // Results exist; scanning again is a secondary action.
                    Button("Scan Again") { store.startScan() }
                        .buttonStyle(MobileActionButtonStyle(fillsWidth: true)).disabled(!store.canScanSelectedSources)
                } else {
                    Button("Start Scan") { store.startScan() }
                        .buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true)).disabled(!store.canScanSelectedSources)
                }
                collection("Screenshots", icon: "viewfinder", items: store.scopedAssets.filter { $0.context?.isScreenshot == true })
                collection("Videos by Size", icon: "video", items: store.scopedAssets.filter { $0.mediaKind == .video }.sorted { ($0.byteCount ?? 0) > ($1.byteCount ?? 0) })
                if store.scopedAssets.contains(where: { $0.mediaKind == .video && $0.byteCount == nil }) { Text("Items with unknown size appear after measured items.").font(.footnote).foregroundStyle(.secondary) }
                collection("Live Photos", icon: "livephoto", items: store.scopedAssets.filter { $0.context?.isLivePhoto == true })
                collection("Duplicates & Similar Photos", icon: "square.on.square", items: UnifiedLibraryAdapter.uniqueReferences(store.reviewGroups.flatMap { $0.assets }), needsScan: true)
                collection("Worth Reviewing", icon: "camera.metering.center.weighted", items: store.scopedAssets.filter { store.qualityAssessments[$0.id]?.needsReview == true }, needsScan: true)
                if store.skippedSimilarityPreviews > 0 {
                    Text(String(format: L10n.tr("%lld previews could not be analyzed. Results cover only accessible items."), store.skippedSimilarityPreviews)).font(.footnote).foregroundStyle(.secondary)
                }
                if let error = store.similarityError ?? store.videoSimilarityError {
                    Label("Some analysis could not be completed", systemImage: "exclamationmark.triangle").font(.headline)
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(18)
        }
        .background(MobileKeptoraDesign.canvas).navigationTitle("Suggestions")
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
                Image(systemName: icon).font(.title2).foregroundStyle(items.isEmpty ? Color.secondary : MobileKeptoraDesign.accent).frame(width: 40)
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStringKey(title)).font(.headline)
                    Text(collectionSubtitle(items.count, needsScan: needsScan)).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer(); if !items.isEmpty { Image(systemName: "chevron.right").foregroundStyle(.secondary) }
            }.padding(18).frame(maxWidth: .infinity).background(MobileKeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).disabled(store.isCleaningUp || items.isEmpty).accessibilityIdentifier("cleanup.collection." + title)
    }
}
