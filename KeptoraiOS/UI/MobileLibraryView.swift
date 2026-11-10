import KeptoraCore
import SwiftUI
import UIKit

struct MobileScanSourcesSection: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    private var masterSymbol: String {
        switch store.sourceSelectionState {
        case .none: return "square"
        case .some: return "minus.square.fill"
        case .all: return "checkmark.square.fill"
        }
    }
    private var masterValue: LocalizedStringKey {
        switch store.sourceSelectionState {
        case .none: return "Not selected"
        case .some: return "Partially selected"
        case .all: return "Selected"
        }
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button { store.toggleAllScanSources() } label: {
                HStack(spacing: 12) {
                    Image(systemName: masterSymbol).font(.title3).foregroundStyle(MobileKeptoraDesign.accent)
                    Text("All Connected Sources").font(.headline)
                    Spacer(minLength: 0)
                }.frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityValue(Text(masterValue)).accessibilityIdentifier("sources.selectAll")
                .disabled(store.sourceControlsDisabled || LibrarySourceSelection().selectedIDs(in: store.connectedSources, coverage: store.coverage).isEmpty)
            Divider()
            ForEach(store.connectedSources) { source in
                let report = store.coverage.first { $0.id == source.id }
                let available = report == nil || report?.authorization == .authorized || report?.authorization == .limited
                let selected = store.selectedSourceIDs.contains(source.id)
                Button { store.toggleScanSource(source.id) } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: selected ? "checkmark.square.fill" : "square")
                            .font(.title3).foregroundStyle(selected ? MobileKeptoraDesign.accent : Color.secondary)
                        Image(systemName: source.scanSymbol).foregroundStyle(MobileKeptoraDesign.secondaryInk).frame(width: 22)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.kind == .photos ? L10n.tr("Photos / iCloud Photos") : source.displayName).font(.subheadline.weight(.semibold))
                            if let report {
                                (report.error == nil ? Text(L10n.plural("%lld items", report.itemCount)) : Text("Count incomplete"))
                                    .font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                                Text(LocalizedStringKey(report.statusKey)).font(.caption)
                                    .foregroundStyle(report.error != nil || report.authorization == .limited ? MobileKeptoraDesign.warning : Color.secondary)
                            } else { Text("Loading item count…").font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk) }
                        }
                        Spacer(minLength: 0)
                    }.padding(.vertical, 10).frame(maxWidth: .infinity, minHeight: 54, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).disabled(store.sourceControlsDisabled || !available)
                    .accessibilityValue(Text(selected ? LocalizedStringKey("Selected") : LocalizedStringKey("Not selected")))
                    .accessibilityIdentifier("sources.source." + source.id)
            }
            Divider()
            if store.selectedSourceIDs.isEmpty {
                Text("Select at least one source").font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                    .padding(.top, 12).accessibilityIdentifier("sources.emptySelection")
            } else {
                Text(store.selectedSourceIDs.count == 1
                     ? L10n.format("1 source selected · %lld different items", store.scopedAssets.count)
                     : L10n.format("%lld sources selected · %lld different items", store.selectedSourceIDs.count, store.scopedAssets.count))
                    .font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk).padding(.top, 12).accessibilityIdentifier("sources.summary")
            }
            // These only matter once there is more than one source to combine.
            if store.connectedSources.count > 1 {
                Text("Selected sources appear together. The same item in overlapping folders is counted once.")
                    .font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk).padding(.top, 6)
                Text("Unticking a source keeps its connection. You can include it again later.").font(.caption).foregroundStyle(MobileKeptoraDesign.secondaryInk).padding(.top, 6)
            }
        }
        .padding(16)
        .keptoraMobileGlass(cornerRadius: 18, tint: MobileKeptoraDesign.accent)
    }
}

struct MobileSourceLibraryView: View {
    var onChooseFolder: (() -> Void)? = nil
    var isStartupSetup = false
    @EnvironmentObject private var store: MobileKeptoraStore
    @State private var showFolderPicker = false

    private var photosConnected: Bool { store.connectedSources.contains { $0.id == LibrarySource.photos.id } }
    private var controlsDisabled: Bool { store.isCleaningUp || store.scanState.isScanning || store.isAnalyzing || store.isRequestingPhotosAccess || store.isLoadingCatalogue }

    var body: some View {
        ZStack {
            MobileAuroraBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    if isStartupSetup {
                        Image("onboarding_privacy").resizable().scaledToFit().frame(maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 20)).accessibilityHidden(true)
                        Text("Connect your library").font(.title2.bold())
                        Text("Connect Photos and folders once. Choose which sources to include in each scan.").foregroundStyle(MobileKeptoraDesign.secondaryInk)
                        if store.isRequestingPhotosAccess { ProgressView("Waiting for Photos access…") }
                    }
                    sourceSection.disabled(controlsDisabled)
                    if !store.connectedSources.isEmpty {
                        MobileScanSourcesSection()
                    }
                    if isStartupSetup { Text("You can continue without access and add sources later.").font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk) }
                    privacyStrip
                    // Background on access and cloud folders stays one tap away instead of filling the screen.
                    DisclosureGroup("Details") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Full Photos access includes iCloud Photos. Limited access shows only the items you approve.")
                            Text("Add folders from iCloud Drive, On My iPhone, or another provider in Files. Selected sources appear together in your library.")
                            Text("Cloud providers may download files according to their own settings.")
                            Text("No camera, microphone, contacts or live location permission is needed. Existing photo details are read only from media you approve.")
                        }.font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk).padding(.top, 6)
                    }.font(.subheadline)
                }
                .padding(.horizontal, MobileKeptoraDesign.pagePadding)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Sources")
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isStartupSetup ? "ios.sourceSetup" : "ios.page.library")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if isStartupSetup {
                VStack {
                    Button {
                        store.completeSourceSetup()
                    } label: {
                        Text("Continue to Library")
                    }
                    .buttonStyle(MobilePrimaryButtonStyle(fillsWidth: true))
                    .disabled(store.isRequestingPhotosAccess)
                    .accessibilityIdentifier("ios.sourceSetup.continue")
                }
                .padding()
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    LinearGradient(
                        colors: [Color.white.opacity(0.28), Color.white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .frame(height: 1)
                }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("ios.sourceSetup.actions")
            }
        }
        .interactiveDismissDisabled(isStartupSetup)
        .sheet(isPresented: $showFolderPicker) {
            DirectoryPicker { url in
                showFolderPicker = false
                if let url { store.connectFolder(url) }
            }
        }
        .task {
            if isStartupSetup, LibraryAccessPolicy.shouldRequestPhotosAtStartup(store.authorization) {
                await store.connectPhotos()
            }
        }
        .alert("Photos Access Needed", isPresented: $store.isShowingPhotosPermissionHelp) {
            if store.canOpenPhotosSettings {
                Button("Open Settings") { store.openPhotosSettings() }
                    .accessibilityIdentifier("ios.photosPermission.openSettings")
            }
            Button("Not Now", role: .cancel) { }
                .accessibilityIdentifier("ios.photosPermission.notNow")
        } message: {
            Text(store.photosPermissionHelpMessage)
        }
    }

    // MARK: – Source Section

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(MobileKeptoraDesign.accent).frame(width: 5, height: 5)
                Text("Sources")
                    .font(MobileKeptoraDesign.labelFont)
                    .tracking(1.4)
                    .foregroundStyle(MobileKeptoraDesign.accent)
            }
            .padding(.leading, 4)

            if !photosConnected {
                Button { Task { await store.connectPhotos() } } label: {
                    sourceCard(
                        title: "Photos",
                        subtitle: photosConnected ? Text("Connected") : Text("Photos and videos on this device"),
                        image: "photo.on.rectangle.angled",
                        selected: photosConnected,
                        tint: MobileKeptoraDesign.accent
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("library.source.photos")
            }

            if store.authorization == .limited {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.headline)
                            .foregroundStyle(MobileKeptoraDesign.amber)
                        
                        Text("Limited Photos access")
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        
                        Spacer()
                        
                        Button("Manage Access") { store.manageLimitedPhotosAccess() }
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(MobileKeptoraDesign.accent)
                            .buttonStyle(MobileActionButtonStyle())
                            .accessibilityIdentifier("ios.library.managePhotosAccess")
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "photo.badge.exclamationmark")
                                .font(.headline)
                                .foregroundStyle(MobileKeptoraDesign.amber)
                            Text("Limited Photos access")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        }
                        Button("Manage Access") { store.manageLimitedPhotosAccess() }
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .foregroundStyle(MobileKeptoraDesign.accent)
                            .buttonStyle(MobileActionButtonStyle())
                            .accessibilityIdentifier("ios.library.managePhotosAccess")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .keptoraMobileGlass(cornerRadius: 14, tint: MobileKeptoraDesign.amber)
            }

            if store.authorization == .denied || store.authorization == .restricted {
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        Image(systemName: "hand.raised.fill")
                            .font(.headline)
                            .foregroundStyle(MobileKeptoraDesign.danger)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.authorization == .denied ? LocalizedStringKey("Photos access disabled") : LocalizedStringKey("Photos access restricted"))
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.primary)
                            
                            Text(photosAccessHint)
                                .font(.system(.caption, design: .rounded))
                                .foregroundStyle(Color.secondary)
                        }
                        
                        Spacer()
                        
                        if store.canOpenPhotosSettings {
                            Button("Open Settings") { store.openPhotosSettings() }
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(MobileKeptoraDesign.accent)
                                .buttonStyle(MobileActionButtonStyle())
                                .accessibilityIdentifier("ios.library.openSettings")
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "hand.raised.fill")
                                .font(.headline)
                                .foregroundStyle(MobileKeptoraDesign.danger)
                            Text(store.authorization == .denied ? LocalizedStringKey("Photos access disabled") : LocalizedStringKey("Photos access restricted"))
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(Color.primary)
                        }
                        Text(photosAccessHint)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(Color.secondary)
                        if store.canOpenPhotosSettings {
                            Button("Open Settings") { store.openPhotosSettings() }
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                .foregroundStyle(MobileKeptoraDesign.accent)
                                .buttonStyle(MobileActionButtonStyle())
                                .accessibilityIdentifier("ios.library.openSettings")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .keptoraMobileGlass(cornerRadius: 14, tint: MobileKeptoraDesign.danger)
            }

            ForEach(store.connectedFolders) { folder in
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { connectedFolderControls(folder) }
                    VStack(alignment: .leading, spacing: 8) { connectedFolderControls(folder) }
                }
            }
            Button(action: chooseFolder) {
                sourceCard(
                    title: "Add Files or Cloud Folder",
                    subtitle: Text("Choose a folder or connected drive"),
                    image: "folder.badge.plus",
                    selected: !store.connectedFolders.isEmpty,
                    tint: MobileKeptoraDesign.cyan
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("library.source.files")
        }
    }
    @ViewBuilder private func connectedFolderControls(_ folder: LibrarySource) -> some View {
        Label(folder.displayName, systemImage: "folder")
        Button("Disconnect") { store.disconnectFolder(folder.id) }.buttonStyle(MobileActionButtonStyle())
    }

    private func chooseFolder() {
        if let onChooseFolder { onChooseFolder() }
        else if isStartupSetup { showFolderPicker = true }
        else { store.present(.filePicker) }
    }

    private var photosAccessHint: LocalizedStringKey {
        store.authorization == .denied
            ? "Allow access in Settings to scan Photos."
            : "Access is restricted on this device."
    }

    private func sourceCard(title: LocalizedStringKey, subtitle: Text, image: String, selected: Bool, tint: Color) -> some View {
        HStack(spacing: 15) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(
                        selected
                        ? AnyShapeStyle(LinearGradient(colors: [tint, MobileKeptoraDesign.violet], startPoint: .topLeading, endPoint: .bottomTrailing))
                        : AnyShapeStyle(tint.opacity(0.13))
                    )
                
                Image(systemName: image)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(selected ? Color.white : tint)
            }
            .frame(width: 54, height: 54)
            .shadow(color: selected ? tint.opacity(0.35) : Color.clear, radius: 10, y: 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.semibold))
                    .foregroundStyle(.primary)
                
                subtitle
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(MobileKeptoraDesign.secondaryInk)
                    .lineLimit(2)
            }

            Spacer()

            if selected {
                ZStack {
                    Circle().fill(MobileKeptoraDesign.mint.opacity(0.14))
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(MobileKeptoraDesign.mint)
                }
                .frame(width: 32, height: 32)
            } else {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .keptoraMobileGlass(cornerRadius: MobileKeptoraDesign.cardRadius, tint: tint, isSelected: selected)
        .contentShape(Rectangle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: – Privacy Strip

    private var privacyStrip: some View {
        HStack(spacing: 10) {
            ZStack {
                Circle().fill(MobileKeptoraDesign.accent.opacity(0.12))
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(MobileKeptoraDesign.accent)
            }
            .frame(width: 30, height: 30)

            Text("Private by design. No account, ads, analytics, or photo upload.")
                .font(.system(.caption, design: .rounded).weight(.medium))
                .foregroundStyle(MobileKeptoraDesign.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .keptoraMobileGlass(cornerRadius: 16, tint: MobileKeptoraDesign.accent)
    }
}
