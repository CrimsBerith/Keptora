import KeptoraCore
import SwiftUI

struct MainRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var navigation: MacNavigation
    @EnvironmentObject private var store: StoreEntitlementController
    @EnvironmentObject private var archive: MacArchiveModel
    @Environment(\.undoManager) private var undoManager
    @State private var hoveredRoute: SidebarRoute?
    @State private var isDropTargeted: Bool = false
    @AppStorage(AppStorageKeys.macSourceSetupCompleted) private var sourceSetupCompleted = false
    @State private var startupSourcesPrepared = false
    @State private var showSourceSetup = false

    private let libraryRoutes: [SidebarRoute] = [.archive]
    private let cleanupRoutes: [SidebarRoute] = [.exact, .similar, .bursts, .screenshots, .videos, .review]
    private let activityRoutes: [SidebarRoute] = [.history]

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                brandHeader

                proHeader
                    .padding(.horizontal, 10)
                    .padding(.bottom, 6)

                VStack(alignment: .leading, spacing: 2) {
                    sidebarSection("Library", routes: libraryRoutes)
                    sidebarSection("Smart Cleanup", routes: cleanupRoutes)
                    sidebarSection("Activity", routes: activityRoutes)

                    Spacer(minLength: 0)
                }
                .padding(.top, 4)
                .padding(.horizontal, 9)
            }
            .background(KeptoraSidebarBackdrop())
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Workspace")
            .navigationSplitViewColumnWidth(min: 184, ideal: 208, max: 232)
        } detail: {
            ZStack {
                KeptoraBackdrop()
                VStack(spacing: 0) {
                    MacSessionHealthBanner()
                    routeDetail.frame(maxWidth: .infinity, maxHeight: .infinity)
                }.environmentObject(archive)

                if isDropTargeted {
                    ZStack {
                        Color.accentColor.opacity(0.08)
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10]))
                            .padding(14)
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 46))
                                .foregroundStyle(Color.accentColor)
                            Text("Drop Folder to Connect")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.primary)
                        }
                    }
                    .transition(.opacity)
                    .allowsHitTesting(false)
                }
            }
            .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                guard let provider = providers.first else { return false }
                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                    guard let url else { return }
                    var isDir: ObjCBool = false
                    if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDir), isDir.boolValue {
                        Task { @MainActor in
                            archive.connectFolder(url)
                            navigation.selectedRoute = .archive
                        }
                    } else {
                        Task { @MainActor in
                            archive.error = L10n.tr("Please drop a folder to scan, not an individual file.")
                        }
                    }
                }
                return true
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 650)
        .background(MacMainWindowMarker())
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Keptora")
        .accessibilityIdentifier("keptora.root")
        .sheet(isPresented: store.paywallBinding(for: .main)) {
            PaywallView().environmentObject(store)
        }
        .sheet(isPresented: $showSourceSetup) {
            MacSourceSetupView(isStartupSetup: true).environmentObject(archive)
        }
        .task {
            await archive.restoreConnections()
            startupSourcesPrepared = true
            presentStartupIfNeeded()
        }
        .keptoraOnChange(of: sourceSetupCompleted) { _ in presentStartupIfNeeded() }
        .keptoraOnChange(of: navigation.selectedRoute) { newRoute in applyRoute(newRoute) }
        .onAppear {
            archive.undoManager = undoManager
        }
        .keptoraOnChange(of: scenePhase) { phase in
            if phase != .active { Task { await archive.flushState() } }
            else if startupSourcesPrepared { Task { await archive.refreshPhotosAccess() } }
        }
        .alert(Text(archive.errorAlertParts.title), isPresented: archive.errorBinding(for: .main)) {
            if archive.canRepairPersistence {
                Button("Save Current Session") { Task { await archive.repairPersistence() } }
            }
            Button("OK", role: .cancel) { archive.error = nil }
        } message: { if let detail = archive.errorAlertParts.detail { Text(detail) } }
    }

    private func presentStartupIfNeeded() {
        guard startupSourcesPrepared, !LaunchArguments.contains(LaunchArguments.portfolioUITesting),
              !store.isShowingPaywall else { return }
        if LibraryAccessPolicy.needsStartupSetup(introductionCompleted: true, setupCompleted: sourceSetupCompleted) {
            showSourceSetup = true
        }
    }

    private var brandHeader: some View {
        HStack(spacing: 10) {
            KeptoraLogoMark(size: 40)
            VStack(alignment: .leading, spacing: 1) {
                Text("KEPTORA")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(KeptoraDesign.accent)
                Text("Photo & video intelligence")
                    .font(.caption2)
                    .foregroundStyle(KeptoraDesign.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
    }

    private func sidebarSection(_ label: LocalizedStringKey, routes: [SidebarRoute]) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .textCase(.uppercase)
                .font(.system(.caption2, design: .rounded, weight: .bold))
                .tracking(1.2)
                .foregroundStyle(KeptoraDesign.secondaryInk)
                .padding(.horizontal, 18)
                .padding(.bottom, 2)
                .padding(.top, 10)
            ForEach(routes) { route in
                sidebarButton(route)
            }
        }
    }

    private func sidebarButton(_ route: SidebarRoute) -> some View {
        let isSelected = navigation.selectedRoute == route
        let isHovered  = hoveredRoute == route
        return Button {
            withAnimation(reduceMotion ? nil : KeptoraDesign.animFast) { navigation.selectedRoute = route }
        } label: {
            HStack(spacing: 11) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isSelected
                              ? AnyShapeStyle(KeptoraDesign.iconGradient)
                              : AnyShapeStyle(Color.primary.opacity(isHovered ? 0.10 : 0.06)))
                    Image(systemName: route.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : .secondary)
                }
                .frame(width: 30, height: 30)
                .keptoraAnimation(KeptoraDesign.animFast, value: isSelected)
                Text(route.title)
                    .font(.system(.body, design: .rounded).weight(isSelected ? .semibold : .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Spacer()
                if let count = routeBadgeCount(route) {
                    Text(verbatim: "\(count)")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(isSelected ? Color.white : KeptoraDesign.secondaryInk)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(
                            isSelected ? Color.white.opacity(0.2) : Color.primary.opacity(0.06),
                            in: Capsule()
                        )
                }
                if isSelected {
                    Circle()
                        .fill(KeptoraDesign.cyan)
                        .frame(width: 6, height: 6)
                        .shadow(color: KeptoraDesign.cyan.opacity(0.7), radius: 4)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(
                isSelected
                    ? (reduceTransparency ? KeptoraDesign.accent.opacity(0.24) : KeptoraDesign.accent.opacity(0.16))
                    : (isHovered ? (reduceTransparency ? Color.secondary.opacity(0.14) : Color.primary.opacity(0.06)) : Color.clear),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .keptoraAnimation(KeptoraDesign.animFast, value: isHovered)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(
                        sidebarBorder(isSelected: isSelected, isHovered: isHovered),
                        lineWidth: isSelected ? 1.5 : 1.0
                    )
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredRoute = $0 ? route : nil }
        .accessibilityIdentifier("mac.sidebar.\(route.rawValue)")
        .accessibilityLabel(Text(routeBadgeCount(route).map { "\(route.localizedTitle), \($0) items" } ?? route.localizedTitle))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func sidebarBorder(isSelected: Bool, isHovered: Bool) -> AnyShapeStyle {
        if reduceTransparency {
            if isSelected { return AnyShapeStyle(KeptoraDesign.accent) }
            if isHovered { return AnyShapeStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.22)) }
            return AnyShapeStyle(Color.clear)
        }
        if isSelected {
            return AnyShapeStyle(LinearGradient(colors: [KeptoraDesign.cyan.opacity(0.65), KeptoraDesign.accent.opacity(0.40)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        if isHovered {
            return AnyShapeStyle(LinearGradient(colors: [Color.white.opacity(colorScheme == .dark ? 0.24 : 0.60), Color.white.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        return AnyShapeStyle(Color.clear)
    }

    private func routeBadgeCount(_ route: SidebarRoute) -> Int? {
        switch route {
        case .archive:
            return archive.scopedAssets.count > 0 ? archive.scopedAssets.count : nil
        case .exact:
            let count = archive.gallery.findingCounts[.copies] ?? 0
            return count > 0 ? count : nil
        case .similar:
            let count = archive.gallery.findingCounts[.verySimilar] ?? 0
            return count > 0 ? count : nil
        case .bursts:
            let count = archive.gallery.findingCounts[.bursts] ?? 0
            return count > 0 ? count : nil
        case .screenshots:
            let count = archive.scopedAssets.filter { $0.context?.isScreenshot == true }.count
            return count > 0 ? count : nil
        case .videos:
            let count = archive.scopedAssets.filter { $0.mediaKind == .video }.count
            return count > 0 ? count : nil
        case .review:
            let count = archive.gallery.findingCounts[.review] ?? 0
            return count > 0 ? count : nil
        case .history:
            return archive.history.count > 0 ? archive.history.count : nil
        }
    }

    private func applyRoute(_ route: SidebarRoute) {
        archive.galleryContext.screenshotsOnly = (route == .screenshots)
        switch route {
        case .archive:
            archive.galleryContext.finding = .all
            archive.galleryContext.media = 0
            archive.contextChanged()
        case .exact:
            archive.openFinding(.copies)
        case .similar:
            archive.openFinding(.verySimilar)
        case .bursts:
            archive.openFinding(.bursts)
        case .screenshots:
            archive.galleryContext.search = ""
            archive.galleryContext.media = 0
            archive.galleryContext.finding = .all
            archive.contextChanged()
        case .videos:
            archive.galleryContext.search = ""
            archive.galleryContext.media = 2
            archive.galleryContext.finding = .all
            archive.contextChanged()
        case .review:
            archive.openFinding(.review)
        case .history:
            break
        }
    }

    @ViewBuilder
    private var proHeader: some View {
        if store.isLifetimeUnlocked {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(KeptoraDesign.success)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Keptora Pro")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(KeptoraDesign.success)
                    Text("Lifetime Unlocked")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(KeptoraDesign.secondaryInk)
                }
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(KeptoraDesign.success.opacity(0.08))
            )
            .accessibilityIdentifier("mac.pro.unlockedBadge")
        } else {
            Button {
                store.presentPaywall(.settings)
            } label: {
                HStack(spacing: 8) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(KeptoraDesign.iconGradient)
                        Image(systemName: "sparkles")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 26, height: 26)

                    VStack(alignment: .leading, spacing: 1) {
                        Text("Unlock Keptora Pro")
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(.primary)
                        Text("Unlimited cleanup & tools")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(KeptoraDesign.secondaryInk)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(KeptoraDesign.secondaryInk)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            reduceTransparency
                                ? AnyShapeStyle(KeptoraDesign.elevated)
                                : AnyShapeStyle(.ultraThinMaterial.opacity(0.6))
                        )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(KeptoraDesign.borderGradient, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("mac.paywall.open")
        }
    }

    @ViewBuilder
    private var routeDetail: some View {
        switch navigation.selectedRoute {
        case .archive, .exact, .similar, .bursts, .screenshots, .videos, .review:
            MacArchiveView()
        case .history:
            CombinedCleanupHistoryView()
        }
    }
}
