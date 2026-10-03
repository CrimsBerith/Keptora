import KeptoraCore
import SwiftUI

struct MobileSourceLibraryView: View {
    var onChooseFolder: (() -> Void)? = nil
    @EnvironmentObject private var store: MobileKeptoraStore

    var body: some View {
        ZStack {
            MobileAuroraBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    sourceSection.disabled(store.isCleaningUp || store.scanState.isScanning || store.isAnalyzing)
                    privacyStrip
                }
                .padding(.horizontal, MobileKeptoraDesign.pagePadding)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Sources")
        .accessibilityIdentifier("ios.page.library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.present(.settings) } label: {
                    ZStack {
                        Circle().fill(MobileKeptoraDesign.brandGradient)
                        Image(systemName: "gearshape.fill")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 36, height: 36)
                    .shadow(color: MobileKeptoraDesign.violet.opacity(0.30), radius: 8, y: 3)
                    .padding(4)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("Settings")
                .accessibilityIdentifier("ios.library.settings")
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
                    subtitle: store.source == .photos ? Text("Connected") : Text("Photos and videos on this device"),
                    image: "photo.on.rectangle.angled",
                    selected: store.source == .photos,
                    tint: MobileKeptoraDesign.coral
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("library.source.photos")

            if store.authorization == .limited, store.source == .photos {
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

            if (store.source == .photos || store.source == .none) && (store.authorization == .denied || store.authorization == .restricted) {
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
            Button { if let onChooseFolder { onChooseFolder() } else { store.present(.filePicker) } } label: {
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
