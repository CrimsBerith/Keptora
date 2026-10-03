import KeptoraCore
import SwiftUI
import UIKit

struct MobileSourceLibraryView: View {
    var onChooseFolder: (() -> Void)? = nil
    var isStartupSetup = false
    @EnvironmentObject private var store: MobileKeptoraStore
    @AppStorage(AppStorageKeys.iOSSourceSetupCompleted) private var sourceSetupCompleted = false
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
                        Text("Approve Photos and connect folders once. Future scans combine every connected source.").foregroundStyle(.secondary)
                        if store.isRequestingPhotosAccess { ProgressView("Waiting for Photos access…") }
                    }
                    sourceSection.disabled(controlsDisabled)
                    MobileWhatsAppAccessGuide(onChooseFolder: chooseFolder).disabled(controlsDisabled)
                    Text("No camera, microphone, contacts or live location permission is needed. Existing photo details are read only from media you approve.").font(.footnote).foregroundStyle(.secondary)
                    if isStartupSetup { Text("You can continue without access and add sources later.").font(.footnote).foregroundStyle(.secondary) }
                    privacyStrip
                }
                .padding(.horizontal, MobileKeptoraDesign.pagePadding)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Sources")
        .accessibilityIdentifier(isStartupSetup ? "ios.sourceSetup" : "ios.page.library")
        .navigationBarTitleDisplayMode(.inline)
        .safeAreaInset(edge: .bottom) {
            if isStartupSetup {
                Button {
                    sourceSetupCompleted = true
                    store.dismissModal()
                } label: {
                    Text("Continue to Library").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .padding().background(.regularMaterial).disabled(store.isRequestingPhotosAccess)
                .accessibilityIdentifier("ios.sourceSetup.continue")
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

            Button { Task { await store.connectPhotos() } } label: {
                sourceCard(
                    title: "Photos",
                    subtitle: photosConnected ? Text("Connected") : Text("Photos and videos on this device"),
                    image: "photo.on.rectangle.angled",
                    selected: photosConnected,
                    tint: MobileKeptoraDesign.coral
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("library.source.photos")

            Text("Full Photos access includes iCloud Photos and WhatsApp media saved to Photos. Limited access shows only the items you approve.").font(.footnote).foregroundStyle(.secondary)
            if store.authorization == .limited, photosConnected {
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
                            .frame(minHeight: 44)
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
                            .frame(minHeight: 44)
                            .accessibilityIdentifier("ios.library.managePhotosAccess")
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MobileKeptoraDesign.amber.opacity(0.12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(MobileKeptoraDesign.amber.opacity(0.3), lineWidth: 0.8)
                        )
                )
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
                                .frame(minHeight: 44)
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
                                .frame(minHeight: 44)
                                .accessibilityIdentifier("ios.library.openSettings")
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(MobileKeptoraDesign.danger.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(MobileKeptoraDesign.danger.opacity(0.2), lineWidth: 0.8)
                        )
                )
            }

            Text("Connected sources are scanned together. Add folders from iCloud Drive, On My iPhone, or another provider in Files once; keep them connected for future scans.")
                .font(.footnote).foregroundStyle(.secondary)
            Text("Cloud providers may download files according to their own settings.").font(.footnote).foregroundStyle(.secondary)
            ForEach(store.connectedFolders) { folder in
                HStack {
                    Label(folder.displayName, systemImage: "folder")
                    Spacer()
                    Button("Disconnect") { store.disconnectFolder(folder.id) }.font(.footnote).frame(minHeight: 44)
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
                    .foregroundStyle(.secondary)
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
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: MobileKeptoraDesign.cardRadius, style: .continuous))
        .background(
            selected ? tint.opacity(0.08) : Color(uiColor: .secondarySystemGroupedBackground).opacity(0.70),
            in: RoundedRectangle(cornerRadius: MobileKeptoraDesign.cardRadius, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: MobileKeptoraDesign.cardRadius, style: .continuous)
                .stroke(
                    selected
                    ? LinearGradient(colors: [tint, MobileKeptoraDesign.violet], startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.32), Color.primary.opacity(0.05)], startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: selected ? 1.5 : 1
                )
        }
        .shadow(color: selected ? tint.opacity(0.18) : Color.black.opacity(0.03), radius: 16, y: 7)
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
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .background(MobileKeptoraDesign.accent.opacity(0.06), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(MobileKeptoraDesign.accent.opacity(0.18), lineWidth: 1)
        }
    }
}

struct MobileWhatsAppAccessGuide: View {
    let onChooseFolder: () -> Void
    @State private var cannotOpenWhatsApp = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("WhatsApp storage & chat media", systemImage: "bubble.left.and.bubble.right").font(.headline)
            Text("Keptora can clean copies saved in Photos or folders you choose. It cannot access WhatsApp's private chat storage.")
            Text("To manage media kept inside WhatsApp, open WhatsApp → Settings → Storage and Data → Manage Storage.")
            Button("Open WhatsApp") {
                guard let url = URL(string: "whatsapp://") else { return }
                UIApplication.shared.open(url, options: [:]) { opened in
                    Task { @MainActor in cannotOpenWhatsApp = !opened }
                }
            }.frame(minHeight: 44).accessibilityIdentifier("ios.whatsapp.open")
            Text("To view chat media here: in WhatsApp, export the chat with media, save it to Files, extract the ZIP, then connect the extracted folder. Keptora displays the exported photos and videos.")
            Button("Choose an Exported Folder", action: onChooseFolder).frame(minHeight: 44)
                .accessibilityIdentifier("ios.whatsapp.exportedFolder")
            Text("Removing exported or saved copies does not free the original WhatsApp chat storage.").font(.footnote).foregroundStyle(.secondary)
        }
        .font(.subheadline).padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
        .alert("WhatsApp could not be opened", isPresented: $cannotOpenWhatsApp) {
            Button("OK", role: .cancel) { }
        } message: { Text("Open WhatsApp manually if it is installed on this device.") }
    }
}
