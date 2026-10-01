import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController
    @State private var showPhotosLibrary = false
    @State private var showRescanConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                sourceCard
                scanStatus
                scanSummaryCard
                workflowStrip
                recoveryCard
                reviewResumeCard
                accessCard
                metrics
            }
            .padding(KeptoraDesign.pagePadding)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .background(KeptoraDesign.canvas)
        .navigationTitle("Home")
        .accessibilityIdentifier("mac.page.library")
        .sheet(isPresented: $showPhotosLibrary) {
            MacPhotosLibraryView()
                .environmentObject(store)
        }
    }

    private var header: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 18) {
                headerCopy
                Spacer()
                headerStatus
            }
            VStack(alignment: .leading, spacing: 14) {
                headerCopy
                headerStatus
            }
        }
    }

    private var sourceCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(KeptoraDesign.accent.opacity(0.12))
                        Image(systemName: "folder.badge.gearshape")
                            .font(.system(size: 28))
                            .foregroundStyle(KeptoraDesign.accent)
                    }
                    .frame(width: 58, height: 58)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Source library")
                            .font(.headline)
                        Text(model.sourceName)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Label(model.sourceAvailability.label, systemImage: model.sourceAvailability.isAvailable ? "externaldrive.badge.checkmark" : "externaldrive.badge.exclamationmark")
                            .font(.caption)
                            .foregroundStyle(model.sourceAvailability.isAvailable ? KeptoraDesign.success : KeptoraDesign.warning)
                    }
                    Spacer()
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 10) {
                        sourceActions
                        Spacer()
                        scanButton
                    }
                    VStack(alignment: .leading, spacing: 10) {
                        sourceActions
                        scanButton
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var scanSummaryCard: some View {
        if let outcome = model.lastScanOutcome, model.scanProgress.phase == .completed {
            PremiumCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Scan complete")
                                .font(.headline)
                            if outcome.groups.isEmpty {
                                Text("No exact duplicates found.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            } else {
                                Text("Ready to review — \(outcome.groups.count.formatted()) duplicate sets found.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        if outcome.groups.isEmpty {
                            Button("Choose Another Folder") {
                                model.chooseFolder()
                            }
                            .buttonStyle(.borderedProminent)
                        } else {
                            Button("Review Duplicates") {
                                model.selectedRoute = .review
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }

                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 10)], spacing: 10) {
                        scanResultMetric("Files scanned", value: outcome.discovered.formatted(), image: "photo.stack")
                        scanResultMetric("Exact groups", value: outcome.groups.count.formatted(), image: "square.on.square")
                        scanResultMetric("Potential recovery", value: ByteCountFormatter.string(fromByteCount: outcome.groups.reduce(0) { $0 + $1.reclaimableBytes }, countStyle: .file), image: "internaldrive")
                    }
                }
            }
        }
    }

    private func scanResultMetric(_ title: String, value: String, image: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: image)
                .foregroundStyle(KeptoraDesign.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.headline.monospacedDigit())
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(KeptoraDesign.quiet, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var workflowStrip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 250), spacing: 14)], spacing: 14) {
            workflowStep(
                title: "Exact Match",
                value: "SHA-256",
                detail: "SHA-256 verified",
                systemImage: "checkmark.seal.fill",
                color: KeptoraDesign.success
            )
            workflowStep(
                title: "Similar Photos",
                value: "\(model.similarityGroups.count.formatted()) groups",
                detail: "Advisory only, no auto-delete",
                systemImage: "sparkles.rectangle.stack",
                color: KeptoraDesign.accent
            )
            workflowStep(
                title: "Cleanup Plan",
                value: ByteCountFormatter.string(fromByteCount: model.plannedBytes, countStyle: .file),
                detail: "Reversible, signed manifest",
                systemImage: "list.clipboard.fill",
                color: KeptoraDesign.warning
            )
        }
    }

    @ViewBuilder
    private var recoveryCard: some View {
        if !model.recoveryIssues.isEmpty {
            PremiumCard {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label("Recovery reconciliation", systemImage: "arrow.triangle.2.circlepath.circle.fill")
                            .font(.headline)
                        Spacer()
                        Text(model.recoveryIssues.count.formatted())
                            .font(.headline.monospacedDigit())
                    }
                    ForEach(model.recoveryIssues.prefix(3)) { issue in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: issue.needsUserAttention ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                                .foregroundStyle(issue.needsUserAttention ? .orange : .green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(issue.title).font(.callout.weight(.semibold))
                                Text(issue.detail).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }


    @ViewBuilder
    private var reviewResumeCard: some View {
        if let checkpoint = model.reviewSessionCheckpoint, model.hasResumableReviewSession {
            PremiumCard {
                HStack(spacing: 14) {
                    Image(systemName: "bookmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Resume exact-duplicate review")
                            .font(.headline)
                        Text("\(checkpoint.positionLabel) · \(checkpoint.reviewedAssets) decisions · \(ByteCountFormatter.string(fromByteCount: checkpoint.plannedBytes, countStyle: .file)) planned")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("Saved locally \(checkpoint.updatedAt.formatted(date: .abbreviated, time: .shortened)).")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    Spacer()
                    Button("Dismiss") { model.dismissReviewSession() }
                        .buttonStyle(.bordered)
                    Button("Resume") { model.resumeReviewSession() }
                        .buttonStyle(.borderedProminent)
                }
            }
        }
    }


    @ViewBuilder
    private var accessCard: some View {
        if !store.isLifetimeUnlocked {
            PremiumCard {
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(KeptoraDesign.accentSubtle)
                        Image(systemName: "sparkles")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(KeptoraDesign.accent)
                    }
                    .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Try Keptora Pro")
                            .font(.headline)
                        Text("Unlimited reviews · Reversible cleanup · No subscription")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 8) {
                        Text(store.trialLabel)
                            .font(.caption.weight(.semibold))
                        Button("View Keptora Pro") { store.presentPaywall(.settings) }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            .tint(KeptoraDesign.accent)
                    }
                }
            }
        }
    }

    private var metrics: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
            MetricTile(title: "Active Assets", value: model.databaseSummary.activeAssets.formatted(), systemImage: "photo.stack")
            MetricTile(title: "Exact Groups", value: model.databaseSummary.duplicateGroups.formatted(), systemImage: "square.on.square")
            MetricTile(title: "Space to Reclaim", value: ByteCountFormatter.string(fromByteCount: model.databaseSummary.reclaimableBytes, countStyle: .file), systemImage: "internaldrive")
            MetricTile(title: "Recoverable", value: model.databaseSummary.quarantinedAssets.formatted(), systemImage: "arrow.uturn.backward.circle")
                .help("Files safely moved to recovery bin — restorable at any time")
            MetricTile(title: "Total Indexed", value: model.databaseSummary.indexedAssets.formatted(), systemImage: "externaldrive.badge.checkmark")
        }
    }

    private var headerCopy: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Free up space. Keep what matters.")
                .font(KeptoraDesign.titleFont)
            Text("Finds exact duplicates with byte-level proof. Review, then clean up — reversibly.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 760, alignment: .leading)
        }
    }

    private var headerStatus: some View {
        Label(store.isLifetimeUnlocked ? "Lifetime unlocked" : store.trialLabel, systemImage: store.isLifetimeUnlocked ? "checkmark.seal.fill" : "gauge.with.dots.needle.50percent")
            .font(.callout.weight(.semibold))
            .foregroundStyle(store.isLifetimeUnlocked ? KeptoraDesign.success : KeptoraDesign.accent)
    }

    private var sourceActions: some View {
        HStack(spacing: 10) {
            Button { model.chooseFolder() } label: {
                Label("Choose Folder", systemImage: "folder")
            }
            .accessibilityIdentifier("mac.library.chooseFolder")
            Button { model.chooseCloudFolder() } label: {
                Label("Cloud Folder", systemImage: "cloud.fill")
            }
            .buttonStyle(.bordered)
            .help("Choose an iCloud Drive or Finder-connected cloud provider folder")
            .accessibilityIdentifier("mac.library.cloudFolder")
            Button { showPhotosLibrary = true } label: {
                Label("Apple Photos", systemImage: "photo.on.rectangle.angled")
            }
            .buttonStyle(.bordered)
            .help("Scan Apple Photos library for duplicates")
            .accessibilityIdentifier("mac.library.photos")
            Button { model.showOnboarding() } label: {
                Label("How It Works", systemImage: "questionmark.circle")
            }
            .buttonStyle(.bordered)
            .help("View Keptora safety principles and features guide")
            .accessibilityIdentifier("mac.library.howItWorks")
        }
    }

    private var scanButton: some View {
        Button {
            if model.plannedAssets.count > 0 || model.hasResumableReviewSession {
                showRescanConfirmation = true
            } else {
                model.startScan()
            }
        } label: {
            Label("Start Read-Only Scan", systemImage: "sparkle.magnifyingglass")
        }
        .buttonStyle(.borderedProminent)
        .disabled(!model.canStartScan)
        .confirmationDialog(
            "Start new scan?",
            isPresented: $showRescanConfirmation,
            titleVisibility: .visible
        ) {
            Button("Discard Review and Rescan", role: .destructive) {
                model.startScan()
            }
            Button("Keep Current Review", role: .cancel) {}
        } message: {
            Text("Starting a new scan will reset your uncommitted review decisions.")
        }
    }

    private func workflowStep(title: String, value: String, detail: String, systemImage: String, color: Color) -> some View {
        PremiumCard {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.title3.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(color)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 3) {
                    Text(title.uppercased())
                        .font(KeptoraDesign.labelFont)
                        .foregroundStyle(.secondary)
                    Text(value)
                        .font(.headline.monospacedDigit())
                        .lineLimit(1)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @ViewBuilder
    private var scanStatus: some View {
        if model.scanProgress.phase != .idle {
            PremiumCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Label(model.scanProgress.label, systemImage: model.scanProgress.isRunning ? "arrow.triangle.2.circlepath" : "checkmark.circle")
                            .font(.headline)
                        Spacer()
                        if model.scanProgress.isRunning {
                            Button("Cancel", role: .cancel) { model.cancelScan() }
                        }
                    }
                    ProgressView(value: model.scanProgress.fraction)
                    HStack {
                        Text("\(model.scanProgress.processed.formatted()) of \(model.scanProgress.total.formatted())")
                        Spacer()
                        Text(model.scanProgress.currentItem ?? model.scanProgress.message ?? "")
                            .lineLimit(1)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if let message = model.scanProgress.message, model.scanProgress.currentItem != nil {
                        Text(message)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Label("Read-only scan — no files are changed", systemImage: "lock")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

}
