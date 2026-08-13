import SwiftUI

struct MainRootView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController

    var body: some View {
        VStack(spacing: 0) {
            appToolbar
            Divider()
            routeDetail
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(CulloraDesign.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("cullora.root")
        .sheet(isPresented: $model.isShowingOnboarding) {
            OnboardingView()
                .environmentObject(model)
        }
        .sheet(isPresented: $model.isShowingSafetyPlan) {
            SafetyPlanSheet()
                .environmentObject(model)
                .environmentObject(store)
        }
        .sheet(isPresented: $model.isShowingRestorePreview) {
            RestorePreviewSheet()
                .environmentObject(model)
        }
        .sheet(isPresented: $store.isShowingPaywall) {
            PaywallView()
                .environmentObject(store)
        }
        .onAppear {
            if ProcessInfo.processInfo.arguments.contains("-culloraScreenshotReconciliation") {
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

    // MARK: - Toolbar

    private var appToolbar: some View {
        HStack(spacing: 16) {
            // App brand mark
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(CulloraDesign.iconGradient)
                        .frame(width: 34, height: 34)
                        .shadow(color: CulloraDesign.accentGlow, radius: 6, y: 2)
                    Image(systemName: "photo.stack.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("CULLORA")
                    .font(.system(.headline, design: .rounded).weight(.bold))
                    .tracking(1.2)
            }

            // Navigation tickets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 7) {
                    ForEach(SidebarRoute.allCases) { route in
                        WorkspaceTicket(
                            route: route,
                            isSelected: (model.selectedRoute ?? .home) == route,
                            action: { model.selectedRoute = route }
                        )
                    }
                }
                .padding(.vertical, 2)
            }

            Spacer(minLength: 8)

            // Pro badge / upgrade button
            if store.isLifetimeUnlocked {
                HStack(spacing: 5) {
                    Circle()
                        .fill(CulloraDesign.success)
                        .frame(width: 7, height: 7)
                    Text("Pro")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(CulloraDesign.success)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(CulloraDesign.success.opacity(0.10),
                            in: Capsule())
            } else {
                Button("Unlock Pro") { store.presentPaywall(.settings) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(CulloraDesign.accent)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(CulloraDesign.accentBorder)
                .frame(height: 1)
        }
    }

    // MARK: - Route Detail

    @ViewBuilder
    private var routeDetail: some View {
        switch model.selectedRoute ?? .home {
        case .home:        HomeView()
        case .review:      ReviewStudioView()
        case .insights:    ReviewInsightsView()
        case .history:     HistoryView()
        case .diagnostics: DiagnosticsView()
        case .settings:    SettingsView()
        }
    }
}

// MARK: - WorkspaceTicket

private struct WorkspaceTicket: View {
    let route: SidebarRoute
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: route.systemImage)
                    .font(.caption.weight(.semibold))
                Text(route.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
            }
            .padding(.horizontal, 11)
            .padding(.vertical, 7)
            .background(
                isSelected ? CulloraDesign.ticketSelected : CulloraDesign.ticketIdle,
                in: TicketShape(cut: 5)
            )
            .overlay {
                TicketShape(cut: 5)
                    .strokeBorder(
                        isSelected
                            ? CulloraDesign.accent.opacity(0.35)
                            : Color.primary.opacity(0.08)
                    )
            }
            .scaleEffect(isSelected ? 1.03 : 1.0)
            .shadow(
                color: isSelected ? CulloraDesign.accentGlow : .clear,
                radius: isSelected ? 6 : 0,
                y: 2
            )
            .animation(CulloraDesign.animFast, value: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - TicketShape

private struct TicketShape: InsettableShape {
    var cut: CGFloat
    var insetAmount: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: insetAmount, dy: insetAmount)
        let c = min(cut, min(r.width, r.height) / 3)
        var path = Path()
        path.move(to: CGPoint(x: r.minX + c, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.minY))
        path.addLine(to: CGPoint(x: r.maxX, y: r.minY + c))
        path.addLine(to: CGPoint(x: r.maxX, y: r.maxY - c))
        path.addLine(to: CGPoint(x: r.maxX - c, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX + c, y: r.maxY))
        path.addLine(to: CGPoint(x: r.minX, y: r.maxY - c))
        path.addLine(to: CGPoint(x: r.minX, y: r.minY + c))
        path.closeSubpath()
        return path
    }

    func inset(by amount: CGFloat) -> TicketShape {
        var copy = self
        copy.insetAmount += amount
        return copy
    }
}
