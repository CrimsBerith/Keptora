import AppKit
import SwiftUI

private enum ReviewStudioMode: String, CaseIterable, Identifiable {
    case exact = "Exact"
    case similar = "Similar"
    var id: String { rawValue }
}

private enum SimilarityReviewLayout: String, CaseIterable, Identifiable {
    case compare = "Compare"
    case cards = "Cards"
    var id: String { rawValue }
}

private enum ExactGroupFilter: String, CaseIterable, Identifiable {
    case all = "All"
    case unreviewed = "Unreviewed"
    case inProgress = "In Progress"
    case planned = "Planned"
    case reviewed = "Reviewed"

    var id: String { rawValue }
}

private enum ExactGroupSort: String, CaseIterable, Identifiable {
    case recovery = "Recovery"
    case copies = "Copies"
    case name = "Name"

    var id: String { rawValue }
}

struct ReviewStudioView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController
    @State private var mode: ReviewStudioMode = .exact
    @State private var similarityLayout: SimilarityReviewLayout = .compare
    @State private var comparisonMemberID: String?
    @State private var comparisonScale: CGFloat = 1
    @State private var comparisonOffset: CGSize = .zero
    @State private var exactFilter: ExactGroupFilter = .all
    @State private var exactSort: ExactGroupSort = .recovery
    @State private var exactSearch = ""
    @State private var showDecisionEvidence = false
    @State private var isQueuePresented = false
    @State private var isEvidencePresented = false
    @State private var showDecisionReconciliation = false
    @State private var showGlobalSelectConfirmation = false
    @State private var isShowingSwipeCulling = false

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                reviewCommandDeck
                Divider()
                reviewCanvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .background(KeptoraDesign.reviewFloor)
            .safeAreaInset(edge: .bottom) {
                decisionShelf
            }
        }
        .overlay(alignment: .leading) {
            if isQueuePresented {
                drawerSurface(title: mode == .exact ? "Exact Review Queue" : "Similarity Queue", systemImage: "rectangle.stack") {
                    groupSidebar
                }
                .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .overlay(alignment: .trailing) {
            if isEvidencePresented {
                drawerSurface(title: mode == .exact ? "Exact Evidence" : "Similarity Evidence", systemImage: "doc.text.magnifyingglass") {
                    inspector
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .background(KeptoraDesign.canvas)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("keptora.review.floor")
        .onChange(of: model.selectedSimilarityGroupID) { _ in
            comparisonMemberID = nil
            resetComparisonViewport()
        }
        .onAppear {
            model.setReviewModeExact(mode == .exact)
            model.ensureReviewFocus()
            model.checkpointReviewSession()
            if ProcessInfo.processInfo.arguments.contains("-keptoraScreenshotReconciliation") {
                showDecisionReconciliation = true
            }
        }
        .onChange(of: mode) { newMode in
            model.setReviewModeExact(newMode == .exact)
            isQueuePresented = false
            isEvidencePresented = false
        }
        .onChange(of: model.selectedGroupID) { _ in
            model.ensureReviewFocus()
            model.checkpointReviewSession()
        }
        .sheet(isPresented: $showDecisionReconciliation) { QuarantineDecisionReconciliationView(model: model) }
        .sheet(isPresented: $showDecisionEvidence) {
            DecisionEvidenceSheet(
                asset: model.selectedReviewAsset,
                evidence: model.selectedDecisionEvidence
            )
        }
        .sheet(isPresented: $isShowingSwipeCulling) {
            let cards: [SwipeCardItem] = model.duplicateGroups.flatMap { group in
                group.assets.map { asset in
                    SwipeCardItem(
                        id: asset.id.rawValue,
                        fileURL: asset.fileURL,
                        displayName: asset.displayName,
                        byteCount: asset.byteCount,
                        badgeLabel: asset.id == group.canonicalAssetID ? "Keeper" : "Copy",
                        badgeColor: asset.id == group.canonicalAssetID ? .green : .orange
                    )
                }
            }
            SwipeCullingStudioView(
                state: SwipeCullingState(items: cards),
                onCommitPlan: { cleanupItems in
                    for item in cleanupItems {
                        let assetID = AssetID(rawValue: item.id)
                        model.setDecision(.quarantinePlan, for: assetID, access: store)
                    }
                    isShowingSwipeCulling = false
                    model.isShowingSafetyPlan = true
                },
                onClose: { isShowingSwipeCulling = false }
            )
        }
        .alert("Select all safe copies?", isPresented: $showGlobalSelectConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Add to Safety Plan") {
                model.applyBatchActionToAllExactGroups(.planSafeExtras, access: store)
            }
            .accessibilityIdentifier("mac.folder.exact.confirmSelectAll")
        } message: {
            Text("This will add \(model.allSafeCopyCount.formatted()) copies totaling \(ByteCountFormatter.string(fromByteCount: model.allSafeCopyBytes, countStyle: .file)) from every exact group. Protected keepers stay untouched, and nothing moves until you confirm the Safety Plan.")
        }
    }

    private var reviewCommandDeck: some View {
        HStack(spacing: 12) {
            // Mode Picker
            Picker("Review mode", selection: $mode) {
                ForEach(ReviewStudioMode.allCases) { item in Text(LocalizedStringKey(item.rawValue)).tag(item) }
            }
            .pickerStyle(.segmented)
            .frame(width: 175)

            Divider().frame(height: 20)

            // Direct Group / Set Navigator
            if mode == .exact && !model.duplicateGroups.isEmpty {
                HStack(spacing: 5) {
                    Button {
                        model.selectPreviousExactGroup()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .keyboardShortcut("[", modifiers: [])
                    .disabled(model.currentExactGroupIndex <= 0)
                    .help("Previous duplicate set ( [ )")

                    Text(model.exactGroupPositionLabel)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06), in: Capsule())

                    Button {
                        model.selectNextExactGroup()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .keyboardShortcut("]", modifiers: [])
                    .disabled(model.currentExactGroupIndex >= model.duplicateGroups.count - 1)
                    .help("Next duplicate set ( ] )")
                }
            } else if mode == .similar && !model.similarityGroups.isEmpty {
                HStack(spacing: 5) {
                    Button {
                        model.selectPreviousSimilarityGroup()
                    } label: {
                        Image(systemName: "chevron.left")
                    }
                    .disabled(model.currentSimilarityGroupIndex <= 0)
                    .help("Previous similar group")

                    Text(model.similarityGroupPositionLabel)
                        .font(.system(.caption, design: .rounded).weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.primary.opacity(0.06), in: Capsule())

                    Button {
                        model.selectNextSimilarityGroup()
                    } label: {
                        Image(systemName: "chevron.right")
                    }
                    .disabled(model.currentSimilarityGroupIndex >= model.similarityGroups.count - 1)
                    .help("Next similar group")
                }
            }

            // Queue Drawer Toggle
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isEvidencePresented = false
                    isQueuePresented.toggle()
                }
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "rectangle.stack")
                    Text(mode == .exact ? "Queue (\(model.duplicateGroups.count))" : "Queue (\(model.similarityGroups.count))")
                }
            }
            .buttonStyle(.bordered)
            .background(isQueuePresented ? KeptoraDesign.accent.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .help("Toggle full review queue sidebar")
            .accessibilityIdentifier("mac.review.queue.open")

            Spacer()

            // Exact Mode Quick Actions
            if mode == .exact {
                if model.plannedBytes > 0 {
                    HStack(spacing: 6) {
                        Label(ByteCountFormatter.string(fromByteCount: model.plannedBytes, countStyle: .file), systemImage: "shippingbox.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(KeptoraDesign.accent)

                        Button("Clear") {
                            model.applyBatchActionToAllExactGroups(.skipExtras, access: store)
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .help("Clear all planned selections")
                        .accessibilityIdentifier("mac.folder.exact.clearSelection")
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(KeptoraDesign.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                }

                Button {
                    isShowingSwipeCulling = true
                } label: {
                    Label("Swipe & Cull", systemImage: "hand.draw.fill")
                }
                .buttonStyle(.bordered)
                .help("Fast card swipe review: Swipe Right to Keep, Swipe Left to Clean")

                Button {
                    showGlobalSelectConfirmation = true
                } label: {
                    Label("Select All Safe Copies", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!model.canApplyAllExactGroups)
                .help("Add every non-keeper duplicate across all sets to the Safety Plan")
                .accessibilityIdentifier("mac.folder.exact.selectAll")
            } else {
                Label("\(model.similarityGroups.count) groups", systemImage: "sparkles.rectangle.stack")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Divider().frame(height: 20)

            // Evidence Drawer Toggle
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isQueuePresented = false
                    isEvidencePresented.toggle()
                }
            } label: {
                Label("Evidence", systemImage: "doc.text.magnifyingglass")
            }
            .buttonStyle(.bordered)
            .background(isEvidencePresented ? KeptoraDesign.accent.opacity(0.15) : Color.clear, in: RoundedRectangle(cornerRadius: 7, style: .continuous))
            .disabled(mode == .exact ? model.selectedGroup == nil : model.selectedSimilarityGroup == nil)
            .help("Toggle evidence and metadata inspector")

            // Secondary Tools Menu
            Menu {
                Button {
                    showDecisionReconciliation = true
                } label: {
                    Label("Quarantine Reconciliation…", systemImage: "arrow.triangle.2.circlepath")
                }
                .accessibilityIdentifier("mac.review.reconciliation.open")

                Button {
                    model.selectedRoute = .insights
                } label: {
                    Label("Review Insights…", systemImage: "chart.bar.xaxis")
                }

                Button {
                    model.selectedRoute = .diagnostics
                } label: {
                    Label("Diagnostics Snapshot…", systemImage: "stethoscope")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .accessibilityIdentifier("mac.review.more")
        }
        .controlSize(.small)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Rectangle().fill(KeptoraDesign.accent.opacity(0.18)).frame(height: 1) }
    }

    @ViewBuilder
    private var decisionShelf: some View {
        if mode == .exact {
            exactDecisionShelf
        } else {
            similarDecisionShelf
        }
    }

    private var exactDecisionShelf: some View {
        HStack(spacing: 12) {
            if let asset = model.selectedReviewAsset {
                VStack(alignment: .leading, spacing: 2) {
                    Text(asset.displayName)
                        .font(.callout.weight(.semibold))
                        .lineLimit(1)
                    Text(model.selectedDecisionEvidence?.proofState.label ?? "Select a decision")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(minWidth: 180, maxWidth: 280, alignment: .leading)
            } else {
                Text("Select an exact copy to review")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 180, alignment: .leading)
            }

            Divider().frame(height: 30)

            Button { model.focusPreviousReviewAsset() } label: { Image(systemName: "chevron.left") }
                .help("Previous photo · Option-Left Arrow")
                .disabled(!model.canApplyFocusedReviewDecision)

            decisionShelfButton(.keep, title: "Keep", systemImage: "checkmark.shield")
            decisionShelfButton(.quarantinePlan, title: "Add to Plan", systemImage: "shippingbox")
            decisionShelfButton(.skip, title: "Skip", systemImage: "forward")

            Button { model.focusNextReviewAsset() } label: { Image(systemName: "chevron.right") }
                .help("Next photo · Option-Right Arrow")
                .disabled(!model.canApplyFocusedReviewDecision)

            Divider().frame(height: 30)

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(model.plannedAssets.count) planned")
                    .font(.caption.weight(.semibold))
                Text(ByteCountFormatter.string(fromByteCount: model.plannedBytes, countStyle: .file))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            Button {
                model.prepareSafetyPlan(access: store)
            } label: {
                Label("Safety Plan", systemImage: "list.clipboard")
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.plannedAssets.isEmpty || model.isCommittingCleanup)
            .accessibilityIdentifier("mac.safetyPlan.open")
        }
        .controlSize(.small)
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
            .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Decision Shelf")
    }

    private var similarDecisionShelf: some View {
        HStack(spacing: 12) {
            Label("Review-only similarity", systemImage: "hand.raised.fill")
                .font(.callout.weight(.semibold))
            Text("Similarity results are for comparison only.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            if model.similarityProgress.isRunning {
                ProgressView()
                    .controlSize(.small)
                Text(model.similarityProgress.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            } else {
                Button("Refresh Similarity") { model.startSimilarityAnalysis() }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
    }

    @ViewBuilder
    private func decisionShelfButton(_ decision: ReviewDecision, title: String, systemImage: String) -> some View {
        let selected = model.selectedReviewAsset.flatMap { model.decisions[$0.id] } == decision
        if selected {
            Button {
                model.applyFocusedDecision(decision, access: store)
            } label: {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!model.canApplyFocusedReviewDecision)
        } else {
            Button {
                model.applyFocusedDecision(decision, access: store)
            } label: {
                Label(title, systemImage: systemImage)
            }
            .buttonStyle(.bordered)
            .disabled(!model.canApplyFocusedReviewDecision)
        }
    }

    private func drawerSurface<Content: View>(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Label(title, systemImage: systemImage)
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        if isQueuePresented { isQueuePresented = false }
                        if isEvidencePresented { isEvidencePresented = false }
                    }
                } label: {
                    Image(systemName: "xmark")
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Close drawer")
                .accessibilityIdentifier("mac.review.drawer.close")
            }
            .padding(14)
            Divider()
            content()
        }
        .frame(width: 342)
        .frame(maxHeight: .infinity)
        .background(KeptoraDesign.drawerSurface)
        .overlay {
            Rectangle().strokeBorder(.primary.opacity(0.10))
        }
        .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 8)
        .padding(.vertical, 8)
    }

    private var groupSidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Review mode", selection: $mode) {
                    ForEach(ReviewStudioMode.allCases) { item in Text(LocalizedStringKey(item.rawValue)).tag(item) }
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 5) {
                    Text(mode == .exact ? "Exact duplicates" : "Similar photos")
                        .font(.headline)
                    Text(mode == .exact
                         ? "\(model.duplicateGroups.count) groups · decisions persist"
                         : "\(model.similarityGroups.count) review-only groups · on device")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(16)

            if mode == .exact, !store.isLifetimeUnlocked {
                HStack(spacing: 8) {
                    Image(systemName: store.accessPolicy.freeReviewsRemaining > 0 ? "gauge.with.dots.needle.50percent" : "lock.fill")
                    Text(store.trialLabel)
                        .font(.caption.weight(.semibold))
                    Spacer()
                    Button("Unlock") { store.presentPaywall(.reviewLimit) }
                        .buttonStyle(.link)
                        .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                .foregroundStyle(store.accessPolicy.freeReviewsRemaining > 0 ? Color.secondary : Color.orange)
            }

            if mode == .exact {
                exactGroupList
            } else {
                similarGroupList
            }
        }
    }

    private var filteredExactGroups: [ReviewGroup] {
        let searched = model.duplicateGroups.filter { group in
            exactSearch.isEmpty || group.assets.contains {
                $0.displayName.localizedCaseInsensitiveContains(exactSearch) ||
                $0.fileURL.path.localizedCaseInsensitiveContains(exactSearch)
            }
        }
        let filtered = searched.filter { group in
            let state = model.progress(for: group).state
            switch exactFilter {
            case .all: return true
            case .unreviewed: return state == .unreviewed
            case .inProgress: return state == .inProgress
            case .planned: return state == .planned
            case .reviewed: return state == .complete
            }
        }
        return filtered.sorted { lhs, rhs in
            switch exactSort {
            case .recovery:
                return lhs.reclaimableBytes == rhs.reclaimableBytes
                    ? lhs.id < rhs.id
                    : lhs.reclaimableBytes > rhs.reclaimableBytes
            case .copies:
                return lhs.assets.count == rhs.assets.count
                    ? lhs.reclaimableBytes > rhs.reclaimableBytes
                    : lhs.assets.count > rhs.assets.count
            case .name:
                return (lhs.canonicalAsset?.displayName ?? lhs.id)
                    .localizedStandardCompare(rhs.canonicalAsset?.displayName ?? rhs.id) == .orderedAscending
            }
        }
    }

    private var exactGroupList: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                TextField("Search names or paths", text: $exactSearch)
                    .textFieldStyle(.roundedBorder)

                HStack(spacing: 8) {
                    Picker("Filter", selection: $exactFilter) {
                        ForEach(ExactGroupFilter.allCases) { item in Text(LocalizedStringKey(item.rawValue)).tag(item) }
                    }
                    .labelsHidden()

                    Picker("Sort", selection: $exactSort) {
                        ForEach(ExactGroupSort.allCases) { item in Text(LocalizedStringKey(item.rawValue)).tag(item) }
                    }
                    .labelsHidden()
                }

                HStack {
                    Text("\(filteredExactGroups.count) of \(model.duplicateGroups.count) groups")
                    Spacer()
                    if exactFilter != .all || !exactSearch.isEmpty {
                        Button("Clear") {
                            exactFilter = .all
                            exactSearch = ""
                        }
                        .buttonStyle(.link)
                        .controlSize(.small)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            List(filteredExactGroups, selection: $model.selectedGroupID) { group in
                let progress = model.progress(for: group)
                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 6) {
                        Text(group.title)
                            .font(.callout.weight(.medium))
                        Spacer()
                        Image(systemName: progress.state.systemImage)
                            .foregroundStyle(progress.state == .planned ? .orange : .secondary)
                    }
                    HStack {
                        Text(ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file))
                        Spacer()
                        Text(progress.state.label)
                        Text("\(progress.decided)/\(progress.totalExtras)")
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .tag(group.id)
            }
            .listStyle(.inset)
            .overlay {
                if filteredExactGroups.isEmpty {
                    KeptoraUnavailableView(
                        "No groups match",
                        systemImage: "line.3.horizontal.decrease.circle",
                        description: "Clear the review filter or search to see the full exact-duplicate queue."
                    )
                }
            }
        }
    }

    private var similarGroupList: some View {
        VStack(spacing: 0) {
            if model.similarityProgress.isRunning {
                VStack(alignment: .leading, spacing: 8) {
                    ProgressView(
                        value: Double(model.similarityProgress.processed),
                        total: Double(max(1, model.similarityProgress.total))
                    )
                    Text(model.similarityProgress.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Cancel", role: .cancel) { model.cancelSimilarityAnalysis() }
                        .controlSize(.small)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            } else {
                Button {
                    model.startSimilarityAnalysis()
                } label: {
                    Label(
                        model.similarityGroups.isEmpty ? "Analyze Similar Photos" : "Refresh Similarity Index",
                        systemImage: "sparkles.rectangle.stack"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }

            List(model.similarityGroups, selection: $model.selectedSimilarityGroupID) { group in
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.title)
                        .font(.callout.weight(.medium))
                    HStack {
                        Label(group.tier.label, systemImage: group.tier.systemImage)
                        Spacer()
                        Text(group.maximumDistance, format: .number.precision(.fractionLength(3)))
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                .tag(group.id)
            }
            .listStyle(.inset)
        }
    }

    @ViewBuilder
    private var reviewCanvas: some View {
        if mode == .exact {
            exactReviewCanvas
        } else {
            similarReviewCanvas
        }
    }

    @ViewBuilder
    private var exactReviewCanvas: some View {
        if let group = model.selectedGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.title)
                                .font(.title2.weight(.semibold))
                            Text("Protected keeper · reversible plan")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 8) {
                            Label("Exact", systemImage: "checkmark.seal.fill")
                                .font(.callout.weight(.semibold))
                                .foregroundStyle(.green)
                            HStack(spacing: 8) {
                                Button {
                                    model.applyBatchAction(.skipExtras, to: group.id, access: store)
                                } label: {
                                    Label("Skip This Group", systemImage: "forward.fill")
                                }
                                .buttonStyle(.bordered)
                                .keyboardShortcut("s", modifiers: [.command, .shift])
                                .help("Mark every non-keeper in this exact set as reviewed without adding it to the Safety Plan.")

                                Button {
                                    model.applyBatchAction(.planSafeExtras, to: group.id, access: store)
                                } label: {
                                    Label("Select All Safe Copies", systemImage: "checkmark.circle.fill")
                                }
                                .buttonStyle(.borderedProminent)
                                .keyboardShortcut("g", modifiers: [.command, .shift])
                                .help("Select every exact duplicate except the protected keeper and add them to the Safety Plan.")
                            }
                            .controlSize(.small)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 16)], spacing: 16) {
                        ForEach(group.assets) { asset in
                            ReviewAssetCard(
                                asset: asset,
                                decision: model.decisions[asset.id],
                                isCanonical: group.canonicalAssetID == asset.id,
                                isFocused: model.selectedReviewAssetID == asset.id,
                                groupAssets: group.assets,
                                onFocus: {
                                    model.selectedReviewAssetID = asset.id
                                    model.checkpointReviewSession()
                                }
                            ) { decision in
                                model.selectedReviewAssetID = asset.id
                                model.setDecision(decision, for: asset.id, access: store)
                            }
                        }
                    }
                }
                .padding(22)
            }
        } else {
            KeptoraUnavailableView(
                "No exact duplicate groups",
                systemImage: "square.on.square.dashed",
                description: "Choose a folder and run a read-only scan to begin.",
                actionTitle: "Choose Folder",
                action: {
                    model.selectedRoute = .home
                    model.chooseFolder()
                }
            )
        }
    }

    @ViewBuilder
    private var similarReviewCanvas: some View {
        if let group = model.selectedSimilarityGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(group.title)
                                .font(.title2.weight(.semibold))
                            Text("Review-only suggestions · no cleanup actions")
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Label(group.tier.label, systemImage: group.tier.systemImage)
                            .font(.callout.weight(.semibold))
                    }

                    Label(
                        "Keptora never adds similar photos to a Safety Plan automatically.",
                        systemImage: "hand.raised.fill"
                    )
                    .font(.callout.weight(.medium))
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))

                    HStack(spacing: 12) {
                        Picker("Similarity layout", selection: $similarityLayout) {
                            ForEach(SimilarityReviewLayout.allCases) { layout in Text(LocalizedStringKey(layout.rawValue)).tag(layout) }
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 260)
                        Spacer()
                        if similarityLayout == .compare {
                            Button("Reset View") { resetComparisonViewport() }
                                .keyboardShortcut("0", modifiers: [.command])
                                .help("Reset synchronized zoom and pan")
                        }
                    }
                    if similarityLayout == .compare {
                        similarityComparison(group)
                    } else {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 230), spacing: 16)], spacing: 16) {
                            ForEach(group.members) { member in
                                SimilarityAssetCard(
                                    member: member,
                                    isAnchor: member.asset.id == group.anchorAssetID,
                                    groupMembers: group.members,
                                    onReveal: { model.reveal(member.asset) }
                                )
                            }
                        }
                    }
                }
                .padding(22)
            }
        } else {
            KeptoraUnavailableView(
                "No similar-photo analysis yet",
                systemImage: "sparkles.rectangle.stack",
                description: "Build the local visual index to receive conservative, review-only suggestions.",
                actionTitle: "Analyze Similar Photos",
                action: { model.startSimilarityAnalysis() }
            )
            .disabled(model.similarityProgress.isRunning)
        }
    }

    @ViewBuilder
    private func similarityComparison(_ group: SimilarityReviewGroup) -> some View {
        let alternatives = group.members.filter { $0.asset.id != group.anchorAssetID }
        let selected = alternatives.first { $0.asset.id.rawValue == comparisonMemberID } ?? alternatives.first
        if let anchor = group.anchor, let selected {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Picker("Compare with", selection: Binding(get: { selected.asset.id.rawValue }, set: { comparisonMemberID = $0; resetComparisonViewport() })) {
                        ForEach(alternatives) { member in Text(member.asset.displayName).tag(member.asset.id.rawValue) }
                    }
                    .labelsHidden().frame(maxWidth: 360)
                    Spacer()
                    Label("Synchronized zoom & pan", systemImage: "arrow.left.and.right")
                        .font(.caption.weight(.semibold)).foregroundStyle(.secondary)
                }
                HStack(spacing: 12) {
                    SynchronizedComparisonPane(title: "Anchor", member: anchor, scale: $comparisonScale, offset: $comparisonOffset, onReveal: { model.reveal(anchor.asset) })
                    SynchronizedComparisonPane(title: selected.distanceToAnchor.formatted(.number.precision(.fractionLength(4))), member: selected, scale: $comparisonScale, offset: $comparisonOffset, onReveal: { model.reveal(selected.asset) })
                }
                .frame(minHeight: 430)
                HStack(spacing: 12) {
                    Button { comparisonScale = max(1, comparisonScale - 0.5) } label: { Label("Zoom Out", systemImage: "minus.magnifyingglass") }.keyboardShortcut("-", modifiers: [.command])
                    Button { comparisonScale = min(8, comparisonScale + 0.5) } label: { Label("Zoom In", systemImage: "plus.magnifyingglass") }.keyboardShortcut("+", modifiers: [.command])
                    Slider(value: $comparisonScale, in: 1...8, step: 0.1).accessibilityLabel("Comparison zoom")
                    Text("\(comparisonScale, format: .number.precision(.fractionLength(1)))×").font(.caption.monospacedDigit()).frame(width: 42, alignment: .trailing)
                }.controlSize(.small)
            }
        } else {
            KeptoraUnavailableView(
                "No comparison candidate",
                systemImage: "rectangle.split.2x1",
                description: "This group needs at least two members for synchronized comparison."
            )
        }
    }

    private func resetComparisonViewport() { comparisonScale = 1; comparisonOffset = .zero }

    @ViewBuilder
    private var inspector: some View {
        if mode == .exact {
            exactInspector
        } else {
            similarInspector
        }
    }

    @ViewBuilder
    private var exactInspector: some View {
        if let group = model.selectedGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Evidence")
                        .font(.headline)
                    InspectorRow(label: "Confidence", value: "Exact")
                    InspectorRow(label: "Algorithm", value: "SHA-256 v1")
                    InspectorRow(label: "Members", value: group.assets.count.formatted())
                    InspectorRow(label: "Recoverable", value: ByteCountFormatter.string(fromByteCount: group.reclaimableBytes, countStyle: .file))

                    let progress = model.progress(for: group)
                    Divider()
                    Label("Review progress", systemImage: progress.state.systemImage)
                        .font(.headline)
                    ProgressView(value: Double(progress.decided), total: Double(max(1, progress.totalExtras)))
                    InspectorRow(label: "Status", value: progress.state.label)
                    InspectorRow(label: "Planned", value: progress.planned.formatted())
                    InspectorRow(label: "Skipped", value: progress.skipped.formatted())
                    InspectorRow(label: "Remaining", value: progress.undecided.formatted())

                    if let keeper = group.canonicalAsset {
                        Divider()
                        Label("Protected keeper", systemImage: "lock.shield.fill")
                            .font(.headline)
                        Text(keeper.displayName)
                            .font(.callout.weight(.medium))
                        Text(group.assets.first?.id == keeper.id
                             ? "Default keeper: the oldest modified copy, then the shortest stable path. Choose Keep on another copy to override it."
                             : "You selected this copy as the keeper. Keptora blocks it from quarantine until you choose another keeper.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Button("Reveal Keeper in Finder") { model.reveal(keeper) }
                            .controlSize(.small)
                    }

                    Divider()
                    Text("Digest")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(group.digest)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)

                    if let evidence = model.selectedDecisionEvidence {
                        HStack(spacing: 8) {
                            Image(systemName: evidence.proofState.systemImage)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(evidence.proofState.label)
                                    .font(.callout.weight(.semibold))
                                Text(evidence.reasonLabel)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Decision Evidence…") { showDecisionEvidence = true }
                                .controlSize(.small)
                        }
                        .padding(10)
                        .background(KeptoraDesign.quiet, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                    } else if model.selectedReviewAsset != nil {
                        Button {
                            showDecisionEvidence = true
                        } label: {
                            Label("Decision Evidence…", systemImage: "doc.text.magnifyingglass")
                        }
                        .controlSize(.small)
                        .help("This asset has not been explicitly reviewed yet.")
                    }

                    Divider()
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Safety Plan", systemImage: "shippingbox")
                                .font(.headline)
                            Spacer()
                            Text(model.plannedAssets.count.formatted())
                                .font(.headline.monospacedDigit())
                        }
                        Text("\(ByteCountFormatter.string(fromByteCount: model.plannedBytes, countStyle: .file)) selected for reversible quarantine.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Button {
                            model.prepareSafetyPlan(access: store)
                        } label: {
                            Label("Review Safety Plan", systemImage: "list.clipboard")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(model.plannedAssets.isEmpty || model.isCommittingCleanup)
                    }
                }
                .padding(18)
            }
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var similarInspector: some View {
        if let group = model.selectedSimilarityGroup {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Similarity evidence")
                        .font(.headline)
                    InspectorRow(label: "Tier", value: group.tier.label)
                    InspectorRow(label: "Maximum distance", value: group.maximumDistance.formatted(.number.precision(.fractionLength(4))))
                    InspectorRow(label: "Members", value: group.members.count.formatted())
                    InspectorRow(label: "Vision revision", value: "1 (pinned)")
                    InspectorRow(label: "Crop policy", value: "Scale fit")
                    InspectorRow(label: "Calibration", value: group.isCalibrated ? "Local profile" : "Conservative bootstrap")

                    Divider()
                    Label("Review-only policy", systemImage: "hand.raised.square.fill")
                        .font(.headline)
                    Text("Feature-print distance is evidence of visual resemblance, not proof that two files are interchangeable. Similar groups have no Keep, Quarantine, or automatic cleanup action.")
                        .font(.callout)
                        .foregroundStyle(.secondary)

                    if let anchor = group.anchor {
                        Divider()
                        Text("Comparison anchor")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(anchor.asset.displayName)
                            .font(.callout.weight(.medium))
                        Button("Reveal in Finder") { model.reveal(anchor.asset) }
                    }

                    Divider()
                    Text("Profile")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(group.profileID)
                        .font(.system(.caption, design: .monospaced))
                        .textSelection(.enabled)
                }
                .padding(18)
            }
        } else {
            Color.clear
        }
    }
}

private struct ReviewAssetCard: View {
    let asset: ReviewAsset
    let decision: ReviewDecision?
    let isCanonical: Bool
    let isFocused: Bool
    var groupAssets: [ReviewAsset] = []
    let onFocus: () -> Void
    let onDecision: (ReviewDecision) -> Void

    @State private var isShowingViewer: Bool = false

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    LocalThumbnail(url: asset.fileURL, accessibilityName: asset.displayName)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            isShowingViewer = true
                        }
                    
                    HStack {
                        Button(action: { isShowingViewer = true }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .help("Open in Photo Viewer and swipe to cull")
                        
                        Spacer()
                    }

                    if isCanonical {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.shield.fill")
                            Text("Protected Keeper")
                        }
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(.ultraThinMaterial, in: Capsule())
                        .overlay { Capsule().stroke(Color.green.opacity(0.45), lineWidth: 1) }
                        .padding(8)
                    } else {
                        Button {
                            onDecision(decision == .quarantinePlan ? .skip : .quarantinePlan)
                        } label: {
                            HStack(spacing: 5) {
                                Image(systemName: decision == .quarantinePlan ? "checkmark.square.fill" : "square")
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(decision == .quarantinePlan ? Color.orange : Color.secondary)
                                if decision == .quarantinePlan {
                                    Text("Plan")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(Color.orange)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .stroke(decision == .quarantinePlan ? Color.orange.opacity(0.45) : Color.clear, lineWidth: 1)
                            }
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .accessibilityIdentifier("mac.folder.exact.checkbox.\(asset.id.rawValue)")
                    }
                }

                HStack(spacing: 8) {
                    Text(asset.displayName)
                        .font(.headline)
                        .lineLimit(1)
                        .help(asset.fileURL.path)
                    if let family = asset.family {
                        Label(family.kind.localizedLabel, systemImage: family.policy == .allOrNothing ? "link.badge.plus" : "square.stack.3d.up")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 4)
                            .background(.blue.opacity(0.10), in: Capsule())
                            .help("\(family.memberCount) linked components · \(family.role.rawValue)")
                    }
                }
                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: asset.byteCount, countStyle: .file))
                    Spacer()
                    Text(asset.modificationDate?.formatted(date: .abbreviated, time: .omitted) ?? "Unknown date")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    decisionButton(.keep, systemImage: "checkmark.shield")
                    decisionButton(.quarantinePlan, systemImage: "shippingbox")
                    decisionButton(.skip, systemImage: "forward")
                }
            }
        }
        .contentShape(ArchivePlateShape(cut: 10))
        .onTapGesture {
            onFocus()
            if !isCanonical {
                onDecision(decision == .quarantinePlan ? .skip : .quarantinePlan)
            }
        }
        .overlay {
            ArchivePlateShape(cut: 10)
                .stroke(
                    isFocused ? Color.accentColor : (decision == .quarantinePlan ? Color.orange.opacity(0.55) : Color.clear),
                    lineWidth: isFocused ? 2 : (decision == .quarantinePlan ? 1.5 : 0)
                )
                .allowsHitTesting(false)
        }
        .sheet(isPresented: $isShowingViewer) {
            let all = groupAssets.isEmpty ? [asset] : groupAssets
            let items = all.map {
                ViewerPhotoItem(
                    id: $0.id.rawValue,
                    fileURL: $0.fileURL,
                    displayName: $0.displayName,
                    byteCount: $0.byteCount
                )
            }
            let initialIdx = items.firstIndex(where: { $0.id == asset.id.rawValue }) ?? 0
            InteractivePhotoViewerView(
                state: PhotoViewerState(items: items, initialIndex: initialIdx),
                onCleanOrDelete: { item in
                    if item.id == asset.id.rawValue {
                        onDecision(.quarantinePlan)
                    }
                },
                onClose: { isShowingViewer = false }
            )
            .frame(minWidth: 920, minHeight: 660)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(isCanonical ? "mac.folder.exact.keeper.\(asset.id.rawValue)" : "mac.folder.exact.cardToggle.\(asset.id.rawValue)")
        .accessibilityAddTraits(isFocused ? .isSelected : [])
    }

    @ViewBuilder
    private func decisionButton(_ value: ReviewDecision, systemImage: String) -> some View {
        let selected = value == decision || (value == .keep && isCanonical)
        if selected {
            decisionButtonBase(value, systemImage: systemImage)
                .buttonStyle(.borderedProminent)
        } else {
            decisionButtonBase(value, systemImage: systemImage)
                .buttonStyle(.bordered)
        }
    }

    private func decisionButtonBase(_ value: ReviewDecision, systemImage: String) -> some View {
        Button { onDecision(value) } label: {
            Label(value.label, systemImage: systemImage)
                .frame(maxWidth: .infinity)
        }
        .controlSize(.small)
        .disabled(isCanonical && value != .keep)
        .help(isCanonical && value != .keep ? "Choose another keeper first." : value.label)
        .accessibilityIdentifier(value == .quarantinePlan && !isCanonical ? "mac.folder.exact.checkbox.\(asset.id.rawValue)" : "")
    }
}

private struct SimilarityAssetCard: View {
    let member: SimilarityReviewMember
    let isAnchor: Bool
    var groupMembers: [SimilarityReviewMember] = []
    let onReveal: () -> Void

    @State private var isShowingViewer: Bool = false

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                ZStack(alignment: .topTrailing) {
                    LocalThumbnail(url: member.asset.fileURL, accessibilityName: member.asset.displayName)
                        .frame(height: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .contentShape(Rectangle())
                        .onTapGesture(count: 2) {
                            isShowingViewer = true
                        }
                    
                    HStack {
                        Button(action: { isShowingViewer = true }) {
                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(6)
                                .background(.regularMaterial, in: Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(8)
                        .help("Open in Photo Viewer and swipe to cull")
                        
                        Spacer()
                    }

                    if isAnchor {
                        Label("Anchor", systemImage: "scope")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(.regularMaterial, in: Capsule())
                            .padding(8)
                    }
                }
                Text(member.asset.displayName)
                    .font(.headline)
                    .lineLimit(1)
                    .help(member.asset.fileURL.path)
                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: member.asset.byteCount, countStyle: .file))
                    Spacer()
                    Text(isAnchor ? "Reference" : member.distanceToAnchor.formatted(.number.precision(.fractionLength(4))))
                        .monospacedDigit()
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                Button(action: onReveal) {
                    Label("Reveal in Finder", systemImage: "folder")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .sheet(isPresented: $isShowingViewer) {
            let all = groupMembers.isEmpty ? [member] : groupMembers
            let items = all.map {
                ViewerPhotoItem(
                    id: $0.asset.id.rawValue,
                    fileURL: $0.asset.fileURL,
                    displayName: $0.asset.displayName,
                    byteCount: $0.asset.byteCount
                )
            }
            let initialIdx = items.firstIndex(where: { $0.id == member.asset.id.rawValue }) ?? 0
            InteractivePhotoViewerView(
                state: PhotoViewerState(items: items, initialIndex: initialIdx),
                onClose: { isShowingViewer = false }
            )
            .frame(minWidth: 920, minHeight: 660)
        }
    }
}

private struct SynchronizedComparisonPane: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController

    let title: String
    let member: SimilarityReviewMember
    @Binding var scale: CGFloat
    @Binding var offset: CGSize
    let onReveal: () -> Void
    @State private var image: NSImage?
    @State private var scaleOrigin: CGFloat = 1
    @State private var offsetOrigin: CGSize = .zero
    @State private var isShowingViewer: Bool = false

    var body: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.asset.displayName).font(.headline).lineLimit(1)
                        Text(title).font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: { isShowingViewer = true }) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                    }
                    .buttonStyle(.borderless)
                    .help("Open in Full-Screen Cinematic Photo Viewer")
                    .accessibilityLabel("Open \(member.asset.displayName) in Photo Viewer")

                    Button(action: onReveal) { Image(systemName: "folder") }.buttonStyle(.borderless).help("Reveal in Finder").accessibilityLabel("Reveal \(member.asset.displayName) in Finder")
                }
                GeometryReader { proxy in
                    ZStack {
                        Rectangle().fill(KeptoraDesign.quiet)
                        if let image {
                            Image(nsImage: image).resizable().scaledToFit().scaleEffect(scale).offset(offset).frame(width: proxy.size.width, height: proxy.size.height)
                        } else { ProgressView() }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .contentShape(Rectangle())
                    .gesture(SimultaneousGesture(
                        MagnificationGesture().onChanged { value in scale = min(8, max(1, scaleOrigin * value)) }.onEnded { _ in scaleOrigin = scale },
                        DragGesture().onChanged { value in offset = CGSize(width: offsetOrigin.width + value.translation.width, height: offsetOrigin.height + value.translation.height) }.onEnded { _ in offsetOrigin = offset }
                    ))
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Synchronized comparison preview of \(member.asset.displayName)")
                    .accessibilityValue("Zoom \(scale, format: .number.precision(.fractionLength(1))) times")
                }
                HStack {
                    Text(ByteCountFormatter.string(fromByteCount: member.asset.byteCount, countStyle: .file))
                    Spacer()
                    Text(member.asset.modificationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown date")
                }.font(.caption).foregroundStyle(.secondary)
            }
        }
        .task(id: member.asset.fileURL) { image = await BoundedThumbnailCache.shared.image(for: member.asset.fileURL, maxPixelSize: 1800) }
        .onChange(of: scale) { if $0 == 1 { scaleOrigin = 1 } }
        .onChange(of: offset) { if $0 == .zero { offsetOrigin = .zero } }
        .sheet(isPresented: $isShowingViewer) {
            InteractivePhotoViewerView(
                state: PhotoViewerState(
                    items: [
                        ViewerPhotoItem(
                            id: member.asset.id.rawValue,
                            fileURL: member.asset.fileURL,
                            displayName: member.asset.displayName,
                            byteCount: member.asset.byteCount
                        )
                    ]
                ),
                onCleanOrDelete: { item in
                    let assetID = AssetID(rawValue: item.id)
                    model.setDecision(.quarantinePlan, for: assetID, access: store)
                },
                onClose: { isShowingViewer = false }
            )
            .frame(minWidth: 920, minHeight: 660)
        }
    }
}

private struct LocalThumbnail: View {
    let url: URL
    let accessibilityName: String
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle().fill(KeptoraDesign.quiet)
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .scaledToFit()
                    .padding(8)
            } else {
                Image(systemName: "photo")
                    .font(.largeTitle)
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Preview of \(accessibilityName)")
        .task(id: url) { image = await BoundedThumbnailCache.shared.image(for: url, maxPixelSize: 420) }
    }
}

private struct DecisionEvidenceSheet: View {
    let asset: ReviewAsset?
    let evidence: ReviewDecisionEvidence?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(.blue.opacity(0.10))
                    Image(systemName: evidence?.proofState.systemImage ?? "doc.text.magnifyingglass")
                        .font(.system(size: 26))
                        .foregroundStyle(evidence?.proofState == .needsReview ? .orange : .blue)
                }
                .frame(width: 54, height: 54)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Decision Evidence")
                        .font(.title2.weight(.semibold))
                    Text(asset?.displayName ?? "No focused asset")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                Button("Done") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(22)

            Divider()

            if let asset, let evidence {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Label(evidence.proofState.label, systemImage: evidence.proofState.systemImage)
                            .font(.headline)
                        Text(evidence.proofState == .verifiedExactPlan
                             ? "This planned copy matches the exact-set SHA-256 digest and is not the protected keeper. Keptora will still re-hash it immediately before quarantine."
                             : evidence.proofState == .protectedKeeper || evidence.proofState == .selectedKeeper
                             ? "This copy is the protected keeper. Keptora blocks it from quarantine until another keeper is selected."
                             : evidence.proofState == .reviewedSkip
                             ? "This byte-identical copy was reviewed but intentionally left out of the Safety Plan."
                             : "The recorded decision cannot currently be proven from the selected exact-set state. Review it again before creating a Safety Plan.")
                            .font(.callout)
                            .foregroundStyle(.secondary)

                        GroupBox("Decision provenance") {
                            VStack(spacing: 9) {
                                evidenceRow("Action", evidence.decision.label)
                                evidenceRow("Reason", evidence.reasonLabel)
                                evidenceRow("Actor", evidence.actor == "user" ? "User" : "Keptora safety rule")
                                evidenceRow("Recorded", evidence.decidedAt.formatted(date: .abbreviated, time: .standard))
                            }
                            .padding(.vertical, 4)
                        }

                        GroupBox("Exact-copy proof") {
                            VStack(spacing: 9) {
                                evidenceRow("Algorithm", "SHA-256 v1")
                                evidenceRow("Keeper", evidence.canonicalAssetID.rawValue == asset.id.rawValue ? "This file" : "Separate protected copy")
                                evidenceRow("Bytes", ByteCountFormatter.string(fromByteCount: asset.byteCount, countStyle: .file))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Digest").font(.caption).foregroundStyle(.secondary)
                                    Text(evidence.exactDigest)
                                        .font(.system(.caption2, design: .monospaced))
                                        .textSelection(.enabled)
                                }
                            }
                            .padding(.vertical, 4)
                        }

                        if let familyKind = evidence.familyKind {
                            GroupBox("Linked asset family") {
                                VStack(spacing: 9) {
                                    evidenceRow("Family", familyKind)
                                    evidenceRow("Role", evidence.familyRole ?? "Unknown")
                                    Text("Family safety is checked again when the Safety Plan is prepared; all-or-nothing families are blocked if a move would separate required components.")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }

                        Label("Similarity suggestions never enter this evidence path and can never be auto-added to cleanup.", systemImage: "hand.raised.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(22)
                }
            } else {
                KeptoraUnavailableView(
                    "No recorded decision",
                    systemImage: "doc.text.magnifyingglass",
                    description: "Choose Keep, Add to Plan, or Skip for the focused exact copy. Keptora will record the reason and show its evidence here."
                )
                .padding(30)
            }
        }
        .frame(minWidth: 560, idealWidth: 620, minHeight: 520, idealHeight: 640)
    }

    private func evidenceRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.callout.weight(.medium))
                .multilineTextAlignment(.trailing)
        }
    }
}

private struct InspectorRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value).fontWeight(.medium)
        }
        .font(.callout)
    }
}

struct QuarantineDecisionReconciliationView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: AppModel
    private let store = QuarantineDecisionReconciliationStore()
    @State private var records: [QuarantineDecisionReconciliationRecord] = []
    @State private var planID = ""
    @State private var decision = ""
    @State private var manifest = ""
    @State private var verification = ""
    @State private var filesystem = ""
    @State private var restore = ""
    @State private var message: String?
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("QUARANTINE DECISION RECONCILIATION")
                    .font(.headline.monospaced())
                    .accessibilityIdentifier("keptora.reconciliation.title")
                Spacer()
                Text("WHY THIS CHANGED")
                    .font(.caption.bold())
                    .foregroundStyle(.orange)
                    .accessibilityIdentifier("keptora.reconciliation.subtitle")
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close Reconciliation")
                .accessibilityIdentifier("mac.reconciliation.close")
            }.padding(16).background(KeptoraDesign.elevated)
            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    TextField("Plan ID", text: $planID); TextField("Decision fingerprint", text: $decision); TextField("Manifest fingerprint", text: $manifest); TextField("Verification fingerprint", text: $verification); TextField("Filesystem fingerprint", text: $filesystem); TextField("Restore fingerprint (optional)", text: $restore)
                    Button("Load Current Safety Plan") { loadCurrentSafetyPlan() }.buttonStyle(.bordered)
                    Button("Reconcile Snapshot") { reconcile() }.buttonStyle(.borderedProminent).disabled([planID,decision,manifest,verification,filesystem].contains(where: \.isEmpty))
                    if let message { Text(message).font(.caption).foregroundStyle(.secondary) }
                }.textFieldStyle(.roundedBorder).frame(width: 360)
                ScrollView { LazyVStack(alignment: .leading, spacing: 8) { ForEach(records.reversed()) { r in VStack(alignment: .leading, spacing: 4) { HStack { Text("R\(r.revisionNumber)").font(.caption.monospaced().bold()); Spacer(); Text(r.state.localizedLabel).font(.caption.bold()) }; Text(r.snapshot.planID).font(.caption); ForEach(r.reasons,id:\.self) { Text("• \($0)").font(.caption2) } }.padding(10).background(KeptoraDesign.elevated, in: RoundedRectangle(cornerRadius: 8)) } } }.frame(maxWidth: .infinity)
            }.padding(18)
        }.frame(minWidth: 780, minHeight: 500).background(KeptoraDesign.reviewFloor).onAppear { records = store.load() }
    }
    private func loadCurrentSafetyPlan() {
        guard let plan = model.pendingPlan else {
            message = "Prepare a cleanup safety plan first."
            return
        }
        let latest = model.latestQuarantineVerification(for: plan.id)
        planID = plan.id
        decision = plan.decisionSnapshotFingerprint ?? "decision-unavailable"
        manifest = latest?.manifestFingerprint ?? "pending-manifest:\(plan.id)"
        verification = latest?.reportFingerprint ?? "verification-not-run"
        if let latest {
            filesystem = "\(latest.state.rawValue)|verified=\(latest.verifiedCount)|issues=\(latest.issueCount)|\(latest.reportFingerprint)"
            restore = latest.phase.rawValue.lowercased().contains("restore") ? latest.reportFingerprint : ""
        } else {
            filesystem = model.safetyPlanFreshness?.currentFingerprint ?? decision
            restore = ""
        }
        message = "Current safety-plan state loaded."
    }

    private func reconcile() {
        let snapshot = QuarantineDecisionSnapshot(planID: planID, decisionFingerprint: decision, manifestFingerprint: manifest, verificationFingerprint: verification, filesystemFingerprint: filesystem, restoreFingerprint: restore.isEmpty ? nil : restore)
        let r = KeptoraPhase6DecisionCore.makeRecord(snapshot: snapshot, history: records)
        var next=records; next.append(r); do { try store.save(next); records=next; message="Snapshot persisted locally." } catch { message=error.localizedDescription }
    }
}
