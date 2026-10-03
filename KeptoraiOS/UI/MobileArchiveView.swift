import KeptoraCore
import SwiftUI

struct MobileLibraryView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var selecting = false
    @State private var media = 0
    @State private var albumID = ""
    @State private var search = ""
    @State private var oldestFirst = false
    @State private var largestFirst = false
    @State private var grouping = 2
    @State private var groupedResults = false
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
    @State private var undoSelection: Set<String>?
    @State private var frames: [String: CGRect] = [:]
    @State private var dragStart: Int?
    @State private var dragBase: Set<String> = []

    private var visible: [UniversalMediaAsset] {
        let groupedIDs = groupedResults ? Set(store.reviewGroups.flatMap { $0.assets.map(\.id) }) : Set<String>()
        return store.assets.filter { asset in
            (!groupedResults || groupedIDs.contains(asset.id)) &&
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
        ScrollViewReader { proxy in
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
                        } else if groupedResults {
                            if store.reviewGroups.isEmpty {
                                ContentUnavailableView("No groups to review", systemImage: "rectangle.stack", description: Text(store.scanState == .completed ? LocalizedStringKey("No groups found in accessible items.") : LocalizedStringKey("Scan all connected sources to find exact copies and similar photos together.")))
                            }
                            ForEach(store.reviewGroups) { group in
                                let items = group.assets.filter { item in visible.contains { $0.id == item.id } }
                                if !items.isEmpty {
                                    HStack {
                                        Label(group.kind == .exact ? LocalizedStringKey("Exact Copies") : LocalizedStringKey("Similar Photos & Videos"), systemImage: group.kind == .exact ? "doc.on.doc" : "square.stack")
                                            .font(.headline)
                                        Spacer()
                                        Text(items.count.formatted()).foregroundStyle(.secondary)
                                    }
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 150 : 106), spacing: 4)], spacing: 4) {
                                        ForEach(items) { asset in cell(asset, suggestedKeeper: asset.id == group.keeperID) }
                                    }
                                }
                            }
                        } else if visible.isEmpty {
                            ContentUnavailableView("No items in this view", systemImage: "photo", description: Text("Change the filters or choose another source."))
                            Button("Reset Filters") { media = 0; albumID = ""; favouritesOnly = false; dateRangeEnabled = false; search = ""; groupedResults = false; store.libraryCollectionIDs = nil; store.libraryCollectionTitle = nil; store.libraryCollectionKind = nil; store.libraryCollectionSortBySize = false }
                        } else {
                            ForEach(sections, id: \.date) { section in
                                sectionHeader(section)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: typeSize.isAccessibilitySize ? 150 : 106), spacing: 4)], spacing: 4) {
                                    ForEach(section.assets) { asset in cell(asset).id(asset.id) }
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 16)
            }
            .coordinateSpace(name: "archive")
            .onPreferenceChange(ArchiveFrameKey.self) { frames = $0 }
            .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .named("archive")))
                .onChanged { value in
                    guard !store.isCleaningUp, !groupedResults else { return }
                    if case .second(true, let drag?) = value {
                        selecting = true
                        guard let target = frames.first(where: { $0.value.contains(drag.location) })?.key,
                              let index = visible.firstIndex(where: { $0.id == target }) else { return }
                        if dragStart == nil { dragStart = index; dragBase = store.selectedLibraryIDs; undoSelection = dragBase }
                        let start = dragStart ?? index
                        store.selectedLibraryIDs = dragBase.union(visible[min(start, index)...max(start, index)].map(\.id))
                        if let frame = frames[target], drag.location.y > frame.maxY - 8, index + 3 < visible.count {
                            proxy.scrollTo(visible[index + 3].id, anchor: .bottom)
                        }
                    }
                }.onEnded { _ in dragStart = nil; store.saveLibrarySelection() })
            .refreshable { await store.loadCatalogue() }
        }
        .background(MobileKeptoraDesign.canvas)
        .navigationTitle(store.libraryCollectionTitle ?? String(localized: "Library"))
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
                Button(selecting ? "Done" : "Select") { selecting.toggle() }
                    .disabled(store.assets.isEmpty || store.isCleaningUp)
                    .accessibilityIdentifier("archive.selectMode")
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !store.selectedLibraryIDs.isEmpty { selectionBar }
        }
        .confirmationDialog("Download iCloud originals?", isPresented: $cloudScan) {
            Button("Download and Scan") { store.startScan(allowNetwork: true) }
        } message: { Text("This may use network data and device storage. You can cancel the scan at any time.") }
        .sheet(isPresented: $sources, onDismiss: { if pendingFolderPicker { pendingFolderPicker = false; store.present(.filePicker) } }) { NavigationStack { MobileSourceLibraryView(onChooseFolder: { pendingFolderPicker = true; sources = false }).toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { sources = false } } } } }
        .sheet(item: $inspector) { MobilePhotoInspectorSheet(asset: $0, items: visible).environmentObject(store) }
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
        .onChange(of: store.connectedFolders) { _, _ in albumID = ""; media = 0; search = ""; dateRangeEnabled = false; favouritesOnly = false }
        .onChange(of: store.source) { _, _ in undoSelection = nil; dragStart = nil; selecting = false; dateRangeEnabled = false; albumID = ""; search = "" }
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
                Label(store.libraryTitle, systemImage: "photo.stack")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if store.isLoadingCatalogue { ProgressView() }
                Text(visible.count.formatted()).monospacedDigit().foregroundStyle(.secondary)
            }
            Button("Sources") { sources = true }.font(.footnote).frame(minHeight: 44)
            DisclosureGroup("Scan Coverage") {
            ForEach(store.coverage) { report in
                HStack(alignment: .top) {
                    Image(systemName: report.error == nil ? "checkmark.circle" : "exclamationmark.triangle")
                    Text(report.source.displayName)
                    Spacer()
                    Text(report.itemCount.formatted()).monospacedDigit()
                }.font(.caption).foregroundStyle(report.error == nil ? Color.secondary : .orange)
                if report.error != nil { Text("Some items in this source are unavailable. Reconnect or check access.").font(.caption).foregroundStyle(.secondary) }
            }
            ForEach(Array(store.connectionErrors.enumerated()), id: \.offset) { entry in Text(entry.element).font(.caption).foregroundStyle(.orange) }
            Text("Photos includes iCloud Photos and saved WhatsApp albums. Files includes the folders you connect. Private chat storage is excluded.").font(.caption).foregroundStyle(.secondary)
            }
            Text("Connected sources only. Add Photos and folders in Sources.").font(.caption).foregroundStyle(.secondary)
            if store.coverage.contains(where: { $0.error != nil }) || !store.connectionErrors.isEmpty {
                Label("Some sources were not fully scanned. Check Scan Coverage.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange)
            }
            HStack {
                if store.scanState.isScanning || store.isAnalyzing {
                    ProgressView()
                    Button("Cancel Scan") { store.cancelScan() }
                } else {
                    Button("Scan All Sources") { store.startScan() }.buttonStyle(.borderedProminent).accessibilityIdentifier("archive.scanAll")
                    Button("Include Cloud Originals") { cloudScan = true }.font(.footnote)
                }
            }.disabled(store.isCleaningUp || store.isLoadingCatalogue)
            if case .scanning(let processed, let total, let current) = store.scanState {
                ProgressView(value: Double(processed), total: Double(max(total, 1)))
                Text(current).font(.caption).lineLimit(2)
            }
            if store.isAnalyzing { Text("Analysis in progress. Groups may change.").font(.caption).foregroundStyle(.secondary) }
            if let error = store.similarityError ?? store.videoSimilarityError { Text(error).font(.caption).foregroundStyle(.orange) }
            if store.skippedCloudItems > 0 {
                Text(String(format: String(localized: "%lld originals could not be analyzed. They remain in the library."), store.skippedCloudItems)).font(.caption).foregroundStyle(.secondary)
            }
            Picker("Library view", selection: $groupedResults) {
                Text("All Items").tag(false)
                Text("Copies & Similar").tag(true)
            }.pickerStyle(.segmented).accessibilityIdentifier("archive.resultMode")
            if store.authorization == .limited {
                Button("Limited Photos access · Manage Access") { store.manageLimitedPhotosAccess() }.font(.footnote).frame(minHeight: 44)
            }
            if store.libraryCollectionIDs != nil {
                Button("Show Entire Library") { store.libraryCollectionIDs = nil; store.libraryCollectionTitle = nil; store.libraryCollectionSortBySize = false; store.libraryCollectionKind = nil }.frame(minHeight: 44)
            }
            if selecting {
                HStack {
                    Button("Select All in This View") { undoSelection = store.selectedLibraryIDs; store.selectedLibraryIDs.formUnion(visible.map(\.id)) }
                    Spacer()
                    if let previous = undoSelection { Button("Undo") { store.selectedLibraryIDs = previous; undoSelection = nil } }
                }.font(.footnote).frame(minHeight: 44)
            }
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
            Text(section.date == .distantFuture ? String(localized: largestFirst || store.libraryCollectionSortBySize ? "Largest First" : "All Items") : section.date == .distantPast ? String(localized: "Date unknown") : (grouping == 1 ? section.date.formatted(date: .complete, time: .omitted) : section.date.formatted(.dateTime.month(.wide).year())))
                .font(.headline)
            Spacer()
            if selecting {
                Button(section.date == .distantFuture ? "Select All in This View" : grouping == 1 ? "Select Day" : "Select Month") { undoSelection = store.selectedLibraryIDs; store.selectedLibraryIDs.formUnion(section.assets.map(\.id)) }
                    .font(.footnote).frame(minHeight: 44)
            }
        }
    }

    private func cell(_ asset: UniversalMediaAsset, suggestedKeeper: Bool = false) -> some View {
        let selected = store.selectedLibraryIDs.contains(asset.id)
        return Button {
            if selecting { store.toggleLibrarySelection(asset) } else { inspector = asset }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                MobileAssetThumbnail(asset: asset).aspectRatio(1, contentMode: .fit)
                    .overlay(selected ? MobileKeptoraDesign.accent.opacity(0.18) : .clear)
                VStack(alignment: .leading, spacing: 4) {
                    Text(store.sourceLabel(asset)).font(.caption2.weight(.semibold)).lineLimit(2)
                        .padding(.horizontal, 5).padding(.vertical, 3)
                        .foregroundStyle(.white).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4))
                    if suggestedKeeper { Label("Suggested Keep", systemImage: "bookmark.fill").font(.caption2.weight(.semibold)).padding(4).foregroundStyle(.white).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 4)) }
                    Spacer()
                }.padding(5).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                HStack {
                    if asset.isFavorite { Image(systemName: "heart.fill") }
                    if asset.mediaKind == .video { Label(asset.formattedDuration, systemImage: "play.fill") }
                    Spacer()
                    if selecting { Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title2) }
                }
                .font(.caption2.weight(.semibold)).foregroundStyle(.white)
                .padding(8).background(LinearGradient(colors: [.clear, .black.opacity(0.7)], startPoint: .top, endPoint: .bottom))
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(selected ? MobileKeptoraDesign.accent : .clear, lineWidth: 3))
            .background(GeometryReader { geo in Color.clear.preference(key: ArchiveFrameKey.self, value: [asset.id: geo.frame(in: .named("archive"))]) })
        }
        .buttonStyle(.plain).disabled(store.isCleaningUp)
        .accessibilityLabel(asset.displayName + ", " + store.sourceLabel(asset))
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityHint(selecting ? "Tap to change selection" : "Tap to preview. Hold and drag to select multiple items.")
        .accessibilityAddTraits(selected ? .isSelected : [])
        .accessibilityIdentifier("archive.asset.\(asset.id)")
    }

    private var selectionBar: some View {
        VStack(spacing: 8) {
            HStack {
                let summary = MediaSelectionSummary(store.librarySelection)
                VStack(alignment: .leading, spacing: 4) {
                    Text(String(format: String(localized: "Selected items: %lld"), store.librarySelection.count)).font(.headline)
                    Text(String(format: String(localized: "Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.caption).foregroundStyle(.secondary)
                    let hidden = store.selectedLibraryIDs.subtracting(visible.map(\.id)).count
                    if hidden > 0 { Text(String(format: String(localized: "%lld selected outside this view"), hidden)).font(.caption).foregroundStyle(.secondary) }
                }
                Spacer()
                Button { undoSelection = store.selectedLibraryIDs; store.selectedLibraryIDs.removeAll() } label: { Image(systemName: "xmark.circle").frame(width: 44, height: 44) }
                    .accessibilityLabel("Clear Selection")
                Button("Review Selection") { reviewSelection = true }.buttonStyle(.borderedProminent)
            }
        }.padding(14).background(.bar)
    }
}

private struct ArchiveFrameKey: PreferenceKey {
    static var defaultValue: [String: CGRect] = [:]
    static func reduce(value: inout [String: CGRect], nextValue: () -> [String: CGRect]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

struct MobileSelectionReviewSheet: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    @State private var capturedIDs: Set<String> = []
    @State private var completed = false
    private var summary: MediaSelectionSummary { MediaSelectionSummary(store.librarySelection) }
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text(String(format: String(localized: "Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.title2.bold())
                    Label(store.libraryTitle, systemImage: "photo.stack")
                    Text(ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file) + " · " + String(localized: "Media size, not freed space")).foregroundStyle(.secondary)
                    if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.footnote) }
                    Text("Photos items move to Recently Deleted and iCloud changes sync across devices. Files move to a recovery folder on the same storage; this does not free disk space. Completed steps appear in History if cleanup stops partway.")
                        .font(.footnote).foregroundStyle(.secondary)
                    if summary.personalItems > 0 { Label("Includes favorites, edited or album items you selected manually.", systemImage: "exclamationmark.triangle").font(.footnote) }
                    if store.exactGroups.contains(where: { $0.assets.allSatisfy { store.selectedLibraryIDs.contains($0.id) } }) {
                        Label("Every item in a known duplicate group is selected.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                    }
                }
                Section("Removal by Source") {
                    ForEach(store.connectedSources) { source in
                        let items = store.librarySelection.filter { $0.sourceID == source.id }
                        if !items.isEmpty {
                            Text(source.displayName + " · " + items.count.formatted())
                            Text(source.kind == .photos ? LocalizedStringKey("Recently Deleted in Photos") : LocalizedStringKey("Recovery Folder")).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Text("Moves in connected cloud folders may sync to other devices.").font(.caption).foregroundStyle(.secondary)
                }
                Section("Selected Items") {
                    ForEach(store.librarySelection) { asset in
                        HStack {
                            MobileAssetThumbnail(asset: asset).frame(width: 60, height: 60).clipShape(RoundedRectangle(cornerRadius: 8))
                            VStack(alignment: .leading) {
                                Text(asset.displayName).lineLimit(2)
                                Text(store.sourceLabel(asset)).font(.caption).foregroundStyle(.secondary)
                                if let date = asset.captureDateDescription { Text(date).font(.caption).foregroundStyle(.secondary) }
                            }
                            Spacer()
                            Button { store.toggleLibrarySelection(asset) } label: { Image(systemName: "minus.circle").frame(width: 44, height: 44) }
                                .buttonStyle(.borderless).accessibilityLabel("Remove from selection")
                        }
                    }
                }
            }
            .disabled(store.isCleaningUp)
            .navigationTitle("Review Selection").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.disabled(store.isCleaningUp) } }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if store.isCleaningUp { ProgressView(store.cleanupStatus ?? String(localized: "Removing selected items…")) }
                    Button("Remove Selected Items") {
                        capturedIDs = store.selectedLibraryIDs; confirm = true
                    }.frame(maxWidth: .infinity).buttonStyle(MobilePrimaryButtonStyle())
                        .disabled(store.librarySelection.isEmpty || store.isCleaningUp || store.scanState.isScanning || store.isAnalyzing)
                    if store.scanState.isScanning || store.isAnalyzing { Text("Wait for analysis to finish or cancel it before cleanup.").font(.footnote) }
                }.padding(16).background(.bar)
            }
            .interactiveDismissDisabled(store.isCleaningUp)
            .alert("Something went wrong", isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
                Button("OK") { store.errorMessage = nil }
            } message: { Text(store.errorMessage ?? "") }
            .alert("Remove selected items?", isPresented: $confirm) {
                Button("Remove Selected Items", role: .destructive) {
                    Task { completed = await store.cleanupLibrarySelection(expectedIDs: capturedIDs) }
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
    @State private var whatsAppAlbumIDs: Set<String> = Set(UserDefaults.standard.stringArray(forKey: "Keptora.WhatsAppAlbumIDs") ?? [])
    @State private var showGuide = false
    @State private var pendingFolderPicker = false
    private var whatsAppAssets: [UniversalMediaAsset] {
        store.assets.filter { item in item.context?.albums.contains { $0.isWhatsAppNamed || whatsAppAlbumIDs.contains($0.id) } == true }
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Make space for your next moment.").font(.title.bold())
                Text("Browse collections, compare suggestions, and choose what to remove.").foregroundStyle(.secondary)
                collection("WhatsApp Media", icon: "message", items: whatsAppAssets)
                Text("This collection uses album membership. Removing a saved copy from Photos does not remove it from WhatsApp chats.")
                    .font(.footnote).foregroundStyle(.secondary)
                Menu("Choose WhatsApp Albums") {
                    ForEach(store.albums) { album in
                        Button {
                            if !whatsAppAlbumIDs.insert(album.id).inserted { whatsAppAlbumIDs.remove(album.id) }
                            UserDefaults.standard.set(Array(whatsAppAlbumIDs), forKey: "Keptora.WhatsAppAlbumIDs")
                        } label: { Label(album.title, systemImage: whatsAppAlbumIDs.contains(album.id) ? "checkmark" : "square") }
                    }
                    if store.albums.isEmpty { Text("Connect Photos to choose an album.") }
                }.frame(minHeight: 44)
                HStack {
                    Button("Select in Library") { store.libraryCollectionIDs = nil; store.libraryCollectionTitle = nil; store.libraryCollectionSortBySize = false; store.libraryCollectionKind = nil; store.selectedTab = .library }
                    Spacer()
                    Button("WhatsApp Storage Guide") { showGuide = true }
                }.font(.footnote).frame(minHeight: 44)
                collection("Screenshots", icon: "viewfinder", items: store.assets.filter { $0.context?.isScreenshot == true })
                collection("Videos by Size", icon: "video", items: store.assets.filter { $0.mediaKind == .video }.sorted { ($0.byteCount ?? 0) > ($1.byteCount ?? 0) })
                if store.assets.contains(where: { $0.mediaKind == .video && $0.byteCount == nil }) { Text("Items with unknown size appear after measured items.").font(.footnote).foregroundStyle(.secondary) }
                collection("Live Photos", icon: "livephoto", items: store.assets.filter { $0.context?.isLivePhoto == true })
                NavigationLink {
                    MobileReviewView()
                } label: {
                    Label("Duplicates & Similar Photos", systemImage: "square.on.square").font(.headline).frame(maxWidth: .infinity, alignment: .leading).padding(18)
                }.buttonStyle(.plain).background(MobileKeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16)).accessibilityIdentifier("cleanup.comparisons")
                if store.scanState.isScanning || store.isAnalyzing {
                    ProgressView("Analyzing your library…")
                    Button("Cancel Analysis") { store.cancelScan() }.frame(minHeight: 44)
                } else {
                    Button("Find Duplicates & Similar Items") { store.startScan() }
                        .frame(maxWidth: .infinity).buttonStyle(MobilePrimaryButtonStyle()).disabled(store.source == .none || store.isCleaningUp)
                }
                if store.skippedSimilarityPreviews > 0 {
                    Text(String(format: String(localized: "%lld previews could not be analyzed. Results cover only accessible items."), store.skippedSimilarityPreviews)).font(.footnote).foregroundStyle(.secondary)
                }
                if let error = store.similarityError ?? store.videoSimilarityError {
                    Label("Some analysis could not be completed", systemImage: "exclamationmark.triangle").font(.headline)
                    Text(error).font(.footnote).foregroundStyle(.secondary)
                }
            }.padding(18)
        }
        .background(MobileKeptoraDesign.canvas).navigationTitle("Cleanup")
        .sheet(isPresented: $showGuide, onDismiss: { if pendingFolderPicker { pendingFolderPicker = false; store.present(.filePicker) } }) {
            NavigationStack {
                List {
                    Text("To manage media kept inside WhatsApp, open WhatsApp → Settings → Storage and Data → Manage Storage.")
                    Text("Keptora can clean copies saved in Photos or folders you choose. It cannot access WhatsApp's private chat storage.")
                    Button("Choose an Exported Folder") { pendingFolderPicker = true; showGuide = false }
                }.navigationTitle("WhatsApp Storage Guide")
                    .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { showGuide = false } } }
            }
        }
    }
    private func collection(_ title: String, icon: String, items: [UniversalMediaAsset]) -> some View {
        Button { store.openCollection(items, title: String(localized: String.LocalizationValue(title)), sortBySize: title == "Videos by Size", kind: title) } label: {
            HStack(spacing: 14) {
                Image(systemName: icon).font(.title2).foregroundStyle(MobileKeptoraDesign.accent).frame(width: 40)
                VStack(alignment: .leading, spacing: 4) { Text(LocalizedStringKey(title)).font(.headline); Text(items.count.formatted()).font(.subheadline).foregroundStyle(.secondary) }
                Spacer(); Image(systemName: "chevron.right").foregroundStyle(.secondary)
            }.padding(18).frame(maxWidth: .infinity).background(MobileKeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16))
        }.buttonStyle(.plain).disabled(store.isCleaningUp)
    }
}
