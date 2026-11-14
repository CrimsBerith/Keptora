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
                                Image(systemName: source.scanSymbol).foregroundStyle(KeptoraDesign.secondaryInk).frame(width: 22)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(source.kind == .photos ? L10n.tr("Photos / iCloud Photos") : source.displayName)
                                    if let report {
                                        (report.error == nil ? Text(L10n.plural("%lld items", report.itemCount)) : Text("Count incomplete")).monospacedDigit().foregroundStyle(KeptoraDesign.secondaryInk)
                                        Text(LocalizedStringKey(report.statusKey)).font(.caption)
                                            .foregroundStyle(report.error != nil || report.authorization == .limited ? KeptoraDesign.warning : Color.secondary)
                                    } else { Text("Loading item count…").foregroundStyle(KeptoraDesign.secondaryInk) }
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
                    Text("Select at least one source").foregroundStyle(KeptoraDesign.secondaryInk).accessibilityIdentifier("sources.emptySelection")
                } else {
                    Text(L10n.format("%lld sources selected · %lld different items", archive.selectedSourceIDs.count, archive.scopedAssets.count))
                        .foregroundStyle(KeptoraDesign.secondaryInk).accessibilityIdentifier("sources.summary")
                }
                Text("Selected sources appear together. The same item in overlapping folders is counted once.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                Text("Unticking a source keeps its connection. You can include it again later.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
            }.padding(6).frame(maxWidth: .infinity, alignment: .leading)
        }
        .groupBoxStyle(KeptoraGlassGroupBoxStyle(tint: KeptoraDesign.accent))
    }
}

struct MacSourceSetupView: View {
    var isStartupSetup = false
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage(AppStorageKeys.macSourceSetupCompleted) private var sourceSetupCompleted = false
    private var controlsDisabled: Bool { archive.sourceControlsDisabled }

    var body: some View {
        ZStack {
            KeptoraBackdrop()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        MacSessionHealthBanner()
                        Group {
                        Image("onboarding_privacy").resizable().scaledToFit().frame(maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .overlay {
                                RoundedRectangle(cornerRadius: 20)
                                    .stroke(KeptoraDesign.borderGradient, lineWidth: 1)
                                    .allowsHitTesting(false)
                            }
                            .shadow(color: reduceTransparency ? .clear : KeptoraDesign.accentGlow, radius: 16, y: 6)
                            .accessibilityHidden(true)
                        Text("Connect your library").font(.title.bold())
                        Text("Connect Photos and folders once. Choose which sources to include in each scan.").foregroundStyle(KeptoraDesign.secondaryInk)
                        if archive.isRequestingPhotosAccess { ProgressView("Waiting for Photos access…") }
                        if !archive.connectedSources.isEmpty { MacScanSourcesSection() }
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Photos", systemImage: "photo.on.rectangle.angled").font(.headline)
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
                                    Text("Limited Photos access").foregroundStyle(KeptoraDesign.warning)
                                    Button("Manage Access") { archive.openPhotosSettings() }
                                }
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .groupBoxStyle(KeptoraGlassGroupBoxStyle(tint: KeptoraDesign.accent))
                        GroupBox {
                            VStack(alignment: .leading, spacing: 12) {
                                Label("Files & cloud folders", systemImage: "folder.badge.plus").font(.headline)
                                ForEach(archive.connectedFolders) { folder in
                                    HStack { Label(folder.displayName, systemImage: "checkmark.circle"); Spacer(); Button("Disconnect") { archive.disconnectFolder(folder.id) } }
                                }
                                Button { archive.chooseFolder() } label: { Text("Add Folders…").frame(minHeight: 32) }
                                    .accessibilityIdentifier("mac.sourceSetup.folders")
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .groupBoxStyle(KeptoraGlassGroupBoxStyle(tint: KeptoraDesign.cyan))
                        Text("You can continue without access and add sources later.").font(.callout).foregroundStyle(KeptoraDesign.secondaryInk)
                        // Background on access and cloud folders stays one click away instead of filling the sheet.
                        DisclosureGroup("Details") {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Full Photos access includes iCloud Photos. Limited access shows only the items you approve.")
                                Text("Choose Pictures, Downloads, iCloud Drive or another cloud folder. Keptora remembers folders you approve; other apps' private storage is unavailable.")
                                Text("Cloud providers may download files according to their own settings.")
                                Text("No camera, microphone, contacts or live location permission is needed. Existing photo details are read only from media you approve.")
                            }.font(.callout).foregroundStyle(KeptoraDesign.secondaryInk).frame(maxWidth: .infinity, alignment: .leading).padding(.top, 6)
                        }
                        ForEach(Array(archive.connectionErrors.enumerated()), id: \.offset) { entry in Text(entry.element).foregroundStyle(KeptoraDesign.warning) }
                        }.disabled(controlsDisabled)
                    }.padding(24)
                }
                HStack {
                    Spacer()
                    Button {
                        if isStartupSetup { sourceSetupCompleted = true; archive.startFirstScanWhenReady() }
                        dismiss()
                    } label: { Text(isStartupSetup ? LocalizedStringKey("Continue to Library") : LocalizedStringKey("Done")).frame(minHeight: 32) }
                        .buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction).disabled(archive.isRequestingPhotosAccess)
                        .accessibilityIdentifier("mac.sourceSetup.continue")
                }
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .background {
                    if reduceTransparency {
                        KeptoraDesign.canvas
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
                    .allowsHitTesting(false)
                }
            }
        }
        .controlSize(.large)
        .frame(minWidth: 480, idealWidth: 650, maxWidth: 800, minHeight: 480, idealHeight: 600, maxHeight: 800)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.sourceSetup")
        .interactiveDismissDisabled(isStartupSetup)
        .onAppear { archive.presentationOwner = .sources }
        .onDisappear { archive.closePresentation() }
        .task {
            if isStartupSetup, LibraryAccessPolicy.shouldRequestPhotosAtStartup(archive.authorization) {
                await archive.requestPhotosAccess(showError: false)
            }
        }
        .alert(Text(archive.errorAlertParts.title), isPresented: archive.errorBinding(for: .sources)) {
            Button("OK", role: .cancel) { archive.error = nil }
        } message: { if let detail = archive.errorAlertParts.detail { Text(detail) } }
    }
}

@MainActor
struct MacArchiveView: View {
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
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
    private var orderedVisible: [UniversalMediaAsset] { archive.gallery.ordered }
    private var visible: [UniversalMediaAsset] { archive.gallery.visible }
    private var qualityFilter: LibraryQualityFilter { archive.galleryContext.quality ?? .all }
    private var qualityBinding: Binding<LibraryQualityFilter> {
        Binding(get: { qualityFilter }, set: { archive.galleryContext.quality = $0; archive.contextChanged() })
    }
    @FocusState private var searchFocused: Bool
    @State private var restoredPosition = false
    @State private var comparingGroup: LibraryReviewGroup?
    var body: some View {
        VStack(spacing: 0) {
            fixedControls
            Divider()
            ScrollViewReader { proxy in
                ScrollView { catalogueContent }.coordinateSpace(name: "mac-gallery")
                    .background(GeometryReader { geometry in
                        Color.clear.onAppear { galleryColumns = max(1, Int((geometry.size.width - 28) / 172)) }
                            .onChange(of: geometry.size.width) { _, width in galleryColumns = max(1, Int((width - 28) / 172)) }
                    })
                    .onAppear { restorePosition(proxy) }
                    .onChange(of: archive.loading) { _, loading in if !loading { restorePosition(proxy) } }
                    .onChange(of: archive.assets.count) { restorePosition(proxy) }
                    .onChange(of: keyboardFocus) { _, id in archive.recordFocus(id); if let id { proxy.scrollTo(id, anchor: .center) } }
            }
            if !archive.selection.isEmpty || archive.canUndoSelection || archive.canRedoSelection {
                VStack(alignment: .leading, spacing: 12) {
                    let summary = MediaSelectionSummary(archive.selected)
                    VStack(alignment: .leading) {
                        Text(String(format: L10n.tr("Selected items: %lld"), archive.selection.count)).font(.headline).accessibilityIdentifier("mac.archive.selectionCount")
                        // An empty selection (kept visible for undo) does not repeat zero counts and sizes.
                        if !archive.selection.isEmpty {
                            Text(String(format: L10n.tr("Photos: %lld · Videos: %lld"), summary.photos, summary.videos)
                                 + " · " + ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file)
                                 + " · " + L10n.tr("Space is not freed right away")).font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                            if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk) }
                        }
                        let hidden = archive.selection.subtracting(visible.map(\.id)).count
                        if hidden > 0 { Text(String(format: L10n.tr("%lld selected outside this view"), hidden)).font(.caption).foregroundStyle(KeptoraDesign.secondaryInk) }
                    }
                    if let status = archive.status { HStack { ProgressView().controlSize(.small); Text(status).font(.caption) } }
                    selectionActions
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 18)
                .background {
                    if reduceTransparency {
                        KeptoraDesign.canvas
                    } else {
                        Rectangle().fill(.ultraThinMaterial)
                    }
                }
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color.white.opacity(colorScheme == .dark ? 0.32 : 0.65), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 1)
                    .allowsHitTesting(false)
                }
                .shadow(color: reduceTransparency ? .clear : Color.black.opacity(0.06), radius: 10, y: -3)
                .disabled(archive.busy || archive.loading)
            }
        }
        .controlSize(.large)
        .background(Color.clear)
        .background(MacGalleryKeyboardMonitor(selectAll: { archive.selectItems(visible) }, find: { searchFocused = true },
            undo: { archive.undoSelection() }, redo: { archive.redoSelection() }))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("mac.page.archive")
        .sheet(isPresented: $showPlan) { MacManualSelectionSheet().environmentObject(archive) }
        .sheet(item: $inspected) { item in
            ZStack {
                KeptoraBackdrop()

                ScrollView {
                    VStack(spacing: 14) {
                        MacPhotosThumbnail(asset: item, pixelSize: 1600, fit: true, allowNetwork: previewNetwork)
                            .frame(minWidth: 520, minHeight: 380)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay {
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(KeptoraDesign.borderGradient, lineWidth: 1)
                                    .allowsHitTesting(false)
                            }
                        Text(item.displayName)
                            .font(.headline)
                            .truncationMode(.middle)
                            .lineLimit(1)
                        Text(archive.sourceLabel(item)).font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                        if !previewNetwork && (item.requiresNetwork || { if case .photoLibrary = item.reference { return true }; return false }()) { Button("Download Preview from iCloud") { previewNetwork = true } }
                        if let date = item.captureDateDescription { Text(date) }
                        if let context = item.context, let camera = context.camera { Text(camera) }
                        if let location = item.context?.location {
                            HStack {
                                Image(systemName: "location.fill").foregroundStyle(KeptoraDesign.accent)
                                Text(String(format: "%.5f, %.5f", location.latitude, location.longitude))
                                if case .file(let url) = item.reference {
                                    Button("Strip Location for Privacy") {
                                        try? MetadataDoctorEngine.stripLocationData(from: url, destinationURL: url)
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                        }
                        if item.context?.captureDate == nil, let inferred = MetadataDoctorEngine.inferDateFromFilename(item.displayName) {
                            HStack {
                                Image(systemName: "calendar.badge.clock").foregroundStyle(KeptoraDesign.accent)
                                Text(L10n.format("Inferred Date: %@", DateFormatter.localizedString(from: inferred, dateStyle: .medium, timeStyle: .short)))
                                    .font(.caption)
                            }
                        }
                        HStack(spacing: 12) {
                            Button("Close") { inspected = nil }
                                .keyboardShortcut(.cancelAction)
                            Button(archive.selection.contains(item.id) ? "Deselect" : "Select") { archive.toggleSelection(item) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(20)
                }
            }
            .frame(minWidth: 560, idealWidth: 640, minHeight: 480, maxHeight: 680)
        }
        .sheet(item: $comparingGroup) { group in
            SideBySideCompareView(group: group, isPresented: $comparingGroup)
                .environmentObject(archive)
        }
        .onChange(of: inspected?.id) { previewNetwork = false }
        .sheet(isPresented: $showAccessGuide) { MacSourceSetupView().environmentObject(archive) }
        .confirmationDialog("Download cloud originals?", isPresented: $cloudScan) {
            Button("Download and Scan") { archive.analyze(allowNetwork: true) }
        } message: { Text("This may use network data and device storage. You can cancel the scan at any time.") }
        .onChange(of: archive.scanSourceSelection) { finding = .all; albumID = ""; media = 0; search = "" }
    }
    private var fixedControls: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) { headerSummary; Spacer(minLength: 12); headerActions }
                .padding(.horizontal, 16).padding(.top, 10)
            filters
            if finding == .copies || (finding == .all && !archive.reviewGroups.isEmpty && archive.sessionProgress.isComplete) {
                exactBatchSelection.padding(.horizontal, 16).padding(.bottom, 8)
            }
            if finding == .verySimilar || finding == .review || (finding == .all && !archive.reviewGroups.isEmpty && archive.sessionProgress.isComplete) {
                similarBatchSelection.padding(.horizontal, 16).padding(.bottom, 8)
            }
            if let message = archive.filterScopeMessage {
                HStack(alignment: .top) {
                    Text(message).font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                    Button { archive.filterScopeMessage = nil } label: { Image(systemName: "xmark.circle").frame(width: 32, height: 32) }.help("Dismiss").accessibilityLabel("Dismiss")
                }.padding(.horizontal, 16).padding(.bottom, 6)
            }
            if let message = archive.analysisCacheMessage { Text(message).font(.caption).foregroundStyle(KeptoraDesign.warning).padding(.horizontal, 16).padding(.bottom, 6) }
            if archive.coverage.contains(where: { $0.error != nil }) || !archive.connectionErrors.isEmpty {
                Button("Some sources have limited access. Manage Sources") { showAccessGuide = true }.font(.caption).padding(.bottom, 12)
            }
        }
        .background {
            if reduceTransparency {
                KeptoraDesign.canvas
            } else {
                Rectangle().fill(.ultraThinMaterial)
            }
        }
    }
    private func restorePosition(_ proxy: ScrollViewProxy) {
        guard !restoredPosition, !archive.loading, !archive.assets.isEmpty else { return }
        if let id = archive.scrollAnchorID, visible.contains(where: { $0.id == id }) { proxy.scrollTo(id, anchor: .center) }
        keyboardFocus = archive.focusedAssetID; restoredPosition = true
    }
    private var catalogueContent: some View {
        VStack(spacing: 0) {
            if archive.assets.isEmpty && !archive.loading {
                VStack(spacing: 16) {
                    Image("onboarding_privacy").resizable().scaledToFit().frame(maxWidth: 520).clipShape(RoundedRectangle(cornerRadius: 22)).accessibilityHidden(true)
                    Text("Your Photos").font(.largeTitle.bold())
                    Text("Open Photos or a folder. Select any photo or video without waiting for duplicate analysis.").foregroundStyle(KeptoraDesign.secondaryInk)
                }.padding(28).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if archive.loading { ProgressView("Loading your library…").padding() }
                if archive.selectedSourceIDs.isEmpty {
                    Text("Select at least one source").font(.headline).padding()
                    Text("Open Sources and select at least one source.").foregroundStyle(KeptoraDesign.secondaryInk)
                    Button("Sources") { showAccessGuide = true }
                }
                if archive.authorization == .limited {
                    Text("Limited Photos access. Keptora can only show the items you allow.").font(.callout).foregroundStyle(KeptoraDesign.secondaryInk).padding(.horizontal, 20)
                    Button("Manage Access") { archive.openPhotosSettings() }.padding(.bottom, 8)
                }
                if archive.skippedPreviews > 0 {
                    Text(String(format: L10n.tr("%lld previews could not be analyzed. Results cover only accessible items."), archive.skippedPreviews)).font(.caption).foregroundStyle(KeptoraDesign.secondaryInk).padding(.horizontal, 20)
                }
                if archive.skippedCloudItems > 0 {
                    Text(String(format: L10n.tr("%lld originals could not be analyzed. They remain in the library."), archive.skippedCloudItems)).font(.caption).foregroundStyle(KeptoraDesign.secondaryInk).padding(.horizontal, 20)
                }
                if archive.sessionProgress.isFinished && !archive.sessionProgress.isComplete && !archive.sessionProgress.stages.values.contains(where: { $0.status == .cancelled }) {
                    Label("Analysis partially completed. Some items need attention.", systemImage: "exclamationmark.triangle").font(.caption).padding(.horizontal, 20)
                }
                if !archive.analysisIssues.isEmpty || !archive.analysisFailures.isEmpty {
                    DisclosureGroup("Items needing attention") {
                        ForEach(AnalysisIssueReason.allCases, id: \.rawValue) { reason in
                            let count = Set(archive.analysisIssues.filter { $0.reason == reason }.map(\.assetID)).count
                            if count > 0 { HStack { Text(LocalizedStringKey(reason.titleKey)); Spacer(); Text(count.formatted()) } }
                        }
                        ForEach(AnalysisStage.allCases, id: \.rawValue) { stage in
                            if let failure = archive.analysisFailures[stage] {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(LocalizedStringKey(stage.titleKey)).font(.caption.bold())
                                    Text(failure).font(.caption).foregroundStyle(KeptoraDesign.secondaryInk).textSelection(.enabled)
                                }
                            }
                        }
                        Button("Show Items with Problems") { archive.openFinding(quality: .issues) }
                        Button("Check Source Access") { showAccessGuide = true }
                        if archive.skippedCloudItems > 0 { Button("Include Cloud Originals") { cloudScan = true } }
                    }.padding(.horizontal, 20)
                }
                VStack(spacing: 0) {
                    Text("Click a photo to select or deselect it.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk).padding(.top, 12)
                    if visible.isEmpty && !archive.loading && !archive.selectedSourceIDs.isEmpty {
                        if archive.analyzing { Text("Results appear as they become available.").foregroundStyle(KeptoraDesign.secondaryInk).padding(30) }
                        else {
                            VStack(spacing: 12) {
                                Text("No items in this view").font(.headline)
                                Text("Change the filters or choose another source.").foregroundStyle(KeptoraDesign.secondaryInk)
                                Button("Reset Filters") { resetFilters() }.accessibilityIdentifier("mac.archive.resetFilters")
                            }.padding(30)
                        }
                    }
                    if archive.galleryContext.finding == .copies {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                            ForEach(orderedVisible) { item in
                                archiveCell(item, groups: archive.gallery.membership[item.id] ?? [], keeperBadge: archive.gallery.keeperBadges[item.id])
                            }
                        }.padding(20)
                    } else if smartOrder {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                            ForEach(orderedVisible) { item in
                                archiveCell(item, groups: archive.gallery.membership[item.id] ?? [], keeperBadge: archive.gallery.keeperBadges[item.id])
                            }
                        }.padding(20)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 12, alignment: .top)], alignment: .leading, spacing: 12) {
                            ForEach(visible) { item in
                                archiveCell(item, groups: archive.gallery.membership[item.id] ?? [], keeperBadge: archive.gallery.keeperBadges[item.id])
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
            Text(archive.sourceSelectionState == .all ? LocalizedStringKey("All Connected Sources") : LocalizedStringKey("Selected Sources")).foregroundStyle(KeptoraDesign.secondaryInk)
        }
    }
    private var findingPicker: some View {
        Picker("Library view", selection: contextBinding(\.finding)) {
            ForEach(LibraryFindingFilter.allCases) { Text(LocalizedStringKey($0.titleKey)).tag($0) }
        }
        .accessibilityIdentifier("mac.archive.libraryView")
    }
    private var headerActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { headerButtons }
            VStack(alignment: .leading, spacing: 8) { headerButtons }
        }
    }
    @ViewBuilder private var headerButtons: some View {
        Button { showAccessGuide = true } label: {
            HStack(spacing: 8) {
                Label("Sources", systemImage: "checklist")
                Text(L10n.format("%lld selected", archive.selectedSourceIDs.count)).monospacedDigit()
            }.fixedSize(horizontal: true, vertical: false)
        }.accessibilityIdentifier("mac.archive.sourcesSummary").disabled(archive.busy)
        Button { archive.refresh() } label: { Image(systemName: "arrow.clockwise").frame(width: 32, height: 32).contentShape(Rectangle()) }
            .help("Refresh Library").accessibilityLabel("Refresh Library").disabled(archive.sourceControlsDisabled)
    }
    private var selectionActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { secondarySelectionActions; Spacer(minLength: 12); reviewSelectionButton }
            VStack(alignment: .leading, spacing: 10) { secondarySelectionActions; reviewSelectionButton }
        }
        .padding(.top, 2)
    }
    private var secondarySelectionActions: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) { secondarySelectionButtons }
            VStack(alignment: .leading, spacing: 8) { secondarySelectionButtons }
        }
    }
    @ViewBuilder private var secondarySelectionButtons: some View {
        if archive.canUndoSelection {
            Button { archive.undoSelection() } label: { Image(systemName: "arrow.uturn.backward").frame(width: 32, height: 32) }
                .help("Undo Selection").accessibilityLabel("Undo Selection").accessibilityIdentifier("mac.archive.undoSelection")
        }
        if archive.canRedoSelection {
            Button { archive.redoSelection() } label: { Image(systemName: "arrow.uturn.forward").frame(width: 32, height: 32) }
                .help("Redo Selection").accessibilityLabel("Redo Selection").accessibilityIdentifier("mac.archive.redoSelection")
        }
        Menu("Selection") { Button("Clear All Selections") { archive.setSelection([]) }.disabled(archive.selection.isEmpty) }
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
                    Text("Items suggested to keep and protected items stay unselected.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                }.padding(.bottom, 8)
            }
        }.disabled(archive.busy || archive.loading || archive.isExactAnalyzing)
    }
    private var similarBatchSelection: some View {
        let scope = Set(visible.map(\.id))
        let candidates = archive.similarSuggestionCandidates(visibleIDs: scope)
        let remaining = candidates.filter { !archive.selection.contains($0.id) }.count
        return Group {
            if !candidates.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Button { archive.selectSimilarSuggestions(visibleIDs: scope) } label: {
                        if remaining == 0 { Text("Similar Photos Selected") }
                        else { Text(L10n.format("Select Similar Photos (%lld)", remaining)) }
                    }.disabled(remaining == 0).accessibilityIdentifier("mac.archive.selectSimilarPhotos")
                    Text("Items suggested to keep and protected items stay unselected.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                }.padding(.bottom, 8)
            }
        }.disabled(archive.busy || archive.loading || archive.analyzing)
    }
    private func selectByClick(_ item: UniversalMediaAsset) {
        searchFocused = false
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
    private func resetFilters() { media = 0; albumID = ""; search = ""; finding = .all; smartOrder = true; archive.galleryContext.quality = .all; archive.filterScopeMessage = nil }
    private func thumbnailCard(_ item: UniversalMediaAsset, selected: Bool, kept: Bool, keeperLabel: String) -> some View {
        ZStack(alignment: .bottomTrailing) {
            MacPhotosThumbnail(asset: item)
                .frame(height: 150)
                .frame(minWidth: 0, maxWidth: .infinity)
                .clipped()
            if selected {
                Color.black.opacity(0.28)
            }
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if archive.decisions.protectedIDs.contains(item.id) {
                        Image(systemName: "lock.fill")
                            .font(.caption.weight(.semibold))
                            .padding(4).foregroundStyle(.white).background(.black.opacity(0.70), in: Circle())
                    }
                    if kept {
                        Image(systemName: "bookmark.fill")
                            .font(.caption2.weight(.semibold))
                            .padding(4).foregroundStyle(.white).background(KeptoraDesign.accentFill, in: Circle())
                    }
                    Spacer(minLength: 2)
                }
                Spacer(minLength: 0)
                HStack {
                    if item.isFavorite || item.mediaKind == .video {
                        HStack(spacing: 4) {
                            if item.isFavorite {
                                Image(systemName: "heart.fill").font(.caption).foregroundStyle(.pink)
                            }
                            if item.mediaKind == .video {
                                Label(item.formattedDuration, systemImage: "play.fill")
                                    .font(.caption2.weight(.semibold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .padding(.horizontal, 6).padding(.vertical, 3)
                        .background(.black.opacity(0.65), in: RoundedRectangle(cornerRadius: 4))
                    }
                    Spacer(minLength: 0)
                    Image(systemName: archive.decisions.protectedIDs.contains(item.id) ? "lock.fill" : (selected ? "checkmark.circle.fill" : "circle"))
                        .font(.title3)
                        .foregroundStyle(selected ? KeptoraDesign.accent : .white)
                }
            }
            .padding(6)
        }
        .frame(height: 150)
        .frame(minWidth: 0, maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
    private func archiveCell(_ item: UniversalMediaAsset, groups: [LibraryReviewGroup] = [], keeperBadge: String? = nil) -> some View {
        let selected = archive.selection.contains(item.id)
        let kept = !selected && keeperBadge != nil
        let keeperLabel = keeperBadge ?? "Suggested Keep"
        return VStack(alignment: .leading, spacing: 6) {
            Button { selectByClick(item) } label: {
                thumbnailCard(item, selected: selected, kept: kept, keeperLabel: keeperLabel)
            }
            .buttonStyle(.plain)
            .contentShape(RoundedRectangle(cornerRadius: 12))
            .accessibilityLabel(item.displayName + ", " + archive.sourceLabel(item))
            .accessibilityValue(Text(verbatim: ([L10n.tr(selected ? "Selected" : "Not selected")] + groups.map { L10n.tr(String.LocalizationValue($0.titleKey)) } + (archive.qualityAssessments[item.id]?.findings.map { L10n.tr(String.LocalizationValue($0.titleKey)) } ?? [])).joined(separator: ", ")))
            .accessibilityHint("Click or press Space to change selection. Shift selects a range.").accessibilityAddTraits(selected ? .isSelected : [])
            .accessibilityIdentifier("mac.archive.asset.\(item.id)")
            .focused($keyboardFocus, equals: item.id)
            .onMoveCommand { moveFocus($0) }

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.displayName)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer(minLength: 4)
                    if let bytes = item.byteCount {
                        Text(ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file))
                            .font(.caption2)
                            .foregroundStyle(KeptoraDesign.secondaryInk)
                            .monospacedDigit()
                    }
                }
                HStack(spacing: 6) {
                    if let date = item.captureDateDescription {
                        Text(date).font(.caption2).foregroundStyle(KeptoraDesign.secondaryInk).lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    if let value = archive.qualityAssessments[item.id]?.findings.first {
                        Label(LocalizedStringKey(value.titleKey), systemImage: value.symbol)
                            .font(.caption2).foregroundStyle(KeptoraDesign.secondaryInk).lineLimit(1)
                    }
                }
                if let issue = archive.gallery.issuesByAsset[item.id] {
                    Label(LocalizedStringKey(issue.reason.titleKey), systemImage: "exclamationmark.triangle")
                        .font(.caption2).foregroundStyle(KeptoraDesign.warning).lineLimit(1)
                }
                if !groups.isEmpty {
                    Text(groups.map { L10n.tr(String.LocalizationValue($0.titleKey)) }.joined(separator: " · "))
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(KeptoraDesign.secondaryInk)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    if !groups.isEmpty && !kept {
                        Button("Keep This") { archive.keep(item, in: groups) }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(archive.analyzing)
                            .accessibilityIdentifier("mac.archive.keep.\(item.id)")
                    } else if kept {
                        Text(LocalizedStringKey("Suggested Keep"))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(KeptoraDesign.accent)
                    }
                    Spacer(minLength: 0)
                    if let firstGroup = groups.first, firstGroup.assets.count > 1 {
                        Button {
                            comparingGroup = firstGroup
                        } label: {
                            Image(systemName: "square.split.2x1")
                        }
                        .buttonStyle(.borderless)
                        .help("Compare Group")
                        .accessibilityLabel("Compare Group")
                        .accessibilityIdentifier("mac.archive.compare.\(item.id)")
                    }
                }
                .frame(minHeight: 24)
            }
        }
        .padding(10)
        .frame(minWidth: 0, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(selected ? KeptoraDesign.accent.opacity(0.12) : KeptoraDesign.elevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .strokeBorder(selected ? KeptoraDesign.accent : Color.white.opacity(0.08), lineWidth: selected ? 2 : 1)
                )
        )
        .id(item.id)
        .onAppear { archive.recordVisibleItem(item.id) }
        .contextMenu {
                                if case .file(let url) = item.reference { Button("Show in Finder") { NSWorkspace.shared.activateFileViewerSelecting([url]) } }
                                if archive.decisions.protectedIDs.contains(item.id) { Button("Unprotect and Select") { archive.unprotectAndSelect(item) } }
                                else { Button(selected ? "Deselect" : "Select") { archive.toggleSelection(item) } }
                                Button("Preview") { inspected = item }
                                Button(archive.decisions.protectedIDs.contains(item.id) ? "Unprotect Photo" : "Protect Photo") { archive.toggleProtection(item) }
                                if archive.gallery.issuesByAsset[item.id] != nil {
                                    Button("Check Source Access") { showAccessGuide = true }
                                    if item.requiresNetwork { Button("Include Cloud Originals") { cloudScan = true } }
                                    else { Button("Retry Scan") { archive.analyze() }.disabled(!archive.canScanSelectedSources) }
                                }
                            }
    }
    private var filters: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                TextField("Search photos, trips, albums, dates...", text: contextBinding(\.search)).textFieldStyle(.roundedBorder).focused($searchFocused).frame(minWidth: 120)
                Menu("Filters") {
                    Picker("Media type", selection: contextBinding(\.media)) { Text("All").tag(0); Text("Photos").tag(1); Text("Videos").tag(2) }
                    Picker("Album", selection: contextBinding(\.albumID)) { Text("All Albums").tag(""); ForEach(archive.albums) { Text($0.title).tag($0.id) } }
                    Picker("Quality", selection: qualityBinding) {
                        ForEach(LibraryQualityFilter.allCases) { filter in
                            Text(verbatim: "\(L10n.tr(String.LocalizationValue(filter.titleKey))) (\(archive.gallery.qualityCounts[filter] ?? 0))").tag(filter)
                        }
                    }
                }.accessibilityIdentifier("mac.archive.filters")
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) { findingPicker.pickerStyle(.segmented); scanControls }
                HStack(spacing: 12) { findingPicker.pickerStyle(.menu); Spacer(minLength: 8); scanControls }
            }
            HStack(spacing: 12) {
                Text(L10n.plural("In this list: %lld items", visible.count))
                    .font(.subheadline.weight(.semibold))
                    .contentTransition(.numericText())
                    .animation(.snappy, value: visible.count)
                    .accessibilityIdentifier("mac.archive.visibleCount")
                Spacer(minLength: 8)
                // Only for a narrowed list; in finding views it would also select the photos suggested to keep.
                if finding == .all && (qualityFilter != .all || media != 0 || !albumID.isEmpty || !search.isEmpty) {
                    Button { archive.selectItems(visible) } label: { Text(L10n.format("Select This List (%lld)", visible.count)) }
                        .disabled(visible.isEmpty || archive.loading || !archive.canEditLibrary).accessibilityIdentifier("mac.archive.selectAll")
                }
                Menu("View Options") {
                    Toggle("Keep Related Shots Together", isOn: contextBinding(\.smartOrder))
                    Button("Reset Filters") { resetFilters() }
                    let count = visible.filter { archive.decisions.protectedIDs.contains($0.id) }.count
                    if count > 0 { Text(L10n.format("%lld protected items stay unselected", count)) }
                }
            }
            // The finding filter is already visible in the Library view picker; chips list the other filters.
            if qualityFilter != .all || media != 0 || !albumID.isEmpty || !search.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        if qualityFilter != .all { filterChip(L10n.tr(String.LocalizationValue(qualityFilter.titleKey)), id: "quality") { archive.galleryContext.quality = .all } }
                        if media != 0 { filterChip(L10n.tr(media == 1 ? "Photos" : "Videos"), id: "media") { media = 0 } }
                        if !albumID.isEmpty { filterChip(archive.albums.first { $0.id == albumID }?.title ?? L10n.tr("Album"), id: "album") { albumID = "" } }
                        if !search.isEmpty { filterChip(L10n.format("Search: %@", search), id: "search") { search = "" } }
                    }
                }
            }
            if archive.analysisPaused { Text("Scan paused.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk) }
            else if archive.analyzing {
                ProgressView(value: Double(archive.analysisProcessed), total: Double(max(archive.analysisTotal, 1)))
                Text("Scanning your photos. You can select ready results.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
            } else if archive.sessionProgress.isComplete {
                scanResults
            }
        }.padding(.horizontal, 14).padding(.top, 10).padding(.bottom, 14).disabled(archive.busy)
    }
    @ViewBuilder private var scanControls: some View {
        if archive.analyzing && !archive.analysisPaused {
            Button("Pause Scan") { archive.pauseAnalysis() }
            Menu("Scan Options") { Button("Cancel Scan") { archive.cancelAnalysis() } }
        }
        else if archive.analysisPaused { Button("Resume Scan") { archive.resumeAnalysis() }; Button("Cancel Scan") { archive.cancelAnalysis() } }
        else if archive.sessionProgress.isComplete {
            // Results are showing; scanning again is secondary.
            Button("Scan Again") { archive.analyze() }.accessibilityIdentifier("mac.archive.scanAll").disabled(!archive.canScanSelectedSources)
            cloudScanMenu
        } else {
            Button("Start Scan") { archive.analyze() }.buttonStyle(.borderedProminent).accessibilityIdentifier("mac.archive.scanAll").disabled(!archive.canScanSelectedSources)
            cloudScanMenu
        }
    }
    @ViewBuilder private var cloudScanMenu: some View {
        if archive.skippedCloudItems > 0 {
            Menu("Scan Options") { Button("Include Cloud Originals") { cloudScan = true } }.disabled(!archive.canScanSelectedSources)
        }
    }
    /// What the finished scan found, with one click into the exact copies.
    private var scanResults: some View {
        let extraCopies = archive.exactSuggestionCandidates(visibleIDs: Set(archive.scopedAssets.map(\.id)))
        let extraBytes = extraCopies.reduce(Int64(0)) { $0 + ($1.byteCount ?? 0) }
        let similar = archive.similarSuggestionCandidates(visibleIDs: Set(archive.scopedAssets.map(\.id)))
        let similarBytes = similar.reduce(Int64(0)) { $0 + ($1.byteCount ?? 0) }
        return HStack(spacing: 12) {
            Label("Scan complete. Choose what to keep.", systemImage: "checkmark.circle").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
            if !extraCopies.isEmpty {
                Button { finding = .copies } label: {
                    Label(L10n.format("Extra copies: %lld · %@", extraCopies.count, ByteCountFormatter.string(fromByteCount: extraBytes, countStyle: .file)), systemImage: "square.on.square")
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("mac.archive.results.copies")
            }
            if !similar.isEmpty {
                Button { finding = .verySimilar } label: {
                    Label(L10n.format("Similar photos: %lld · %@", similar.count, ByteCountFormatter.string(fromByteCount: similarBytes, countStyle: .file)), systemImage: "photo.stack")
                }
                .buttonStyle(.link)
                .accessibilityIdentifier("mac.archive.results.similar")
            }
            if extraCopies.isEmpty && similar.isEmpty && archive.gallery.findingCounts[.copies] == 0 && archive.gallery.findingCounts[.verySimilar] == 0 {
                Text("No copies or similar photos found.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
            }
        }
    }
    private func filterChip(_ title: String, id: String, remove: @escaping () -> Void) -> some View {
        Button(action: remove) {
            HStack { Text(title).multilineTextAlignment(.leading); Spacer(minLength: 4); Image(systemName: "xmark.circle.fill") }
                .font(.caption.weight(.semibold)).padding(8).frame(minWidth: 32, minHeight: 32)
                .background(KeptoraDesign.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            reduceTransparency
                                ? AnyShapeStyle(KeptoraDesign.accent.opacity(0.40))
                                : AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(colorScheme == .dark ? 0.30 : 0.65), KeptoraDesign.accent.opacity(0.25)], startPoint: .topLeading, endPoint: .bottomTrailing)),
                            lineWidth: 0.8
                        )
                        .allowsHitTesting(false)
                )
                .contentShape(RoundedRectangle(cornerRadius: 8))
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
    @State private var outcome: LibraryCleanupOutcome?
    @State private var needsReReview = false
    private var reviewedItems: [UniversalMediaAsset] { review.items }
    var body: some View {
        ZStack {
            KeptoraBackdrop()

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
                                    Text(source.kind == .photos ? LocalizedStringKey("Recently Deleted in Photos") : LocalizedStringKey("Recovery Folder")).font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                                    if source.kind == .photos { Text("Changes to iCloud Photos sync across your devices.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk) }
                                    else { Text("Files stay recoverable on the same storage; space is not freed yet.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk) }
                                }
                            }
                        }
                        Text("Moves in connected cloud folders may sync to other devices.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                    }
                    Section {
                        DisclosureGroup("Recovery Details") {
                            Text("Photos items move to Recently Deleted and iCloud changes sync across devices. Files move to a recovery folder on the same storage; this does not free disk space. Completed steps appear in History if cleanup stops partway.").font(.callout).foregroundStyle(KeptoraDesign.secondaryInk)
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
                        Text("Removing an item from this list keeps it in your library.").font(.callout).foregroundStyle(KeptoraDesign.secondaryInk)
                        if reviewedItems.isEmpty { Text("No items selected.").foregroundStyle(KeptoraDesign.secondaryInk) }
                        ForEach(reviewedItems) { item in reviewRow(item) }
                    }
                }
                .scrollContentBackground(.hidden)
                .disabled(archive.busy || !archive.canEditLibrary)
                Text(L10n.format("Selected items: %lld", reviewedItems.count)).font(.headline)
                if archive.busy { ProgressView(archive.status ?? L10n.tr("Removing selected items…")) }
                if let outcome, !outcome.isComplete {
                    Text(L10n.format("Moved: %lld · Failed: %lld · Not attempted: %lld", outcome.completedIDs.count, outcome.failedIDs.count, outcome.notAttemptedIDs.count)).font(.callout)
                    Text("Check the remaining items before trying again. Completed items have left this review.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                    Button("Review Remaining Items Again") {
                        review = FrozenSelectionReview(archive.selected); expectedIDs = Set(review.items.map(\.id))
                        leaveLinkedFiles = false; needsReReview = false
                    }.disabled(!archive.canEditLibrary || archive.busy || archive.loading || archive.analyzing)
                        .accessibilityIdentifier("mac.archive.review.remaining")
                }
                if archive.loading || archive.analyzing { Text("Wait for analysis to finish or cancel it before cleanup.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk) }
                if !archive.busy && !archive.loading && !archive.analyzing && archive.cleanupStorageIsBusy {
                    Text("Another operation is using this storage. Wait for it to finish or cancel its scan.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { secondaryReviewActions; Spacer(minLength: 12); removeButton }
                    VStack(alignment: .leading, spacing: 10) { secondaryReviewActions; removeButton }
                }
                .padding(.top, 4)
            }
            .controlSize(.large)
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 24)
        }
        .frame(minWidth: 480, idealWidth: 650, minHeight: 480, idealHeight: 650).interactiveDismissDisabled(archive.busy)
        .onChange(of: reviewedItems) { leaveLinkedFiles = false }
        .onAppear { if !captured { review = FrozenSelectionReview(archive.selected); captured = true } }
        .onAppear { archive.presentationOwner = .review }
        .onDisappear { archive.closePresentation() }
        .confirmationDialog("Remove selected items?", isPresented: $confirm) {
            Button(role: .destructive) { Task {
                let result = await archive.removeSelectionOutcome(expectedIDs: expectedIDs, reviewedAssets: reviewedItems, allowPartialFamilies: leaveLinkedFiles)
                outcome = result; review.discard(result.completedIDs); expectedIDs = Set(review.items.map(\.id))
                if result.isComplete { dismiss() } else { needsReReview = true }
            } }
                label: { Text(L10n.plural("Remove %lld Items", expectedIDs.count)) }
                .accessibilityIdentifier("mac.archive.review.confirmRemoval")
            Button("Cancel", role: .cancel) { }
        } message: { Text("Only the items listed here will be removed. Review the destination and recovery conditions before continuing.") }
        .alert(Text(archive.errorAlertParts.title), isPresented: archive.errorBinding(for: .review)) {
            Button("OK") { archive.error = nil }
        } message: { if let detail = archive.errorAlertParts.detail { Text(detail) } }
    }
    private var hasUnavailableSelection: Bool {
        !archive.unresolvedSelectionIDs.intersection(archive.selection).isEmpty || archive.pendingSelection.contains { archive.selection.contains($0.id) }
    }
    private var reviewSummary: some View {
        let summary = MediaSelectionSummary(reviewedItems)
        let reviewedIDs = Set(reviewedItems.map(\.id))
        return VStack(alignment: .leading, spacing: 8) {
            Text(String(format: L10n.tr("Photos: %lld · Videos: %lld"), summary.photos, summary.videos)).font(.headline)
            Text(ByteCountFormatter.string(fromByteCount: summary.knownBytes, countStyle: .file) + " · " + L10n.tr("Space is not freed right away")).foregroundStyle(KeptoraDesign.secondaryInk)
            if summary.unknownSizeCount > 0 { Text("Some item sizes are unavailable.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk) }
            if summary.personalItems > 0 { Label("Includes favorites, hidden, edited or shared items you selected manually.", systemImage: "exclamationmark.triangle") }
            if archive.exact.contains(where: { $0.assets.allSatisfy { reviewedIDs.contains($0.id) } }) {
                Label("Every item in a known duplicate group is selected.", systemImage: "exclamationmark.triangle").foregroundStyle(KeptoraDesign.warning)
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
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 4) {
                Text(item.displayName).lineLimit(2)
                Text(archive.sourceLabel(item)).font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
                if let date = item.captureDateDescription { Text(date).font(.caption).foregroundStyle(KeptoraDesign.secondaryInk) }
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
            label: { Text(L10n.plural("Remove %lld Items", reviewedItems.count)).frame(minHeight: 32) }
            .buttonStyle(.borderedProminent).tint(KeptoraDesign.dangerFill).accessibilityIdentifier("mac.archive.review.remove")
            .disabled(!archive.canRemoveSelection || needsReReview || reviewedItems.isEmpty || hasUnavailableSelection || (!leaveLinkedFiles && !LibraryFileFamilies.omittedCompanions(for: reviewedItems).isEmpty))
    }
}

struct MacManualHistoryView: View {
    @EnvironmentObject private var archive: MacArchiveModel
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Cleanup History").font(.title2.bold())
            if archive.busy { ProgressView(archive.status ?? L10n.tr("Restoring files…")) }
            if let error = archive.error { Label(error, systemImage: "exclamationmark.triangle").foregroundStyle(KeptoraDesign.danger) }
            if !archive.connectionErrors.isEmpty { Button("Add Folders…") { archive.chooseFolder() }.disabled(archive.sourceControlsDisabled) }
            Text(L10n.format("Recovery storage: %@", ByteCountFormatter.string(fromByteCount: archive.history.reduce(0) { $0 + ($1.folderRecord?.recoveryBytes ?? 0) }, countStyle: .file))).font(.headline)
            Text("Recovery files stay on their original storage until you restore them. They do not free disk space.").font(.caption).foregroundStyle(KeptoraDesign.secondaryInk)
            ForEach(archive.recoveryCatalogueIssues) { issue in
                VStack(alignment: .leading, spacing: 8) {
                    Label("A recovery record could not be read", systemImage: "exclamationmark.triangle").foregroundStyle(KeptoraDesign.warning)
                    Text("The files were kept. Open the recovery folder to inspect this record.").font(.caption)
                    Button("Show Recovery Folder") { NSWorkspace.shared.activateFileViewerSelecting([issue.manifestURL.deletingLastPathComponent()]) }
                }
                .padding(12)
                .keptoraGlass(cornerRadius: 14, tint: KeptoraDesign.warning)
            }
            if archive.history.isEmpty { Text("No manual cleanup history yet.").foregroundStyle(KeptoraDesign.secondaryInk) }
            ForEach(archive.history) { entry in
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { historyDetails(entry); Spacer(minLength: 12); recoveryAction(entry) }
                    VStack(alignment: .leading, spacing: 12) { historyDetails(entry); recoveryAction(entry) }
                }
                .padding(16)
                .keptoraGlass(cornerRadius: 16, tint: entry.isPhotos ? KeptoraDesign.coral : KeptoraDesign.cyan)
            }
        }.controlSize(.large).padding(20).task { await archive.verifyRecoveryCatalogue() }
    }
    private func historyDetails(_ entry: MacRecoveryEntry) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.date.formatted()).font(.headline)
            Text(L10n.plural("%lld items", entry.folderRecord.map { $0.restoredAt == nil ? $0.movedCount : $0.operations.count } ?? entry.count))
            if let record = entry.folderRecord {
                Text(L10n.format("Planned: %lld · In recovery: %lld · Needs attention: %lld", record.operations.count, record.movedCount, record.unresolvedCount)).font(.caption)
                Text(ByteCountFormatter.string(fromByteCount: record.recoveryBytes, countStyle: .file)).font(.caption)
            }
            if entry.isPhotos, entry.operationState == .planned { Label("Interrupted Photos request. Check Recently Deleted before trying again.", systemImage: "exclamationmark.triangle") }
            if entry.isPhotos, entry.operationState == .failed { Label("Removal was not completed.", systemImage: "exclamationmark.triangle") }
            Label(entry.isPhotos ? LocalizedStringKey("Recently Deleted in Photos") : LocalizedStringKey("Recovery Folder"), systemImage: entry.isPhotos ? "photo" : "folder")
            Text(entry.isPhotos ? "Recover items in Apple Photos → Recently Deleted for up to 30 days unless permanently deleted sooner." : "Files remain in the recovery folder on the same storage.").font(.callout).foregroundStyle(KeptoraDesign.secondaryInk)
        }
    }
    @ViewBuilder private func recoveryAction(_ entry: MacRecoveryEntry) -> some View {
        if entry.isPhotos {
            Button("Open Apple Photos") { NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/Photos.app")) }
        } else if entry.folderRecord?.restoredAt != nil { Label("Restored", systemImage: "checkmark.circle") }
        else {
            HStack(spacing: 12) {
                Button("Restore Files") { Task { await archive.restore(entry) } }.disabled(!archive.canRemoveSelection)
                Button("Show Recovery Folder") { archive.revealRecovery(entry) }
            }
        }
    }
}

struct CombinedCleanupHistoryView: View {
    var body: some View { ScrollView { MacManualHistoryView() } }
}
