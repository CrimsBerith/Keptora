import SwiftUI

struct MainRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController
    @State private var hoveredRoute: SidebarRoute?
    @State private var isDropTargeted: Bool = false

    private let primaryRoutes: [SidebarRoute] = [.home, .review, .smartBuckets, .history]
    private let toolRoutes:    [SidebarRoute] = [.insights]

    var body: some View {
        NavigationSplitView {
            VStack(spacing: 0) {
                brandHeader

                VStack(alignment: .leading, spacing: 2) {
                    sidebarSection("Workspace", routes: primaryRoutes)

                    sidebarSection("Tools", routes: toolRoutes)

                    Spacer(minLength: 0)
                }
                .padding(.top, 8)
                .padding(.horizontal, 9)

                proFooter
                    .sheet(isPresented: $model.isShowingRestorePreview) {
                        RestorePreviewSheet().environmentObject(model)
                    }
            }
            .background(KeptoraSidebarBackdrop())
            .navigationSplitViewColumnWidth(min: 184, ideal: 208, max: 232)
            .sheet(isPresented: $model.isShowingOnboarding) {
                OnboardingView().environmentObject(model)
            }
        } detail: {
            ZStack {
                KeptoraBackdrop()
                routeDetail
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                if isDropTargeted {
                    ZStack {
                        Color.accentColor.opacity(0.08)
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10]))
                            .padding(14)
                        VStack(spacing: 10) {
                            Image(systemName: "arrow.down.doc.fill")
                                .font(.system(size: 46))
                                .foregroundColor(.accentColor)
                            Text("Drop Folder to Connect & Scan")
                                .font(.headline.weight(.bold))
                                .foregroundColor(.primary)
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
                            model.connectFolderURL(url)
                            model.selectedRoute = .home
                        }
                    }
                }
                return true
            }
            .toolbar { utilityToolbar }
            .sheet(isPresented: $model.isShowingSafetyPlan) {
                SafetyPlanSheet()
                    .environmentObject(model)
                    .environmentObject(store)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("keptora.root")
        .sheet(isPresented: $store.isShowingPaywall) {
            PaywallView().environmentObject(store)
        }
        .onAppear {
            if model.selectedRoute == nil { model.selectedRoute = .home }
            if ProcessInfo.processInfo.arguments.contains("-keptoraScreenshotReconciliation") {
                model.selectedRoute = .review
            }
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active { model.checkpointReviewSession() }
        }
        .alert("Something went wrong", isPresented: $model.isShowingError) {
            Button("Copy Diagnostics") { model.copyDiagnostics() }
            Button("Export Diagnostics…") { model.exportDiagnostics() }
            Button("OK", role: .cancel) { }
        } message: {
            Text(model.errorMessage ?? "An unknown error occurred.")
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
            }
            Spacer()
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
        let isSelected = (model.selectedRoute ?? .home) == route
        let isHovered  = hoveredRoute == route
        return Button {
            withAnimation(KeptoraDesign.animFast) { model.selectedRoute = route }
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
                .animation(KeptoraDesign.animFast, value: isSelected)
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
            .animation(KeptoraDesign.animFast, value: isHovered)
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

    @ToolbarContentBuilder
    private var utilityToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                model.selectedRoute = .insights
            } label: {
                Label("Insights", systemImage: "chart.bar.xaxis")
            }
            .help("Review insights")
            .accessibilityIdentifier("mac.toolbar.insights")

            Button {
                model.selectedRoute = .diagnostics
            } label: {
                Label("Support", systemImage: "questionmark.circle")
            }
            .help("Support and diagnostics")
            .accessibilityIdentifier("mac.toolbar.support")

            Button {
                model.selectedRoute = .settings
            } label: {
                Label("Settings", systemImage: "gearshape")
            }
            .help("Keptora settings")
            .accessibilityIdentifier("mac.toolbar.settings")
        }
    }

    @ViewBuilder
    private var routeDetail: some View {
        switch model.selectedRoute ?? .home {
        case .home:         HomeView()
        case .review:       ReviewStudioView()
        case .smartBuckets: SmartBucketsDashboardView()
        case .insights:     ReviewInsightsView()
        case .history:      HistoryView()
        case .diagnostics:  DiagnosticsView()
        case .settings:     SettingsView()
        }
    }
}
