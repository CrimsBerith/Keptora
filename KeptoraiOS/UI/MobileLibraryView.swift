import KeptoraCore
import SwiftUI

struct MobileLibraryView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @EnvironmentObject private var purchase: MobilePurchaseController
    @State private var showCloudDownloadConfirmation = false

    var body: some View {
        ZStack {
            MobileAuroraBackground()
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    hero
                    sourceSection
                    if store.source != .none { scanSection }
                    if !store.exactGroups.isEmpty {
                        resultSection
                    } else if store.scanState == .completed && !store.isAnalyzing {
                        noDuplicatesSection
                    }
                    privacyStrip
                }
                .padding(.horizontal, MobileKeptoraDesign.pagePadding)
                .padding(.bottom, 24)
            }
        }
        .navigationTitle("Library")
        .accessibilityIdentifier("ios.page.library")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { store.present(.settings) } label: {
                    ZStack {
                        Circle().fill(MobileKeptoraDesign.brandGradient)
                        Image(systemName: purchase.isUnlocked ? "checkmark.seal.fill" : "person.crop.circle.fill")
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
        .confirmationDialog(
            "Download iCloud originals?",
            isPresented: $showCloudDownloadConfirmation,
            titleVisibility: .visible
        ) {
            Button("Download and Scan") { store.startScan(allowNetwork: true) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This may use network data and device storage. You can cancel the scan at any time.")
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

    // MARK: – Hero Header

    private var hero: some View {
        ZStack(alignment: .bottomTrailing) {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(MobileKeptoraDesign.heroGradient)

            Circle()
                .fill(MobileKeptoraDesign.coral.opacity(0.24))
                .frame(width: 180, height: 180)
                .blur(radius: 12)
                .offset(x: 60, y: 60)

            Circle()
                .fill(MobileKeptoraDesign.cyan.opacity(0.18))
                .frame(width: 130, height: 130)
                .blur(radius: 18)
                .offset(x: -80, y: -40)

            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 108, weight: .ultraLight))
                .foregroundStyle(.white.opacity(0.09))
                .offset(x: -12, y: 14)

            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    MobileBrandMark(size: 40)
                    HStack(spacing: 5) {
                        if purchase.isUnlocked {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(MobileKeptoraDesign.cyan)
                        }
                        Text(purchase.isUnlocked ? "KEPTORA PRO" : "KEPTORA")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .tracking(1.8)
                            .foregroundStyle(.white.opacity(0.90))
                    }
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.12), in: Capsule())
                    .overlay { Capsule().stroke(.white.opacity(0.20), lineWidth: 1) }
                }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Make room for what matters.")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.8)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(22)
        }
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.35), Color.white.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: MobileKeptoraDesign.violet.opacity(0.26), radius: 26, y: 12)
        .padding(.top, 4)
    }

    // MARK: – Source Section

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Circle().fill(MobileKeptoraDesign.accent).frame(width: 5, height: 5)
                Text("YOUR LIBRARY")
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

            Button { store.present(.filePicker) } label: {
                sourceCard(
                    title: "Files and iCloud Drive",
                    subtitle: {
                        if case .folder(let url) = store.source { return Text(verbatim: url.lastPathComponent) }
                        return Text(LocalizedStringKey("Choose a folder or connected drive"))
                    }(),
                    image: "folder.badge.gearshape",
                    selected: {
                        if case .folder = store.source { return true }
                        return false
                    }(),
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

    // MARK: – Scan Section

    @ViewBuilder
    private var scanSection: some View {
        if store.isAnalyzing {
            // Exact scan is done but similarity passes still run: do not offer a new scan yet.
            HStack(spacing: 10) {
                ProgressView().tint(MobileKeptoraDesign.cyan)
                Text("Analyzing similar photos and videos…")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer()
                Button("Cancel", role: .cancel) { store.cancelScan() }
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundStyle(MobileKeptoraDesign.danger)
                    .frame(minHeight: 44)
            }
            .keptoraPanel(tint: MobileKeptoraDesign.cyan)
            .accessibilityElement(children: .combine)
        } else {
            scanStateSection
        }
    }

    @ViewBuilder
    private var scanStateSection: some View {
        switch store.scanState {
        case .scanning(let processed, let total, let current):
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.85)
                            .tint(MobileKeptoraDesign.cyan)
                        Text("Scanning \(store.source.title)")
                            .font(.system(.headline, design: .rounded).weight(.semibold))
                    }
                    Spacer()
                    Button("Cancel", role: .cancel) { store.cancelScan() }
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundStyle(MobileKeptoraDesign.danger)
                        .frame(minHeight: 44)
                }

                ProgressView(value: Double(processed), total: Double(max(total, 1)))
                    .tint(MobileKeptoraDesign.cyan)
                    .accessibilityLabel("Scan progress")
                    .accessibilityValue(String(format: String(localized: "%1$lld of %2$lld"), Int64(processed), Int64(total)))

                HStack {
                    Text("\(processed.formatted()) of \(total.formatted())")
                        .font(.system(.caption, design: .rounded).weight(.bold))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                    Spacer()
                    Text(current)
                        .font(.system(.caption, design: .rounded))
                        .lineLimit(1)
                }
                .foregroundStyle(.secondary)
            }
            .keptoraPanel(tint: MobileKeptoraDesign.cyan)

        case .failed(let message):
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title3)
                        .foregroundStyle(MobileKeptoraDesign.amber)
                    Text("Scan Interrupted")
                        .font(.system(.headline, design: .rounded).weight(.semibold))
                }
                Text(message)
                    .font(.system(.subheadline, design: .rounded))
                    .foregroundStyle(.secondary)
                Button {
                    store.startScan()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("Try Again")
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(MobilePrimaryButtonStyle())
            }
            .keptoraPanel(tint: MobileKeptoraDesign.amber)

        default:
            VStack(spacing: 12) {
                Button { store.startScan() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkle.magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                        if store.hasScanCheckpoint {
                            Text("Resume Scan")
                        } else if store.source == .photos {
                            Text("Scan Photos")
                        } else {
                            Text("Scan Files")
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 34)
                }
                .buttonStyle(MobilePrimaryButtonStyle())
                .accessibilityIdentifier("ios.library.scan")

                if store.skippedCloudItems > 0 {
                    Button {
                        showCloudDownloadConfirmation = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "icloud.and.arrow.down")
                                .font(.system(size: 13, weight: .semibold))
                            Text("Scan \(store.skippedCloudItems.formatted()) iCloud-only items")
                                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        }
                        .foregroundStyle(MobileKeptoraDesign.accent)
                        .padding(.vertical, 6)
                    }
                }
            }
        }
    }

    // MARK: – Results & Metrics

    private var resultSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Ready to review")
                        .font(.system(.title2, design: .rounded).weight(.bold))
                    Text("Only verified exact copies can enter cleanup.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                ZStack {
                    Circle().fill(MobileKeptoraDesign.mint.opacity(0.14))
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(MobileKeptoraDesign.mint)
                        .font(.title2)
                }
                .frame(width: 44, height: 44)
            }

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 12) {
                MobileMetricTile(
                    title: "Scanned",
                    value: store.dashboard.scannedItems.formatted(),
                    systemImage: "photo.stack",
                    tint: MobileKeptoraDesign.cyan
                )
                MobileMetricTile(
                    title: "Exact sets",
                    value: store.dashboard.exactGroups.formatted(),
                    systemImage: "square.on.square",
                    tint: MobileKeptoraDesign.violet
                )
                MobileMetricTile(
                    title: "Safe copies",
                    value: store.dashboard.safeCopies.formatted(),
                    systemImage: "checkmark.circle.fill",
                    tint: MobileKeptoraDesign.mint
                )
                MobileMetricTile(
                    title: "Potential space",
                    value: ByteCountFormatter.string(fromByteCount: store.dashboard.potentialRecoveryBytes, countStyle: .file),
                    systemImage: "internaldrive",
                    tint: MobileKeptoraDesign.coral
                )
            }

            Button {
                store.selectedTab = .review
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Start Review")
                        .font(.system(.headline, design: .rounded).weight(.bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity, minHeight: 34)
            }
            .buttonStyle(MobilePrimaryButtonStyle())
            .accessibilityIdentifier("ios.library.startReview")
        }
        .keptoraPanel(tint: MobileKeptoraDesign.mint)
    }

    /// Shown when a scan finished without finding any exact copies, so the screen is not just blank.
    private var noDuplicatesSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(MobileKeptoraDesign.mint)
                .accessibilityHidden(true)
            Text("No exact copies found")
                .font(.system(.title3, design: .rounded).weight(.bold))
            Text("Nothing in \(store.source.title) is a byte-identical duplicate.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            if !store.similarVideoGroups.isEmpty || !store.similarityGroups.isEmpty {
                let count = store.similarVideoGroups.count + store.similarityGroups.count
                Button {
                    store.selectedTab = .review
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                        Text("Review \(count) Similar Sets")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 38)
                }
                .buttonStyle(MobilePrimaryButtonStyle())
                .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .keptoraPanel(tint: MobileKeptoraDesign.mint)
        .accessibilityElement(children: .combine)
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
