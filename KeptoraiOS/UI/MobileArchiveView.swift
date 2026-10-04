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
    @State private var inspector: UniversalMediaAsset?
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
                    if store.source == .none {
                        welcome
                    } else {
                        catalogueHeader
                        filters
                        if let error = store.catalogueError {
                            ContentUnavailableView {
                                Label("Library could not be loaded", systemImage: "exclamationmark.triangle")
                            } description: { Text(error) } actions: {
                                Button("Try Again") { Task { await store.loadCatalogue() } }
                            }
                        } else if store.isLoadingCatalogue && store.assets.isEmpty {
                            ProgressView("Loading your library…").frame(maxWidth: .infinity, minHeight: 180)
                        } else if store.selectedSourceIDs.isEmpty {
                            ContentUnavailableView("Select at least one source", systemImage: "checklist", description: Text("Tick a source above to show its photos and videos."))
                        } else if visible.isEmpty {
                            if store.scanState.isScanning { Text("Results appear as they become available.").foregroundStyle(.secondary).padding(.vertical, 40) }
                            else {
                            ContentUnavailableView("No items in this view", systemImage: "photo", description: Text("Change the filters or choose another source."))
                            Button("Reset Filters") { media = 0; albumID = ""; favouritesOnly = false; dateRangeEnabled = false; search = ""; store.libraryCollectionIDs = nil; store.libraryCollectionTitle = nil; store.libraryCollectionKind = nil; store.libraryCollectionSortBySize = false }
                            }
                        } else if smartOrder {
                            let blocks = LibraryReviewBlock.make(assets: visible, groups: store.reviewGroups, quality: store.qualityAssessments, smart: true)
                            ForEach(blocks) { block in
                                let membership = block.groupsByAsset
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(LocalizedStringKey(block.titleKey)).font(.headline)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 150 : 106), spacing: 4)], spacing: 4) {
                                        ForEach(block.assets) { asset in
                                            cell(asset, groups: membership[asset.id] ?? []).id(asset.id)
                                        }
                                    }.scrollTargetLayout()
                                    ForEach(block.groups) { group in
                                        groupActions(group)
                                    }
                                }
                            }
                        } else {
                            ForEach(sections, id: \.date) { section in
                                sectionHeader(section)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 150 : 106), spacing: 4)], spacing: 4) {
                                    ForEach(section.assets) { asset in cell(asset).id(asset.id) }
                                }.scrollTargetLayout()
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .scrollPosition(id: $visibleAnchor, anchor: .top)
            .refreshable { await store.loadCatalogue() }
        .background(MobileKeptoraDesign.canvas)
        .navigationTitle(store.libraryCollectionKind.map { L10n.tr(String.LocalizationValue($0)) } ?? store.libraryCollectionTitle ?? L10n.tr("Library"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $search, prompt: "Search filenames or camera")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Menu {
                    Button("Sources") { sources = true }
                    Button("Settings", systemImage: "gearshape") { store.present(.settings) }.accessibilityIdentifier("ios.library.settings")
                    Button("Refresh Library", systemImage: "arrow.clockwise") { Task { await store.loadCatalogue() } }
                } label: { Image(systemName: "gearshape").frame(minWidth: 44, minHeight: 44) }
                .accessibilityLabel("Library options").accessibilityIdentifier("ios.library.options")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.selectLibraryItems(visible) } label: { Image(systemName: "checkmark.circle").frame(minWidth: 44, minHeight: 44) }
                    .disabled(visible.isEmpty || store.isCleaningUp)
                    .accessibilityLabel("Select All in This View")
                    .accessibilityIdentifier("archive.selectAll")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.selectedLibraryIDs.isEmpty || store.canUndoLibrarySelection { selectionBar }
        }
        .confirmationDialog("Download iCloud originals?", isPresented: $cloudScan) {
            Button("Download and Scan") { store.startScan(allowNetwork: true) }
        } message: { Text("This may use network data and device storage. You can cancel the scan at any time.") }
        .sheet(isPresented: $sources, onDismiss: { if pendingFolderPicker { pendingFolderPicker = false; store.present(.filePicker) } }) { NavigationStack { MobileSourceLibraryView(onChooseFolder: { pendingFolderPicker = true; sources = false }).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { sources = false } } } } }
        .sheet(item: $inspector) { MobilePhotoInspectorSheet(asset: $0).environmentObject(store) }
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
        .onChange(of: store.libraryCollectionIDs) { _, _ in albumID = ""; search = ""; media = 0; favouritesOnly = false; dateRangeEnabled = false; largestFirst = false }
        .onChange(of: store.selectedLibraryIDs) { _, _ in store.saveLibrarySelection() }
        .alert("Photos Access Needed", isPresented: Binding(get: { store.isShowingPhotosPermissionHelp && !sources }, set: { if !$0 { store.isShowingPhotosPermissionHelp = false } })) {
            if store.canOpenPhotosSettings { Button("Open Settings") { store.openPhotosSettings() }.accessibilityIdentifier("ios.photosPermission.openSettings") }
            Button("Not Now", role: .cancel) { store.isShowingPhotosPermissionHelp = false }.accessibilityIdentifier("ios.photosPermission.notNow")
        } message: { Text(store.photosPermissionHelpMessage) }
        .accessibilityIdentifier("ios.page.archive")
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Image("onboarding_privacy").resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
            Text("Your photos. Your choice.").font(.largeTitle.bold())
            Text("Browse every photo, select what you no longer need, and review before removing anything.").foregroundStyle(.secondary)
            Button("Open Photos") { Task { await store.connectPhotos() } }
                .accessibilityIdentifier("library.source.photos")
                .frame(maxWidth: .infinity).buttonStyle(MobilePrimaryButtonStyle())
            Button("Choose a Folder") { store.present(.filePicker) }.accessibilityIdentifier("library.source.files").frame(minHeight: 44)
            Text("Private processing on your device. No account required.").font(.footnote).foregroundStyle(.secondary)
        }.padding(8)
    }

    private var catalogueHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("Selected Items", systemImage: "photo.stack")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if store.isLoadingCatalogue { ProgressView() }
                Text(visible.count.formatted()).monospacedDigit().foregroundStyle(.secondary)
            }
            Button { sources = true } label: {
                HStack {
                    Label("Scan Sources", systemImage: "checklist")
                    Spacer()
                    Text(store.selectedSourceIDs.count.formatted())
                    Image(systemName: "chevron.right")
                }.frame(minHeight: 44)
            }.accessibilityIdentifier("archive.sourcesSummary")
            DisclosureGroup("Source Access") {
            ForEach(store.coverage) { report in
                HStack(alignment: .top) {
                    Image(systemName: report.error == nil ? "checkmark.circle" : "exclamationmark.triangle")
                    Text(report.source.localizedScanTitle)
                    Spacer()
                    Text(report.itemCount.formatted()).monospacedDigit()
                }.font(.caption).foregroundStyle(report.error == nil ? Color.secondary : .orange)
                if report.error != nil { Text("Some items in this source are unavailable. Reconnect or check access.").font(.caption).foregroundStyle(.secondary) }
            }
            ForEach(Array(store.connectionErrors.enumerated()), id: \.offset) { entry in Text(entry.element).font(.caption).foregroundStyle(.orange) }
            Text("Photos includes iCloud Photos. Files includes the folders you connect.").font(.caption).foregroundStyle(.secondary)
            }
            Text("Connected sources only. Add Photos and folders in Sources.").font(.caption).foregroundStyle(.secondary)
            if store.coverage.contains(where: { $0.error != nil }) || !store.connectionErrors.isEmpty {
                Label("Some sources have limited access. Check Source Access.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
            HStack {
                if store.scanState.isScanning || store.isAnalyzing {
                    ProgressView()
                    Button("Pause Scan") { store.suspendScanForBackground() }
                    Button("Cancel Scan") { store.cancelScan() }
                } else {
                    Button("Scan Selected Sources") { store.startScan() }.buttonStyle(.borderedProminent).accessibilityIdentifier("archive.scanAll").disabled(!store.canScanSelectedSources)
                    Menu {
                        Button("Include Cloud Originals") { cloudScan = true }
                        Button("Select Exact Copy Suggestions") { if !store.selectExactSuggestions(isUnlocked: purchase.isUnlocked) { store.present(.paywall) } }
                    } label: { Image(systemName: "ellipsis.circle").frame(width: 44, height: 44) }
                    .accessibilityLabel("Scan and selection options").disabled(!store.canScanSelectedSources)
                }
            }.disabled(store.isCleaningUp || store.isLoadingCatalogue)
            if case .scanning(let processed, let total, let current) = store.scanState {
                ProgressView(value: Double(processed), total: Double(max(total, 1)))
                Text(current).font(.caption).lineLimit(2)
            }
            if store.isAnalyzing { Text("Analysis in progress. Groups may change.").font(.caption).foregroundStyle(.secondary) }
            if let error = store.similarityError ?? store.videoSimilarityError { Text(error).font(.caption).foregroundStyle(.orange) }
            if store.skippedCloudItems > 0 {
                Text(String(format: L10n.tr("%lld originals could not be analyzed. They remain in the library."), store.skippedCloudItems)).font(.caption).foregroundStyle(.secondary)
            }
            if case .paused = store.scanState {
                Button("Resume Scan") { store.startScan(allowNetwork: store.lastScanAllowedNetwork) }.frame(minHeight: 44)
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
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                    ForEach(LibraryFindingFilter.allCases) { option in
                        Button { finding = option } label: {
                            Text(LocalizedStringKey(option.titleKey)).font(.subheadline.weight(.semibold)).padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 44)
                        }.background(finding == option ? MobileKeptoraDesign.accent.opacity(0.16) : Color.clear, in: Capsule())
                        .accessibilityAddTraits(finding == option ? .isSelected : [])
                        .accessibilityIdentifier("archive.finding." + option.rawValue)
                    }
                }.accessibilityIdentifier("archive.resultMode")
            if store.authorization == .limited {
                Button("Limited Photos access · Manage Access") { store.manageLimitedPhotosAccess() }.font(.footnote).frame(minHeight: 44)
            }
            if store.libraryCollectionIDs != nil {
                Button("Show Entire Library") { store.libraryCollectionIDs = nil; store.libraryCollectionTitle = nil; store.libraryCollectionSortBySize = false; store.libraryCollectionKind = nil }.frame(minHeight: 44)
            }
            Text("Tap a photo to select it. Use the magnifier to enlarge it.").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var filters: some View {
        HStack {
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
            } label: { Image(systemName: "line.3.horizontal.decrease.circle").frame(width: 44, height: 44) }
            .accessibilityLabel("Filter and sort library")
        }
    }

    private func dateMatches(_ asset: UniversalMediaAsset) -> Bool {
        guard let date = asset.context?.captureDate ?? asset.creationDate else { return false }
        let lower = Calendar.current.startOfDay(for: fromDate)
        let upper = Calendar.current.date(byAdding: .day, value: 1, to: Calendar.current.startOfDay(for: toDate)) ?? toDate
        return date >= lower && date < upper
    }

    private func sectionHeader(_ section: (date: Date, assets: [UniversalMediaAsset])) -> some View {
        HStack {
            Text(section.date == .distantFuture ? L10n.tr(largestFirst || store.libraryCollectionSortBySize ? "Largest First" : "All Items") : section.date == .distantPast ? L10n.tr("Date unknown") : (grouping == 1 ? section.date.formatted(Date.FormatStyle(date: .complete, time: .omitted, locale: L10n.currentLocale)) : section.date.formatted(.dateTime.locale(L10n.currentLocale).month(.wide).year())))
                .font(.headline)
            Spacer()
                Button(section.date == .distantFuture ? "Select All in This View" : grouping == 1 ? "Select Day" : "Select Month") { store.selectLibraryItems(section.assets) }
                    .font(.footnote).frame(minHeight: 44)
        }
    }

    private func cell(_ asset: UniversalMediaAsset, groups: [LibraryReviewGroup] = []) -> some View {
        let selected = store.selectedLibraryIDs.contains(asset.id)
        let kept = !selected && groups.contains { store.decisions.keeper(in: $0) == asset.id }
        var spoken = [asset.displayName, store.sourceLabel(asset)]
        if let finding = store.qualityAssessments[asset.id]?.findings.first { spoken.append(L10n.tr(String.LocalizationValue(finding.titleKey))) }
        if kept { spoken.append(L10n.tr("Kept in This Group")) }
        if store.decisions.protectedIDs.contains(asset.id) { spoken.append(L10n.tr("Protected")) }
        return VStack(spacing: 0) {
          ZStack(alignment: .topTrailing) {
            Button { store.toggleLibrarySelection(asset) } label: {
            ZStack(alignment: .bottomTrailing) {
                MobileAssetThumbnail(asset: asset).aspectRatio(1, contentMode: .fit).allowsHitTesting(false).accessibilityHidden(true)
                    .overlay(selected ? Color.black.opacity(0.28) : .clear)
                VStack(alignment: .leading, spacing: 4) {
                    Label(LocalizedStringKey(asset.sourceBadgeKey(in: store.connectedSources)), systemImage: asset.sourceBadgeSymbol(in: store.connectedSources)).font(.caption2.weight(.semibold)).lineLimit(1)
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .foregroundStyle(.white).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4))
                    if let issue = store.qualityAssessments[asset.id]?.findings.first {
                        Label(LocalizedStringKey(issue.titleKey), systemImage: issue.symbol).font(.caption2).lineLimit(1).padding(4).foregroundStyle(.white).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4))
                    }
                    if store.decisions.protectedIDs.contains(asset.id) { Image(systemName: "lock.fill").foregroundStyle(.white) }
                    if kept { Label("Kept in This Group", systemImage: "bookmark.fill").font(.caption2.weight(.semibold)).lineLimit(1).padding(4).foregroundStyle(.white).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4)) }
                    Spacer()
                }.padding(5).padding(.trailing, 34).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? MobileKeptoraDesign.accent : .clear, lineWidth: 3))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(spoken.joined(separator: ", "))
            .accessibilityValue(Text(selected ? LocalizedStringKey("Selected") : LocalizedStringKey("Not selected")))
            .accessibilityHint("Tap to change selection")
            .accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("archive.asset.\(asset.id)")
            Button { inspector = asset } label: {
                Image(systemName: "magnifyingglass").font(.body.weight(.semibold)).foregroundStyle(.white)
                    .frame(width: 44, height: 44).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 8))
            }.buttonStyle(.plain)
                .accessibilityLabel("Open Preview").accessibilityIdentifier("archive.preview.\(asset.id)")
          }
          if !groups.isEmpty {
              Button("Keep This") { store.keep(asset, in: groups) }
                  .font(.caption.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 44)
                  .buttonStyle(.bordered).disabled(store.scanState.isScanning || store.isAnalyzing)
                  .accessibilityIdentifier("archive.keep.\(asset.id)")
          }
        }.disabled(store.isCleaningUp)
            .contextMenu {
                Button(store.decisions.protectedIDs.contains(asset.id) ? "Unprotect Photo" : "Protect Photo") { store.toggleProtection(asset) }
            }
    }

    private func groupActions(_ group: LibraryReviewGroup) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(LocalizedStringKey(group.titleKey)).font(.caption.weight(.semibold))
            Text(LocalizedStringKey(store.decisions.keeperReason(in: group, quality: store.qualityAssessments))).font(.caption).foregroundStyle(.secondary)
            HStack {
                Button("Select Others") { if !store.selectOthers(in: group, isUnlocked: purchase.isUnlocked) { store.present(.paywall) } }
                    .buttonStyle(.bordered).frame(minHeight: 44).accessibilityIdentifier("archive.others.\(group.id)")
                Menu {
                    Button("Protect Group") { store.protect(group) }
                } label: { Label("Group Actions", systemImage: "ellipsis.circle").frame(minHeight: 44) }
            }.font(.footnote)
        }.disabled(store.isCleaningUp || store.scanState.isScanning || store.isAnalyzing)
    }

    private var selectionBar: some View {
        VStack(spacing: 8) {
            HStack {
                let summary = MediaSelectionSummary(store.librarySelection)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: L10n.tr("Selected items: %lld"), store.selectedLibraryIDs.count)).font(.headline)
                    Text(String(format: L10n.tr("Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.caption).foregroundStyle(.secondary)
                    let hidden = store.selectedLibraryIDs.subtracting(visible.map(\.id)).count
                    if hidden > 0 { Text(String(format: L10n.tr("%lld selected outside this view"), hidden)).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file)).font(.subheadline.weight(.semibold))
                    Text("Media size, not freed space").font(.caption2).foregroundStyle(.secondary)
                    if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.caption2).foregroundStyle(.secondary) }
                }
            }
            ViewThatFits(in: .horizontal) {
                HStack { selectionButtons }
                VStack { selectionButtons }
            }
        }.padding(14).background(.bar).disabled(store.isCleaningUp)
    }
    @ViewBuilder private var selectionButtons: some View {
        if store.canUndoLibrarySelection {
            Button("Undo Selection") { store.undoLibrarySelection() }.frame(minHeight: 44).accessibilityIdentifier("archive.undoSelection")
        }
        Button { store.replaceLibrarySelection([]) } label: { Image(systemName: "xmark.circle").frame(width: 44, height: 44) }
            .accessibilityLabel("Clear Selection").disabled(store.selectedLibraryIDs.isEmpty)
        Button("Review Selection") { reviewSelection = true }.buttonStyle(.borderedProminent).frame(minHeight: 44).disabled(store.selectedLibraryIDs.isEmpty).accessibilityIdentifier("archive.reviewSelection")
    }
}

struct MobileSelectionReviewSheet: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    @State private var capturedIDs: Set<String> = []
    @State private var completed = false
    @State private var reviewedItems: [UniversalMediaAsset] = []
    private var summary: MediaSelectionSummary { MediaSelectionSummary(reviewedItems) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(format: L10n.tr("Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.title2.bold())
                    Label("Selected Items", systemImage: "photo.stack")
                    Text(ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file) + " · " + L10n.tr("Media size, not freed space")).foregroundStyle(.secondary)
                    if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.footnote) }
                    Text("Photos items move to Recently Deleted and iCloud changes sync across devices. Files move to a recovery folder on the same storage; this does not free disk space. Completed steps appear in History if cleanup stops partway.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if summary.personalItems > 0 { Label("Includes favorites, hidden, edited or shared items you selected manually.", systemImage: "exclamationmark.triangle").font(.footnote) }
                    if store.exactGroups.contains(where: { $0.assets.allSatisfy { store.selectedLibraryIDs.contains($0.id) } }) {
                        Label("Every item in a known duplicate group is selected.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                }
                Section("Removal by Source") {
                    ForEach(store.connectedSources) { source in
                        let items = reviewedItems.filter { $0.sourceID == source.id }
                        if !items.isEmpty {
                            Text(source.localizedScanTitle + " · " + items.count.formatted())
                            Text(source.kind == .photos ? LocalizedStringKey("Recently Deleted in Photos") : LocalizedStringKey("Recovery Folder")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Moves in connected cloud folders may sync to other devices.").font(.caption).foregroundStyle(.secondary)
                }
                if (!store.unresolvedSelectionIDs.intersection(store.selectedLibraryIDs).isEmpty || !store.pendingSelection.filter({ store.selectedLibraryIDs.contains($0.id) }).isEmpty) {
                    Section("Unavailable Selected Items") {
                        Text("Reconnect unavailable sources or remove their items from your selection.")
                        Button("Remove Unavailable Items from Selection") { store.discardPendingSelection(); reviewedItems.removeAll { !store.selectedLibraryIDs.contains($0.id) } }
                    }
                }
                Section("Selected Items") {
                    ForEach(reviewedItems) { asset in
                        HStack {
                            MobileAssetThumbnail(asset: asset).frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading) {
                                Text(asset.displayName).lineLimit(2)
                                Text(store.sourceLabel(asset)).font(.caption).foregroundStyle(.secondary)
                                if let date = asset.captureDateDescription { Text(date).font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Button { store.toggleLibrarySelection(asset); reviewedItems.removeAll { $0.id == asset.id } } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }
                                .buttonStyle(.borderless).accessibilityLabel("Remove from selection")
                        }
                    }
                }
            }
            .disabled(store.isCleaningUp)
            .navigationTitle("Review Selection").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(store.isCleaningUp).accessibilityIdentifier("archive.review.close") } }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if store.isCleaningUp { ProgressView(store.cleanupStatus ?? L10n.tr("Removing selected items…")) }
                    Button("Remove Selected Items") {
                        capturedIDs = Set(reviewedItems.map(\.id)); confirm = true
                    }.frame(maxWidth: .infinity).buttonStyle(MobilePrimaryButtonStyle())
                        .disabled(store.librarySelection.isEmpty || (!store.unresolvedSelectionIDs.intersection(store.selectedLibraryIDs).isEmpty || !store.pendingSelection.filter({ store.selectedLibraryIDs.contains($0.id) }).isEmpty) || store.isCleaningUp || store.scanState.isScanning || store.isAnalyzing)
                    if store.scanState.isScanning || store.isAnalyzing { Text("Wait for analysis to finish or cancel it before cleanup.").font(.footnote) }
                }.padding(16).background(.bar)
            }
            .onAppear { reviewedItems = store.librarySelection }
            .interactiveDismissDisabled(store.isCleaningUp)
            .alert("Something went wrong", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .alert("Remove selected items?", isPresented: $confirm) {
                Button("Remove Selected Items", role: .destructive) {
                    Task { completed = await store.cleanupLibrarySelection(expectedIDs: capturedIDs, reviewedAssets: reviewedItems) }
                }
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
}

struct MobileCleanupHubView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Make space for your next moment.").font(.title.bold())
                Text("Browse collections, select photos, and choose what to remove.").foregroundStyle(.secondary)
                if store.connectedSources.isEmpty {
                    NavigationLink { MobileSourceLibraryView() } label: {
                        Label("Connect your library", systemImage: "folder.badge.plus")
                    }.buttonStyle(.borderedProminent)
                } else {
                    NavigationLink { MobileSourceLibraryView() } label: { Label("Scan Sources", systemImage: "checklist") }.frame(minHeight: 44)
                }
                collection("Screenshots", icon: "viewfinder", items: store.scopedAssets.filter { $0.context?.isScreenshot == true })
                collection("Videos by Size", icon: "video", items: store.scopedAssets.filter { $0.mediaKind == .video }.sorted { ($0.byteCount ?? 0) > ($1.byteCount ?? 0) })
                if store.scopedAssets.contains(where: { $0.mediaKind == .video && $0.byteCount == nil }) { Text("Items with unknown size appear after measured items.").font(.footnote).foregroundStyle(.secondary) }
                collection("Live Photos", icon: "livephoto", items: store.scopedAssets.filter { $0.context?.isLivePhoto == true })
                collection("Duplicates & Similar Photos", icon: "square.on.square", items: UnifiedLibraryAdapter.uniqueReferences(store.reviewGroups.flatMap { $0.assets }))
                collection("Worth Reviewing", icon: "camera.metering.center.weighted", items: store.scopedAssets.filter { store.qualityAssessments[$0.id]?.needsReview == true })
                if store.scanState.isScanning || store.isAnalyzing {
                    ProgressView("Analyzing your library…")
                    Button("Cancel Analysis") { store.cancelScan() }.frame(minHeight: 44)
                } else {
                    Button("Find Duplicates & Similar Items") { store.startScan() }
                        .frame(maxWidth: .infinity).buttonStyle(MobilePrimaryButtonStyle()).disabled(!store.canScanSelectedSources)
                }
                if store.skippedSimilarityPreviews > 0 {
                    Text(String(format: L10n.tr("%lld previews could not be analyzed. Results cover only accessible items."), store.skippedSimilarityPreviews)).font(.footnote).foregroundStyle(.secondary)
                }
                if let error = store.similarityError ?? store.videoSimilarityError {
                    Label("Some analysis could not be completed", systemImage: "exclamationmark.triangle").font(.headline)
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(18)
        }
        .background(MobileKeptoraDesign.canvas).navigationTitle("Cleanup")
    }
    private func collection(_ title: String, icon: String, items: [UniversalMediaAsset]) -> some View {
        Button { store.openCollection(items, title: L10n.tr(String.LocalizationValue(title)), sortBySize: title == "Videos by Size", kind: title) } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundStyle(MobileKeptoraDesign.accent).frame(width: 40)
                VStack(alignment: .leading, spacing: 4) { Text(LocalizedStringKey(title)).font(.headline); Text(items.count.formatted()).font(.subheadline).foregroundStyle(.secondary) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.padding(18).frame(maxWidth: .infinity).background(MobileKeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).disabled(store.isCleaningUp).accessibilityIdentifier("cleanup.collection." + title)
    }
}
