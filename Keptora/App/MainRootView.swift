import KeptoraCore
import SwiftUI

struct MainRootView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

    private let primaryRoutes: [SidebarRoute] = [.archive, .history]

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                brandHeader

                VStack(alignment: .leading, spacing: 2) {
                    sidebarSection("Workspace", routes: primaryRoutes)

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .padding(.horizontal, 9)

                proFooter
            }
            .background(KeptoraSidebarBackdrop())
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
        .onAppear {
            archive.undoManager = undoManager
        }
        .keptoraOnChange(of: scenePhase) { phase in
            if phase != .active { Task { await archive.flushState() } }
            else if startupSourcesPrepared { Task { await archive.refreshPhotosAccess() } }
        }
        .alert("Something went wrong", isPresented: archive.errorBinding(for: .main)) {
            if archive.canRepairPersistence {
                Button("Save Current Session") { Task { await archive.repairPersistence() } }
            }
            Button("OK", role: .cancel) { archive.error = nil }
        } message: { Text(archive.error ?? "") }
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
                    .foregroundStyle(KeptoraDesign.accentGradient)
                Text("Photo & video intelligence")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
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
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.secondary)
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
                Spacer()
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
                    ? KeptoraDesign.accent.opacity(0.13)
                    : (isHovered ? Color.primary.opacity(0.04) : Color.clear),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .keptoraAnimation(KeptoraDesign.animFast, value: isHovered)
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? KeptoraDesign.accent.opacity(0.20) : Color.clear)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hoveredRoute = $0 ? route : nil }
        .accessibilityIdentifier("mac.sidebar.\(route.rawValue)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var proFooter: some View {
        Divider()
        if store.isLifetimeUnlocked {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(KeptoraDesign.success)
                Text("Keptora Pro")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(KeptoraDesign.success)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Button {
                store.presentPaywall(.settings)
            } label: {
                Label("Unlock Keptora Pro", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(KeptoraDesign.accent)
            .controlSize(.regular)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .accessibilityIdentifier("mac.paywall.open")
        }
    }

    @ViewBuilder
    private var routeDetail: some View {
        switch navigation.selectedRoute {
        case .archive: MacArchiveView()
        case .history: CombinedCleanupHistoryView()
        }
    }
}
