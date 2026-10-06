import AppKit
import KeptoraCore
import Photos
import SwiftUI

struct MacScanSourcesSection: View {
    @EnvironmentObject private var archive: MacArchiveModel
    private var masterSymbol: String {
        switch archive.sourceSelectionState {
        case .none: return "square"
        case .some: return "minus.square.fill"
        case .all: return "checkmark.square.fill"
        }
    }
    private var masterValue: LocalizedStringKey {
        switch archive.sourceSelectionState {
        case .none: return "Not selected"
        case .some: return "Partially selected"
        case .all: return "Selected"
        }
    }
    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 10) {
                Button { archive.toggleAllScanSources() } label: {
                    Label("All Connected Sources", systemImage: masterSymbol).font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).accessibilityValue(Text(masterValue)).accessibilityIdentifier("sources.selectAll")
                    .disabled(archive.sourceControlsDisabled || LibrarySourceSelection().selectedIDs(in: archive.connectedSources, coverage: archive.coverage).isEmpty)
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(archive.connectedSources) { source in
                        let report = archive.coverage.first { $0.id == source.id }
                        let available = report == nil || report?.authorization == .authorized || report?.authorization == .limited
                        let selected = archive.selectedSourceIDs.contains(source.id)
                        Button { archive.toggleScanSource(source.id) } label: {
                            HStack(spacing: 10) {
                                Image(systemName: selected ? "checkmark.square.fill" : "square").foregroundStyle(selected ? KeptoraDesign.accent : Color.secondary)
                                Image(systemName: source.scanSymbol).foregroundStyle(.secondary).frame(width: 22)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.kind == .photos ? L10n.tr("Photos / iCloud Photos") : source.displayName)
                                    if let report {
                                        (report.error == nil ? Text(String(format: L10n.tr("%lld items"), report.itemCount)) : Text("Count incomplete")).monospacedDigit().foregroundStyle(.secondary)
                                        Text(LocalizedStringKey(report.statusKey)).font(.caption)
                                            .foregroundStyle(report.error != nil || report.authorization == .limited ? Color.orange : Color.secondary)
                                    } else { Text("Loading item count…").foregroundStyle(.secondary) }
                                }
                                Spacer(minLength: 0)
                            }.padding(.vertical, 6).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading).contentShape(Rectangle())
                        }.buttonStyle(.plain).disabled(archive.sourceControlsDisabled || !available)
                            .accessibilityValue(Text(selected ? LocalizedStringKey("Selected") : LocalizedStringKey("Not selected")))
                            .accessibilityIdentifier("sources.source." + source.id)
                    }
                }
                Divider()
                if archive.selectedSourceIDs.isEmpty {
                    Text("Select at least one source").foregroundStyle(.secondary).accessibilityIdentifier("sources.emptySelection")
                } else {
                    Text(L10n.format("%lld sources selected · %lld different items", archive.selectedSourceIDs.count, archive.scopedAssets.count))
                        .foregroundStyle(.secondary).accessibilityIdentifier("sources.summary")
                }
                Text("Selected sources appear together. The same item in overlapping folders is counted once.").font(.caption).foregroundStyle(.secondary)
                Text("Unticking a source keeps its connection. You can include it again later.").font(.caption).foregroundStyle(.secondary)
            }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct MacSourceSetupView: View {
    var isStartupSetup = false
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKeys.macSourceSetupCompleted) private var sourceSetupCompleted = false
    private var controlsDisabled: Bool { archive.busy || archive.analyzing || archive.loading || archive.isRequestingPhotosAccess }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Image("onboarding_privacy").resizable().scaledToFit().frame(maxHeight: 150)
                        .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                    Text("Connect your library").font(.title.bold())
                    Text("Connect Photos and folders once. Choose which sources to include in each scan.").foregroundStyle(.secondary)
                    if archive.isRequestingPhotosAccess { ProgressView("Waiting for Photos access…") }
                    if !archive.connectedSources.isEmpty { MacScanSourcesSection() }
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Photos", systemImage: "photo.on.rectangle.angled").font(.headline)
                            Text("Full Photos access includes iCloud Photos. Limited access shows only the items you approve.")
                            if archive.photosConnected { Label("Photos Connected", systemImage: "checkmark.circle.fill").foregroundStyle(.green) }
                            else if archive.authorization == .notDetermined {
                                Button("Connect Photos") { archive.connectPhotos() }
                            } else {
                                Text(archive.authorization == .unavailable ? LocalizedStringKey("Photos is not available on this device.") : (archive.authorization == .restricted ? LocalizedStringKey("Access is restricted on this device.") : LocalizedStringKey("Photos access disabled")))
                                if archive.authorization == .denied {
                                    Button { archive.openPhotosSettings() } label: { Text("Open Settings").frame(minHeight: 32) }
                                        .accessibilityIdentifier("mac.sourceSetup.openSettings")
                                }
                            }
                            if archive.authorization == .limited {
                                Text("Limited Photos access").foregroundStyle(.orange)
                                Button("Manage Access") { archive.openPhotosSettings() }
                            }
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Files & cloud folders", systemImage: "folder.badge.plus").font(.headline)
                            Text("Choose Pictures, Downloads, iCloud Drive or another cloud folder. Keptora remembers folders you approve; other apps' private storage is unavailable.")
                            Text("Cloud providers may download files according to their own settings.").font(.callout).foregroundStyle(.secondary)
                            ForEach(archive.connectedFolders) { folder in Label(folder.displayName, systemImage: "checkmark.circle") }
                            Button { archive.chooseFolder() } label: { Text("Add Folders…").frame(minHeight: 32) }
                                .accessibilityIdentifier("mac.sourceSetup.folders")
                        }.frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Text("No camera, microphone, contacts or live location permission is needed. Existing photo details are read only from media you approve.").font(.callout).foregroundStyle(.secondary)
                    Text("You can continue without access and add sources later.").font(.callout).foregroundStyle(.secondary)
                    ForEach(Array(archive.connectionErrors.enumerated()), id: \.offset) { entry in Text(entry.element).foregroundStyle(.orange) }
                }.padding(24).disabled(controlsDisabled)
            }
            Divider()
            HStack {
                Spacer()
                Button {
                    if isStartupSetup { sourceSetupCompleted = true }
                    dismiss()
                } label: { Text(isStartupSetup ? LocalizedStringKey("Continue to Library") : LocalizedStringKey("Done")).frame(minHeight: 32) }
                    .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(archive.isRequestingPhotosAccess)
                    .accessibilityIdentifier("mac.sourceSetup.continue")
            }.padding(18)
        }
        .controlSize(.large)
        .frame(minWidth: 480, idealWidth: 650, maxWidth: 800, minHeight: 480, idealHeight: 600, maxHeight: 800)
        .accessibilityIdentifier("mac.sourceSetup")
        .interactiveDismissDisabled(isStartupSetup)
        .task {
            if isStartupSetup, LibraryAccessPolicy.shouldRequestPhotosAtStartup(archive.authorization) {
                await archive.requestPhotosAccess(showError: false)
            }
        }
        .alert("Something went wrong", isPresented: Binding(get: { archive.error != nil }, set: { if !$0 { archive.error = nil } })) {
            Button("OK", role: .cancel) { archive.error = nil }
        } message: { Text(archive.error ?? "") }
    }
}

struct MacArchiveView: View {
    @EnvironmentObject private var archive: MacArchiveModel
    private var search: String {
        get { archive.galleryContext.search }
        nonmutating set { archive.galleryContext.search = newValue; archive.contextChanged() }
    }
    private var finding: LibraryFindingFilter {
        get { archive.galleryContext.finding }
        nonmutating set { archive.galleryContext.finding = newValue; archive.contextChanged() }
    }
    private var smartOrder: Bool {
        get { archive.galleryContext.smartOrder }
        nonmutating set { archive.galleryContext.smartOrder = newValue; archive.contextChanged() }
    }
    @State private var cloudScan = false
    private var media: Int {
        get { archive.galleryContext.media }
        nonmutating set { archive.galleryContext.media = newValue; archive.contextChanged() }
    }
    private var albumID: String {
        get { archive.galleryContext.albumID }
        nonmutating set { archive.galleryContext.albumID = newValue; archive.contextChanged() }
    }
    @State private var showPlan = false
    @State private var inspected: UniversalMediaAsset?
    @State private var previewNetwork = false
    @State private var showAccessGuide = false
    @FocusState private var keyboardFocus: String?
    @State private var rangeAnchor: String?
    @State private var galleryColumns = 4
    private func contextBinding<Value>(_ key: WritableKeyPath<MacGalleryContext, Value>) -> Binding<Value> {
        Binding(get: { archive.galleryContext[keyPath: key] }, set: { archive.galleryContext[keyPath: key] = $0; archive.contextChanged() })
    }
    private var orderedVisible: [UniversalMediaAsset] {
        smartOrder ? LibraryReviewBlock.make(assets: visible, groups: archive.reviewGroups, quality: archive.qualityAssessments, smart: true).flatMap(\.assets) : visible
    }
    private var visible: [UniversalMediaAsset] {
        let findingIDs = finding.ids(groups: archive.reviewGroups, quality: archive.qualityAssessments)
        return archive.scopedAssets.filter { item in
            (findingIDs == nil || findingIDs!.contains(item.id)) &&
            (media == 0 || (media == 1 ? item.mediaKind == .image : item.mediaKind == .video)) &&
            (albumID.isEmpty || item.context?.albums.contains { $0.id == albumID } == true) &&
            (search.isEmpty || item.displayName.localizedCaseInsensitiveContains(search))
        }.sorted { ($0.context?.captureDate ?? $0.creationDate ?? .distantPast) > ($1.context?.captureDate ?? $1.creationDate ?? .distantPast) }
    }
    var body: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView { catalogueContent }.coordinateSpace(name: "mac-gallery")
                    .background(GeometryReader { geometry in
                        Color.clear.onAppear { galleryColumns = max(1, Int((geometry.size.width - 28) / 172)) }
                            .onChange(of: geometry.size.width) { width in galleryColumns = max(1, Int((width - 28) / 172)) }
                    })
                    .onAppear { if let id = archive.scrollAnchorID { proxy.scrollTo(id, anchor: .center) }; keyboardFocus = archive.focusedAssetID }
                    .onPreferenceChange(MacGalleryPositions.self) { positions in
                        if let first = positions.filter({ $0.value >= 0 }).min(by: { $0.value < $1.value }), archive.scrollAnchorID != first.key {
                            archive.recordScrollAnchor(first.key)
                        }
                    }
                    .onChange(of: keyboardFocus) { id in archive.recordFocus(id); if let id { proxy.scrollTo(id, anchor: .center) } }
            }
            if !archive.selection.isEmpty || archive.canUndoSelection {
                Divider()
                VStack(alignment: .leading, spacing: 12) {
                    let summary = MediaSelectionSummary(archive.selected)
                    VStack(alignment: .leading) {
                        Text(String(format: L10n.tr("Selected items: %lld"), archive.selection.count)).font(.headline)
                        Text(String(format: L10n.tr("Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.headline)
                        Text(ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file) + " · " + L10n.tr("Media size, not freed space")).font(.caption).foregroundStyle(.secondary)
                        if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.caption).foregroundStyle(.secondary) }
                        let hidden = archive.selection.subtracting(visible.map(\.id)).count
                        if hidden > 0 { Text(String(format: L10n.tr("%lld selected outside this view"), hidden)).font(.caption).foregroundStyle(.secondary) }
                    }
                    if let status = archive.status { HStack { ProgressView().controlSize(.small); Text(status).font(.caption) } }
                    selectionActions
                }.padding(16).disabled(archive.busy || archive.loading)
            }
        }
        .controlSize(.large)
        .background(KeptoraDesign.canvas)
        .background(MacGalleryKeyboardMonitor { archive.selectItems(visible) })
        .accessibilityIdentifier("mac.page.archive")
        .sheet(isPresented: $showPlan) { MacManualSelectionSheet().environmentObject(archive) }
        .sheet(item: $inspected) { item in
            VStack(spacing: 14) {
                MacPhotosThumbnail(asset: item, pixelSize: 1600, fit: true, allowNetwork: previewNetwork).frame(minWidth: 600, minHeight: 420)
                Text(item.displayName).font(.headline)
                Text(archive.sourceLabel(item)).font(.caption).foregroundStyle(.secondary)
                if !previewNetwork && (item.requiresNetwork || { if case .photoLibrary = item.reference { return true }; return false }()) { Button("Download Preview from iCloud") { previewNetwork = true } }
                if let date = item.captureDateDescription { Text(date) }
                if let context = item.context, let camera = context.camera { Text(camera) }
                if let location = item.context?.location { Text(String(format: "%.5f, %.5f", location.latitude, location.longitude)) }
                HStack { Button("Close") { inspected = nil }; Button(archive.selection.contains(item.id) ? "Deselect" : "Select") { archive.toggleSelection(item) } }
            }.padding(20)
        }
        .onChange(of: inspected?.id) { _ in previewNetwork = false }
        .sheet(isPresented: $showAccessGuide) { MacSourceSetupView().environmentObject(archive) }
        .confirmationDialog("Download cloud originals?", isPresented: $cloudScan) {
            Button("Download and Scan") { archive.analyze(allowNetwork: true) }
        } message: { Text("This may use network data and device storage. You can cancel the scan at any time.") }
        .onChange(of: archive.scanSourceSelection) { _ in finding = .all; albumID = ""; media = 0; search = "" }
    }
    private var catalogueContent: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { headerSummary; Spacer(minLength: 12); headerActions }
                VStack(alignment: .leading, spacing: 12) { headerSummary; headerActions }
            }.padding(20).disabled(archive.busy || archive.analyzing)
            if !archive.connectedSources.isEmpty {
                Button { showAccessGuide = true } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Sources", systemImage: "checklist")
                            Text(archive.connectedSources.filter { archive.selectedSourceIDs.contains($0.id) }.map(\.localizedScanTitle).joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                        }
                        Spacer(); Text(L10n.format("%lld selected", archive.selectedSourceIDs.count)); Image(systemName: "chevron.right")
                    }.frame(minHeight: 44).contentShape(Rectangle())
                }.padding(.horizontal, 20).padding(.bottom, 12).accessibilityIdentifier("mac.archive.sourcesSummary")
            }
            DisclosureGroup("Source Access") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Photos includes iCloud Photos. Files includes the folders you connect.").font(.callout).foregroundStyle(.secondary)
                    Text("Cloud providers may download files according to their own settings.").font(.caption).foregroundStyle(.secondary)
                    Button("Permissions & Sources") { showAccessGuide = true }
                    ForEach(archive.coverage) { report in
                        HStack {
                            Label(report.source.localizedScanTitle, systemImage: report.error == nil ? "checkmark.circle" : "exclamationmark.triangle")
                            Spacer(); Text(report.itemCount.formatted())
                        }.font(.callout)
                        if report.error != nil { Text("Some items in this source are unavailable. Reconnect or check access.").font(.caption).foregroundStyle(.orange) }
                    }
                    ForEach(archive.connectedFolders) { folder in
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) { folderControls(folder) }
                            VStack(alignment: .leading, spacing: 8) { folderControls(folder) }
                        }
                    }
                    ForEach(Array(archive.connectionErrors.enumerated()), id: \.offset) { entry in Text(entry.element).font(.caption).foregroundStyle(.orange) }
                }
            }.padding(.horizontal, 20).padding(.bottom, 12).disabled(archive.busy || archive.loading || archive.analyzing)
            if archive.coverage.contains(where: { $0.error != nil }) || !archive.connectionErrors.isEmpty {
                Label("Some sources have limited access. Check Source Access.", systemImage: "exclamationmark.triangle").font(.caption).foregroundStyle(.orange).padding(12)
                Button("Manage Source Access") { showAccessGuide = true }.buttonStyle(.bordered).padding(.bottom, 12)
            }
            Divider()
            if archive.assets.isEmpty && !archive.loading {
                VStack(spacing: 16) {
                    Image("onboarding_privacy").resizable().scaledToFit().frame(maxWidth: 520).clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
                    Text("Your photos. Your choice.").font(.largeTitle.bold())
                    Text("Open Photos or a folder. Select any photo or video without waiting for duplicate analysis.").foregroundStyle(.secondary)
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                filters
                if archive.loading { ProgressView("Loading your library…").padding() }
                if archive.selectedSourceIDs.isEmpty {
                    Text("Select at least one source").font(.headline).padding()
                    Text("Open Sources and select at least one source.").foregroundStyle(.secondary)
                    Button("Sources") { showAccessGuide = true }
                }
                if archive.authorization == .limited {
                    Text("Limited Photos access. Keptora can only show the items you allow.").font(.callout).foregroundStyle(.secondary).padding(.horizontal, 20)
                    Button("Manage Access") { archive.openPhotosSettings() }.padding(.bottom, 8)
                }
                if archive.skippedPreviews > 0 {
                    Text(String(format: L10n.tr("%lld previews could not be analyzed. Results cover only accessible items."), archive.skippedPreviews)).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
                if archive.skippedCloudItems > 0 {
                    Text(String(format: L10n.tr("%lld originals could not be analyzed. They remain in the library."), archive.skippedCloudItems)).font(.caption).foregroundStyle(.secondary).padding(.horizontal, 20)
                }
                ViewThatFits(in: .horizontal) {
                    findingPicker.pickerStyle(.segmented)
                    findingPicker.pickerStyle(.menu)
                }.frame(maxWidth: 640).padding(12)
                if finding == .copies { exactBatchSelection.padding(.horizontal, 20) }
                if archive.sessionProgress.isFinished && !archive.sessionProgress.isComplete && !archive.sessionProgress.stages.values.contains(where: { $0.status == .cancelled }) {
                    Label("Analysis partially completed. Some items need attention.", systemImage: "exclamationmark.triangle").font(.caption).padding(.horizontal, 20)
                }
                if !archive.analysisIssues.isEmpty {
                    DisclosureGroup("Items needing attention") {
                        ForEach(AnalysisIssueReason.allCases, id: \.rawValue) { reason in
                            let count = Set(archive.analysisIssues.filter { $0.reason == reason }.map(\.assetID)).count
                            if count > 0 { HStack { Text(LocalizedStringKey(reason.titleKey)); Spacer(); Text(count.formatted()) } }
                        }
                    }.padding(.horizontal, 20)
                }
                VStack(spacing: 0) {
                    Text("Click a photo to select or deselect it.").font(.caption).foregroundStyle(.secondary).padding(.top, 12)
                    if visible.isEmpty && !archive.loading && !archive.selectedSourceIDs.isEmpty {
                        if archive.analyzing { Text("Results appear as they become available.").foregroundStyle(.secondary).padding(30) }
                        else {
                            VStack(spacing: 12) {
                                Text("No items in this view").font(.headline)
                                Text("Change the filters or choose another source.").foregroundStyle(.secondary)
                                Button("Reset Filters") { resetFilters() }.accessibilityIdentifier("mac.archive.resetFilters")
                            }.padding(30)
                        }
                    }
                    if smartOrder {
                        let candidatesByGroup = archive.decisions.candidatesByGroup(archive.reviewGroups)
                        let visibleIDs = Set(visible.map(\.id))
                        let blocks = LibraryReviewBlock.make(assets: visible, groups: archive.reviewGroups, quality: archive.qualityAssessments, smart: true)
                        LazyVStack(alignment: .leading, spacing: 16) {
                            ForEach(blocks) { block in
                                let membership = block.groupsByAsset
                                let keeperBadges = archive.decisions.keeperBadgeKeys(in: block.groups)
                                Text(LocalizedStringKey(block.titleKey)).font(.headline)
                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 250), spacing: 12)], spacing: 12) {
                                    ForEach(block.assets) { item in archiveCell(item, groups: membership[item.id] ?? [], keeperBadge: keeperBadges[item.id]) }
                                }
                                ForEach(block.groups) { group in
                                    groupActions(group, candidates: (candidatesByGroup[group.id] ?? []).filter { visibleIDs.contains($0.id) }, itemCount: group.assets.filter { visibleIDs.contains($0.id) }.count)
                                }
                            }
                        }.padding(20)
                    } else {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 250), spacing: 12)], spacing: 12) {
                        ForEach(visible) { item in
                            archiveCell(item)
                        }
                    }.padding(20)
                    }
                }.disabled(archive.busy)

            }
        }.frame(maxWidth: .infinity)
    }
    private var headerSummary: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Photo Library").font(.title2.bold())
            Text(archive.sourceSelectionState == .all ? LocalizedStringKey("All Connected Sources") : LocalizedStringKey("Selected Sources")).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private func folderControls(_ folder: LibrarySource) -> some View {
        Text(folder.displayName)
        Button("Disconnect") { archive.disconnectFolder(folder.id) }
    }
    private var findingPicker: some View {
        Picker("Library view", selection: contextBinding(\.finding)) {
            ForEach(LibraryFindingFilter.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) }
        }
    }
    private var headerActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { headerButtons }
            VStack(alignment: .leading, spacing: 8) { headerButtons }
        }
    }
    @ViewBuilder private var headerButtons: some View {
        Button { archive.connectPhotos() } label: { Text(archive.photosConnected ? LocalizedStringKey("Photos Connected") : LocalizedStringKey("Connect Photos")) }
        Button("Add Folders…") { archive.chooseFolder() }
        Button { archive.refresh() } label: { Image(systemName: "arrow.clockwise").frame(width: 32, height: 32).contentShape(Rectangle()) }
            .help("Refresh Library").accessibilityLabel("Refresh Library")
    }
    private var selectionActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { secondarySelectionActions; Spacer(minLength: 12); reviewSelectionButton }
            VStack(alignment: .leading, spacing: 8) { secondarySelectionActions; reviewSelectionButton }
        }
    }
    private var secondarySelectionActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { secondarySelectionButtons }
            VStack(alignment: .leading, spacing: 8) { secondarySelectionButtons }
        }
    }
    @ViewBuilder private var secondarySelectionButtons: some View {
        if archive.canUndoSelection {
            Button("Undo Selection") { archive.undoSelection() }.accessibilityIdentifier("mac.archive.undoSelection")
        }
        Button("Clear All Selections") { archive.setSelection([]) }.disabled(archive.selection.isEmpty)
    }
    private var reviewSelectionButton: some View {
        Button { showPlan = true } label: { Text(L10n.format("Review Selection (%lld)", archive.selection.count)).frame(minHeight: 32) }
            .buttonStyle(.borderedProminent).disabled(archive.selection.isEmpty).accessibilityIdentifier("mac.archive.reviewSelection")
    }
    private var exactBatchSelection: some View {
        let scope = Set(visible.map(\.id))
        let candidates = archive.exactSuggestionCandidates(visibleIDs: scope)
        let remaining = candidates.filter { !archive.selection.contains($0.id) }.count
        return Group {
            if !candidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button { archive.selectExactSuggestions(visibleIDs: scope) } label: {
                        if remaining == 0 { Text("Extra Copies Selected") }
                        else { Text(L10n.format("Select Extra Copies (%lld)", remaining)) }
                    }.disabled(remaining == 0).accessibilityIdentifier("mac.archive.selectExtraCopies")
                    Text("Items suggested to keep and protected items stay unselected.").font(.caption).foregroundStyle(.secondary)
                }.padding(.bottom, 8)
            }
        }.disabled(archive.busy || archive.loading || archive.analyzing)
    }
    private func groupActions(_ group: LibraryReviewGroup, candidates: [UniversalMediaAsset], itemCount: Int) -> some View {
        let remaining = candidates.filter { !archive.selection.contains($0.id) }.count
        return VStack(alignment: .leading, spacing: 4) {
            Text(L10n.format("%@ · %lld items", L10n.tr(String.LocalizationValue(group.titleKey)), itemCount)).font(.caption.weight(.semibold))
            Text(LocalizedStringKey(archive.decisions.keeperReason(in: group, quality: archive.qualityAssessments))).font(.caption).foregroundStyle(.secondary)
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { groupButtons(group, candidates: candidates, remaining: remaining) }
                VStack(alignment: .leading, spacing: 8) { groupButtons(group, candidates: candidates, remaining: remaining) }
            }
        }.disabled(archive.busy || archive.analyzing)
    }
    @ViewBuilder private func groupButtons(_ group: LibraryReviewGroup, candidates: [UniversalMediaAsset], remaining: Int) -> some View {
        Button { archive.selectOthers(in: group, visibleIDs: Set(candidates.map(\.id))) } label: {
            if candidates.isEmpty { Text("No Other Items to Select") }
            else if remaining == 0 { Text("Others Selected") }
            else { Text(L10n.format("Select Others (%lld)", remaining)) }
        }.disabled(remaining == 0).accessibilityIdentifier("mac.archive.others.\(group.id)")
        Menu("Group Actions") { Button("Protect Group") { archive.protect(group) } }
    }
    private func selectByClick(_ item: UniversalMediaAsset) {
        if NSEvent.modifierFlags.contains(.shift), let anchor = rangeAnchor {
            archive.selectItems(LibraryRangeSelection.items(from: anchor, through: item.id, in: orderedVisible))
        } else { archive.toggleSelection(item); rangeAnchor = item.id }
        keyboardFocus = item.id
    }
    private func moveFocus(_ direction: MoveCommandDirection) {
        let items = orderedVisible
        guard let index = items.firstIndex(where: { $0.id == keyboardFocus }), !items.isEmpty else { return }
        let step = direction == .left ? -1 : direction == .right ? 1 : direction == .up ? -galleryColumns : galleryColumns
        let next = items[max(0, min(items.count - 1, index + step))]
        if NSEvent.modifierFlags.contains(.shift) {
            let anchor = rangeAnchor ?? items[index].id
            rangeAnchor = anchor
            archive.selectItems(LibraryRangeSelection.items(from: anchor, through: next.id, in: items))
        }
        keyboardFocus = next.id
    }
    private func resetFilters() { media = 0; albumID = ""; search = ""; finding = .all; smartOrder = true }
    private func archiveCell(_ item: UniversalMediaAsset, groups: [LibraryReviewGroup] = [], keeperBadge: String? = nil) -> some View {
        let selected = archive.selection.contains(item.id)
        let kept = !selected && keeperBadge != nil
        let keeperLabel = keeperBadge ?? "Suggested Keep"
        return VStack(alignment: .leading, spacing: 8) {
                                Button { selectByClick(item) } label: {
                                    MacPhotosThumbnail(asset: item).frame(height: 160).clipShape(RoundedRectangle(cornerRadius: 12))
                                        .allowsHitTesting(false).accessibilityHidden(true)
                                        .overlay(selected ? Color.black.opacity(0.28) : .clear, in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(alignment: .topLeading) {
                                            Label(LocalizedStringKey(item.sourceBadgeKey(in: archive.connectedSources)), systemImage: item.sourceBadgeSymbol(in: archive.connectedSources)).font(.caption.weight(.semibold)).lineLimit(1)
                                                .padding(6).foregroundStyle(.white).background(.black.opacity(0.78), in: RoundedRectangle(cornerRadius: 5)).padding(6)
                                        }.overlay(alignment: .bottomTrailing) {
                                            Image(systemName: selected ? "checkmark.circle.fill" : "circle").font(.title2)
                                                .foregroundStyle(selected ? KeptoraDesign.accent : .white).padding(8)
                                        }
                                }.buttonStyle(.plain).accessibilityLabel(item.displayName + ", " + archive.sourceLabel(item))
                                    .accessibilityValue(Text(verbatim: ([L10n.tr(selected ? "Selected" : "Not selected")] + groups.map { L10n.tr(String.LocalizationValue($0.titleKey)) } + (archive.qualityAssessments[item.id]?.findings.map { L10n.tr(String.LocalizationValue($0.titleKey)) } ?? [])).joined(separator: ", ")))
                                    .accessibilityHint("Click or press Space to change selection. Shift selects a range.").accessibilityAddTraits(selected ? .isSelected : [])
                                    .accessibilityIdentifier("mac.archive.asset.\(item.id)")
                                    .focused($keyboardFocus, equals: item.id)
                                    .onMoveCommand { moveFocus($0) }
                                HStack {
                                    Text(item.displayName).lineLimit(1)
                                    Spacer()

                                }
                                if let date = item.captureDateDescription { Text(date).font(.caption).foregroundStyle(.secondary) }
                                if let value = archive.qualityAssessments[item.id]?.findings.first { Label(LocalizedStringKey(value.titleKey), systemImage: value.symbol).font(.caption).foregroundStyle(.secondary) }
                                if archive.decisions.protectedIDs.contains(item.id) { Label("Protected", systemImage: "lock.fill").font(.caption) }
                                if kept { Label(LocalizedStringKey(keeperLabel), systemImage: "bookmark.fill").font(.caption).foregroundStyle(KeptoraDesign.accent) }
                                if let findings = archive.qualityAssessments[item.id]?.findings, findings.count > 1 {
                                    Menu {
                                        ForEach(Array(findings.dropFirst()), id: \.rawValue) { finding in Label(LocalizedStringKey(finding.titleKey), systemImage: finding.symbol) }
                                    } label: { Text(L10n.format("More Findings (%lld)", findings.count - 1)) }.font(.caption)
                                }
                                if item.isFavorite { Label("Favorite", systemImage: "heart.fill").font(.caption) }
                                if !groups.isEmpty {
                                    Button("Keep This") { archive.keep(item, in: groups) }.disabled(archive.analyzing)
                                        .accessibilityIdentifier("mac.archive.keep.\(item.id)")
                                }
                            }
                            .padding(10).background(KeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(archive.selection.contains(item.id) ? KeptoraDesign.accent : .clear, lineWidth: 2))
                            .id(item.id)
                            .background(GeometryReader { geometry in Color.clear.preference(key: MacGalleryPositions.self, value: [item.id: geometry.frame(in: .named("mac-gallery")).minY]) })
                            .contextMenu { if case .file(let url) = item.reference { Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) } }; Button(selected ? "Deselect" : "Select") { archive.toggleSelection(item) }; Button("Preview") { inspected = item }; Button(archive.decisions.protectedIDs.contains(item.id) ? "Unprotect Photo" : "Protect Photo") { archive.toggleProtection(item) } }
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { filterControls }
                VStack(alignment: .leading, spacing: 8) { filterControls }
            }
            if finding != .all || media != 0 || !albumID.isEmpty || !search.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], alignment: .leading, spacing: 8) {
                    if finding != .all { filterChip(L10n.tr(String.LocalizationValue(finding.titleKey)), id: "finding") { finding = .all } }
                    if media != 0 { filterChip(L10n.tr(media == 1 ? "Photos" : "Videos"), id: "media") { media = 0 } }
                    if !albumID.isEmpty { filterChip(archive.albums.first { $0.id == albumID }?.title ?? L10n.tr("Album"), id: "album") { albumID = "" } }
                    if !search.isEmpty { filterChip(L10n.format("Search: %@", search), id: "search") { search = "" } }
                }
            }
            Text(L10n.format("In this list: %lld items", visible.count)).font(.subheadline.weight(.semibold)).accessibilityIdentifier("mac.archive.visibleCount")
            if archive.analyzing {
                ProgressView(value: Double(archive.analysisProcessed), total: Double(max(archive.analysisTotal, 1)))
                Text("Scanning your photos. You can select ready results.").font(.caption).foregroundStyle(.secondary)
            } else if archive.analysisPaused {
                Text("Scan paused.").font(.caption).foregroundStyle(.secondary)
            } else if archive.sessionProgress.isComplete {
                Label("Scan complete. Choose what to keep.", systemImage: "checkmark.circle").font(.caption).foregroundStyle(.secondary)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { browsingControls }
                VStack(alignment: .leading, spacing: 8) { browsingControls }
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { scanControls }
                VStack(alignment: .leading, spacing: 8) { scanControls }
            }
        }.padding(16).disabled(archive.busy)
    }
    @ViewBuilder private var filterControls: some View {
        Picker("Media type", selection: contextBinding(\.media)) { Text("All").tag(0); Text("Photos").tag(1); Text("Videos").tag(2) }.pickerStyle(.segmented).frame(maxWidth: 240)
        Picker("Album", selection: contextBinding(\.albumID)) { Text("All Albums").tag(""); ForEach(archive.albums) { Text($0.title).tag($0.id) } }.frame(maxWidth: 220)
        TextField("Search filenames", text: contextBinding(\.search)).textFieldStyle(.roundedBorder)
    }
    @ViewBuilder private var browsingControls: some View {
        Button { archive.selectItems(visible) } label: { Text(L10n.format("Select This List (%lld)", visible.count)) }
            .disabled(visible.isEmpty || archive.loading).accessibilityIdentifier("mac.archive.selectAll")
        if finding != .all || media != 0 || !albumID.isEmpty || !search.isEmpty { Button("Reset Filters") { resetFilters() } }
        Toggle("Keep Related Shots Together", isOn: contextBinding(\.smartOrder)).toggleStyle(.checkbox)
    }
    @ViewBuilder private var scanControls: some View {
        if archive.analyzing && !archive.analysisPaused {
            Button("Pause Scan") { archive.pauseAnalysis() }
            Menu("Scan Options") { Button("Cancel Scan") { archive.cancelAnalysis() } }
        }
        else if archive.analysisPaused { Button("Resume Scan") { archive.resumeAnalysis() } }
        else {
            Button("Start Scan") { archive.analyze() }.buttonStyle(.borderedProminent).accessibilityIdentifier("mac.archive.scanAll").disabled(!archive.canScanSelectedSources)
            Menu("Scan Options") { Button("Include Cloud Originals") { cloudScan = true } }.disabled(!archive.canScanSelectedSources)
        }
    }
    private func filterChip(_ title: String, id: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack { Text(title).multilineTextAlignment(.leading); Spacer(minLength: 4); Image(systemName: "xmark.circle.fill") }
                .font(.caption.weight(.semibold)).padding(8).frame(minWidth: 32, minHeight: 32)
                .background(KeptoraDesign.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8)).contentShape(RoundedRectangle(cornerRadius: 8))
        }.buttonStyle(.plain).accessibilityLabel(Text(L10n.format("Remove Filter: %@", title)))
            .accessibilityIdentifier("mac.archive.filter.remove." + id)
    }
}

struct MacManualSelectionSheet: View {
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.dismiss) private var dismiss
    @State private var confirm = false
    @State private var expectedIDs: Set<String> = []
    @State private var review = FrozenSelectionReview()
    @State private var captured = false
    @State private var leaveLinkedFiles = false
    private var reviewedItems: [UniversalMediaAsset] { review.items }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Review Selection").font(.title.bold())
            List {
                Section { reviewSummary }
                Section("Removal by Source") {
                    ForEach(archive.connectedSources) { source in
                        let items = reviewedItems.filter { $0.sourceID == source.id }
                        if !items.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(source.localizedScanTitle + " · " + items.count.formatted())
                                Text(source.kind == .photos ? LocalizedStringKey("Recently Deleted in Photos") : LocalizedStringKey("Recovery Folder")).font(.caption).foregroundStyle(.secondary)
                                if source.kind == .photos { Text("Changes to iCloud Photos sync across your devices.").font(.caption).foregroundStyle(.secondary) }
                                else { Text("Files stay recoverable on the same storage; space is not freed yet.").font(.caption).foregroundStyle(.secondary) }
                            }
                        }
                    }
                    Text("Moves in connected cloud folders may sync to other devices.").font(.caption).foregroundStyle(.secondary)
                }
                Section {
                    DisclosureGroup("Recovery Details") {
                        Text("Photos items move to Recently Deleted and iCloud changes sync across devices. Files move to a recovery folder on the same storage; this does not free disk space. Completed steps appear in History if cleanup stops partway.").font(.callout).foregroundStyle(.secondary)
                    }
                }
                if hasUnavailableSelection {
                    Section("Unavailable Selected Items") {
                        Text("Reconnect unavailable sources or remove their items from your selection.")
                        Button("Remove Unavailable Items from Selection") {
                            review.discard(Set(archive.pendingSelection.map(\.id)).union(archive.unresolvedSelectionIDs))
                            archive.discardPendingSelection()
                        }
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
                    Text("Removing an item from this list keeps it in your library.").font(.callout).foregroundStyle(.secondary)
                    if reviewedItems.isEmpty { Text("No items selected.").foregroundStyle(.secondary) }
                    ForEach(reviewedItems) { item in reviewRow(item) }
                }
            }.disabled(archive.busy)
            Text(L10n.format("Selected items: %lld", reviewedItems.count)).font(.headline)
            if archive.busy { ProgressView(archive.status ?? L10n.tr("Removing selected items…")) }
            if archive.loading || archive.analyzing { Text("Wait for analysis to finish or cancel it before cleanup.").font(.caption).foregroundStyle(.secondary) }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { secondaryReviewActions; Spacer(minLength: 12); removeButton }
                VStack(alignment: .leading, spacing: 8) { secondaryReviewActions; removeButton }
            }
        }.controlSize(.large).padding(24).frame(minWidth: 480, idealWidth: 650, minHeight: 480, idealHeight: 650).interactiveDismissDisabled(archive.busy)
        .onChange(of: reviewedItems) { _ in leaveLinkedFiles = false }
        .onAppear { if !captured { review = FrozenSelectionReview(archive.selected); captured = true } }
        .alert("Remove selected items?", isPresented: $confirm) {
            Button(role: .destructive) { Task { if await archive.removeSelection(expectedIDs: expectedIDs, reviewedAssets: reviewedItems, allowPartialFamilies: leaveLinkedFiles) { dismiss() } } }
                label: { Text(L10n.format("Remove %lld Items", expectedIDs.count)) }
            Button("Cancel", role: .cancel) { }
        } message: { Text("Only the items listed here will be removed. Review the destination and recovery conditions before continuing.") }
        .alert("Something went wrong", isPresented: Binding(get: { archive.error != nil }, set: { if !$0 { archive.error = nil } })) {
            Button("OK") { archive.error = nil }
        } message: { Text(archive.error ?? "") }
    }
    private var hasUnavailableSelection: Bool {
        !archive.unresolvedSelectionIDs.intersection(archive.selection).isEmpty || archive.pendingSelection.contains { archive.selection.contains($0.id) }
    }
    private var reviewSummary: some View {
        let summary = MediaSelectionSummary(reviewedItems)
        let reviewedIDs = Set(reviewedItems.map(\.id))
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(format: L10n.tr("Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.headline)
            Text(ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file))
            Text("Media size, not freed space").font(.caption).foregroundStyle(.secondary)
            if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.caption).foregroundStyle(.secondary) }
            Text("Review these items before removing them.").foregroundStyle(.secondary)
            if summary.personalItems > 0 { Label("Includes favorites, hidden, edited or shared items you selected manually.", systemImage: "exclamationmark.triangle") }
            if archive.exact.contains(where: { $0.assets.allSatisfy { reviewedIDs.contains($0.id) } }) {
                Label("Every item in a known duplicate group is selected.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
            }
        }
    }
    private func reviewRow(_ item: UniversalMediaAsset) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { reviewDetails(item); excludeButton(item) }
            VStack(alignment: .leading, spacing: 12) { reviewDetails(item); excludeButton(item) }
        }.padding(.vertical, 4)
    }
    private func reviewDetails(_ item: UniversalMediaAsset) -> some View {
        HStack(alignment: .top, spacing: 12) {
            MacPhotosThumbnail(asset: item, pixelSize: 160).frame(width: 76, height: 76).clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName).lineLimit(2)
                Text(archive.sourceLabel(item)).font(.caption).foregroundStyle(.secondary)
                if let date = item.captureDateDescription { Text(date).font(.caption).foregroundStyle(.secondary) }
            }
        }
    }
    private func excludeButton(_ item: UniversalMediaAsset) -> some View {
        Button {
            if review.remove(item.id) { archive.setSelection(archive.selection.subtracting([item.id])) }
        } label: { Label("Remove from selection", systemImage: "minus.circle").padding(.horizontal, 8).frame(minWidth: 32, minHeight: 32).contentShape(Rectangle()) }
            .buttonStyle(.borderless).accessibilityLabel("Remove from selection")
            .accessibilityHint("This item will stay in your library.")
            .accessibilityIdentifier("mac.archive.review.exclude." + item.id)
    }
    private var secondaryReviewActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { secondaryReviewButtons }
            VStack(alignment: .leading, spacing: 8) { secondaryReviewButtons }
        }
    }
    @ViewBuilder private var secondaryReviewButtons: some View {
        Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).disabled(archive.busy)
        if review.canUndoRemoval {
            Button("Undo Review Change") {
                if let item = review.undoRemoval() { archive.setSelection(archive.selection.union([item.id])) }
            }.keyboardShortcut("z", modifiers: [.command]).disabled(archive.busy).accessibilityIdentifier("mac.archive.review.undo")
        }
    }
    private var removeButton: some View {
        Button(role: .destructive) { expectedIDs = Set(reviewedItems.map(\.id)); confirm = true }
            label: { Text(L10n.format("Remove %lld Items", reviewedItems.count)).frame(minHeight: 32) }
            .buttonStyle(.borderedProminent).tint(.red).accessibilityIdentifier("mac.archive.review.remove")
            .disabled(archive.busy || archive.loading || archive.analyzing || reviewedItems.isEmpty || hasUnavailableSelection || (!leaveLinkedFiles && !LibraryFileFamilies.omittedCompanions(for: reviewedItems).isEmpty))
    }
}

struct MacManualHistoryView: View {
    @EnvironmentObject private var archive: MacArchiveModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cleanup History").font(.title2.bold())
            if archive.busy { ProgressView(archive.status ?? L10n.tr("Restoring files…")) }
            if let error = archive.error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(.red) }
            if !archive.connectionErrors.isEmpty { Button("Add Folders…") { archive.chooseFolder() }.disabled(archive.sourceControlsDisabled) }
            Text(L10n.format("Recovery storage: %@", ByteCountFormatter.string(fromByteCount: archive.history.reduce(0) { $0 + ($1.folderRecord?.recoveryBytes ?? 0) }, countStyle: .file))).font(.headline)
            Text("Recovery files stay on their original storage until you restore them. They do not free disk space.").font(.caption).foregroundStyle(.secondary)
            if archive.history.isEmpty { Text("No manual cleanup history yet.").foregroundStyle(.secondary) }
            ForEach(archive.history) { entry in
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { historyDetails(entry); Spacer(minLength: 12); recoveryAction(entry) }
                    VStack(alignment: .leading, spacing: 12) { historyDetails(entry); recoveryAction(entry) }
                }.padding(16).background(KeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 16))
            }
        }.controlSize(.large).padding(20)
    }
    private func historyDetails(_ entry: MacRecoveryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.date.formatted()).font(.headline)
            Text(L10n.format("%lld items", entry.folderRecord.map { $0.restoredAt == nil ? $0.movedCount : $0.operations.count } ?? entry.count))
            if let record = entry.folderRecord {
                Text(L10n.format("Planned: %lld · In recovery: %lld · Needs attention: %lld", record.operations.count, record.movedCount, record.unresolvedCount)).font(.caption)
                Text(ByteCountFormatter.string(fromByteCount: record.recoveryBytes, countStyle: .file)).font(.caption)
            }
            if entry.isPhotos, entry.operationState == .planned { Label("Interrupted Photos request. Check Recently Deleted before trying again.", systemImage: "exclamationmark.triangle") }
            if entry.isPhotos, entry.operationState == .failed { Label("Removal was not completed.", systemImage: "exclamationmark.triangle") }
            Label(entry.isPhotos ? LocalizedStringKey("Recently Deleted in Photos") : LocalizedStringKey("Recovery Folder"), systemImage: entry.isPhotos ? "photo" : "folder")
            Text(entry.isPhotos ? "Recover items in Apple Photos → Recently Deleted for up to 30 days unless permanently deleted sooner." : "Files remain in the recovery folder on the same storage.").font(.callout).foregroundStyle(.secondary)
        }
    }
    @ViewBuilder private func recoveryAction(_ entry: MacRecoveryEntry) -> some View {
        if entry.isPhotos {
            Button("Open Apple Photos") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Photos.app")) }
        } else if entry.folderRecord?.restoredAt != nil { Label("Restored", systemImage: "checkmark.circle") }
        else {
            HStack(spacing: 12) {
                Button("Restore Files") { Task { await archive.restore(entry) } }.disabled(archive.busy || archive.loading || archive.analyzing)
                Button("Show Recovery Folder") { archive.revealRecovery(entry) }
            }
        }
    }
}

struct CombinedCleanupHistoryView: View {
    @State private var manual = true
    var body: some View {
        VStack(spacing: 0) {
            Picker("History source", selection: $manual) {
                Text("Library Cleanup").tag(true)
                Text("Verified Copy Plans").tag(false)
            }.pickerStyle(.segmented).padding(20).frame(maxWidth: 500)
            if manual { ScrollView { MacManualHistoryView() } }
            else { HistoryView() }
        }
    }
}


private struct MacGalleryPositions: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]
    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) { value.merge(nextValue(), uniquingKeysWith: { _, new in new }) }
}

struct MacSuggestionsView: View {
    @EnvironmentObject private var archive: MacArchiveModel
    @EnvironmentObject private var model: AppModel
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Suggestions").font(.largeTitle.bold())
                Text(LocalizedStringKey(archive.sessionProgress.isComplete ? "Scan complete. Choose what to keep." : "Scan your selected sources to find copies and photos worth reviewing.")).foregroundStyle(.secondary)
                ForEach(LibraryFindingFilter.allCases.filter { $0 != .all }) { category in
                    let count = category.ids(groups: archive.reviewGroups, quality: archive.qualityAssessments)?.count ?? 0
                    Button {
                        archive.galleryContext.finding = category; archive.contextChanged(); model.selectedRoute = .archive
                    } label: {
                        HStack {
                            Label(LocalizedStringKey(category.titleKey), systemImage: category == .copies ? "square.on.square" : category == .verySimilar ? "photo.on.rectangle.angled" : "sparkles")
                            Spacer(); Text(count.formatted()).monospacedDigit(); Image(systemName: "chevron.right")
                        }.padding(20).frame(minHeight: 64)
                    }.buttonStyle(.bordered).disabled(count == 0).accessibilityIdentifier("mac.suggestions." + category.rawValue)
                }
                if archive.analyzing { ProgressView(archive.status ?? L10n.tr("Loading sources")) }
                else { Button("Start Scan") { archive.analyze() }.buttonStyle(.borderedProminent).disabled(!archive.canScanSelectedSources) }
            }.padding(24).frame(maxWidth: 850, alignment: .leading)
        }.accessibilityIdentifier("mac.page.suggestions")
    }
}
