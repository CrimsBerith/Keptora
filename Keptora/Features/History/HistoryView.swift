import SwiftUI

struct HistoryView: View {
    private enum HistoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case quarantined = "In Quarantine"
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
                            .frame(width: 180)
                        }

                        LazyVStack(spacing: 14) {
                            ForEach(filteredHistory) { item in
                                historyCard(item)
                            }
                        }
                    }
                    .padding(KeptoraDesign.pagePadding)
                    .frame(maxWidth: 980)
                }
                .background(KeptoraDesign.canvas)
            }
        }
        .navigationTitle("Quarantine & Restore")
        .accessibilityIdentifier("mac.page.history")
    }

    private var quarantineSummary: some View {
        let active = model.cleanupHistory.filter { $0.canRestore }
        let activeFiles = active.reduce(0) { $0 + $1.operationCount }
        let activeBytes = active.reduce(Int64(0)) { $0 + $1.estimatedBytes }
        return HStack(spacing: 12) {
            summaryMetric("Active plans", active.count.formatted(), "shippingbox")
            summaryMetric("Tracked files", activeFiles.formatted(), "doc.on.doc")
            summaryMetric("Restorable space", ByteCountFormatter.string(fromByteCount: activeBytes, countStyle: .file), "internaldrive")
            summaryMetric("Signed manifests", model.cleanupHistory.filter { $0.manifestPath != nil }.count.formatted(), "signature")
            summaryMetric("Verified states", model.quarantineVerificationLineage.filter { $0.state == .verified }.count.formatted(), "checkmark.shield")
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
                        .foregroundStyle(verification.state == .verified ? .green : .orange)
                    } else {
                        Text("No post-commit verification record yet")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                HStack {
                    if item.manifestPath != nil {
                        Button("Show Manifest") { model.revealManifest(item) }
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
            }
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
        case .committed, .partiallyCommitted: return .orange
        case .restored, .partiallyRestored: return .green
        case .failed: return .red
        case .draft, .committing: return .blue
        }
    }
}
