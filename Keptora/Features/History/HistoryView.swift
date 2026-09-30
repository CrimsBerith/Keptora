import SwiftUI

struct HistoryView: View {
    private enum HistoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case quarantined = "In Recovery Bin"
        case restored = "Restored"
        case attention = "Needs Attention"
        var id: String { rawValue }
    }

    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var filter: HistoryFilter = .all

    var body: some View {
        Group {
            if model.cleanupHistory.isEmpty {
                KeptoraUnavailableView(
                    "No cleanup history yet",
                    systemImage: "clock.badge.checkmark",
                    description: "Completed Safety Plans will appear here.",
                    actionTitle: "Back to Library",
                    action: { model.selectedRoute = .home }
                )
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        quarantineSummary
                        HStack {
                            TextField("Search source or plan ID", text: $query)
                                .textFieldStyle(.roundedBorder)
                            Picker("Status", selection: $filter) {
                                ForEach(HistoryFilter.allCases) { option in Text(LocalizedStringKey(option.rawValue)).tag(option) }
                            }
                            .labelsHidden()
                            .accessibilityLabel("Status filter")
                            .frame(width: 180)
                        }

                        // Filtered once per render; the property walks the whole history.
                        let items = filteredHistory
                        if items.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .font(.title)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                                Text("No matching plans")
                                    .font(.headline)
                                Text("Try a different search or status filter.")
                                    .font(.callout)
                                    .foregroundStyle(.secondary)
                                Button("Clear Filters") {
                                    query = ""
                                    filter = .all
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 14) {
                                ForEach(items) { item in
                                    historyCard(item)
                                }
                            }
                        }
                    }
                    .padding(KeptoraDesign.pagePadding)
                    .frame(maxWidth: 980)
                }
                .background(KeptoraDesign.canvas)
            }
        }
        .navigationTitle("History & Restore")
        .accessibilityIdentifier("mac.page.history")
    }

    private var quarantineSummary: some View {
        var activeCount = 0
        var activeFiles = 0
        var activeBytes: Int64 = 0
        var signedManifestCount = 0

        for item in model.cleanupHistory {
            if item.canRestore {
                activeCount += 1
                activeFiles += item.operationCount
                activeBytes += item.estimatedBytes
            }
            if item.manifestPath != nil {
                signedManifestCount += 1
            }
        }

        let verifiedStatesCount = model.quarantineVerificationLineage.lazy.filter { $0.state == .verified }.count

        // Adaptive grid: five metrics in one row truncate at the minimum window width.
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            summaryMetric("Active plans", activeCount.formatted(), "shippingbox")
            summaryMetric("Files in bin", activeFiles.formatted(), "doc.on.doc")
            summaryMetric("Restorable space", ByteCountFormatter.string(fromByteCount: activeBytes, countStyle: .file), "internaldrive")
            summaryMetric("Signed manifests", signedManifestCount.formatted(), "signature")
            summaryMetric("Verified states", verifiedStatesCount.formatted(), "checkmark.shield")
        }
    }

    private var filteredHistory: [CleanupHistoryItem] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return model.cleanupHistory.filter { item in
            let filterMatches: Bool
            switch filter {
            case .all: filterMatches = true
            case .quarantined: filterMatches = item.state == .committed || item.state == .partiallyCommitted || item.state == .partiallyRestored
            case .restored: filterMatches = item.state == .restored
            case .attention: filterMatches = item.state == .failed || item.state == .committing || item.state == .draft
            }
            guard filterMatches else { return false }
            guard !trimmed.isEmpty else { return true }
            return item.sourcePath.localizedCaseInsensitiveContains(trimmed)
                || item.id.localizedCaseInsensitiveContains(trimmed)
                || item.state.label.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func historyCard(_ item: CleanupHistoryItem) -> some View {
        PremiumCard {
            HStack(alignment: .top, spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 13, style: .continuous)
                        .fill(statusColor(item.state).opacity(0.12))
                    Image(systemName: statusImage(item.state))
                        .font(.title2)
                        .foregroundStyle(statusColor(item.state))
                }
                .frame(width: 52, height: 52)

                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text(item.state.label)
                            .font(.headline)
                        Text(item.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.sourcePath)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text("Plan \(item.id.prefix(12))")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    HStack(spacing: 14) {
                        Label("\(item.operationCount) files", systemImage: "doc.on.doc")
                        Label(ByteCountFormatter.string(fromByteCount: item.estimatedBytes, countStyle: .file), systemImage: "internaldrive")
                        if item.manifestPath != nil {
                            Label("Signed manifest", systemImage: "signature")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if let verification = model.latestQuarantineVerification(for: item.id) {
                        HStack(spacing: 8) {
                            Label(
                                verification.state.label,
                                systemImage: verification.state == .verified ? "checkmark.shield.fill" : "exclamationmark.shield.fill"
                            )
                            Text("v\(verification.identity.revisionNumber) • \(verification.phase.localizedLabel) • \(verification.verifiedCount)/\(verification.operationCount)")
                        }
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(verification.state == .verified ? KeptoraDesign.success : KeptoraDesign.warning)
                    } else {
                        Text("No post-commit verification record yet")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 8) {
                        historyActionButtons(item: item)
                    }
                    VStack(alignment: .trailing, spacing: 8) {
                        historyActionButtons(item: item)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func historyActionButtons(item: CleanupHistoryItem) -> some View {
        if item.manifestPath != nil {
            Button("Show Manifest") { model.revealManifest(item) }
                .buttonStyle(.bordered)
            Button {
                model.verifyCleanupState(item)
            } label: {
                if model.verifyingCleanupPlanID == item.id {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Verify State", systemImage: "checkmark.shield")
                }
            }
            .buttonStyle(.bordered)
            .disabled(model.verifyingCleanupPlanID != nil || model.restoringPlanID != nil || model.isCommittingCleanup)
            .accessibilityIdentifier("keptora.history.verifyState.\(item.id)")
        }
        if item.canRestore {
            Button {
                model.prepareRestorePreview(item)
            } label: {
                if model.isPreparingRestorePreview && model.restorePreviewItem?.id == item.id {
                    ProgressView().controlSize(.small)
                } else {
                    Label("Review Restore", systemImage: "arrow.uturn.backward.circle")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(model.restoringPlanID != nil || model.isPreparingRestorePreview)
        }
    }

    private func summaryMetric(_ title: String, _ value: String, _ image: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: image).foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption).foregroundStyle(.secondary)
                Text(value).font(.headline)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KeptoraDesign.quiet, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private func statusImage(_ state: CleanupPlanState) -> String {
        switch state {
        case .committed, .partiallyCommitted: return "shippingbox.fill"
        case .restored, .partiallyRestored: return "arrow.uturn.backward.circle.fill"
        case .failed: return "exclamationmark.triangle.fill"
        case .draft, .committing: return "doc.badge.clock"
        }
    }

    private func statusColor(_ state: CleanupPlanState) -> Color {
        switch state {
        case .committed, .partiallyCommitted: return KeptoraDesign.warning
        case .restored, .partiallyRestored: return KeptoraDesign.success
        case .failed: return KeptoraDesign.danger
        case .draft, .committing: return KeptoraDesign.accent
        }
    }
}
