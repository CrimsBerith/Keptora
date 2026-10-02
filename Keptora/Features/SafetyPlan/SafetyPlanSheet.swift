import SwiftUI

struct SafetyPlanSheet: View {
    private enum SortMode: String, CaseIterable, Identifiable {
        case path = "Path"
        case name = "Name"
        case largest = "Largest"
        var id: String { rawValue }
    }

    @State private var query = ""
    @State private var sortMode: SortMode = .path
    @State private var visibleLimit = 300
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 760, idealWidth: 900, minHeight: 560, idealHeight: 680)
        .interactiveDismissDisabled(true)
        .keptoraOnChange(of: query) { visibleLimit = 300 }
        .keptoraOnChange(of: sortMode) { visibleLimit = 300 }
        .onAppear { model.refreshSafetyPlanFreshness() }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.orange.opacity(0.12))
                Image(systemName: "shippingbox")
                    .font(.system(size: 27))
                    .foregroundStyle(.orange)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text("Review Safe Cleanup")
                    .font(.title2.weight(.semibold))
                Text("Keptora moves reviewed duplicate copies into a safe recovery bin. Your original photos are kept safe and untouched.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(22)
    }

    @ViewBuilder
    private var content: some View {
        if let plan = model.pendingPlan {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    planMetric(title: "Files", value: plan.operations.count.formatted(), image: "doc.on.doc")
                    planMetric(title: "Space", value: ByteCountFormatter.string(fromByteCount: plan.estimatedBytes, countStyle: .file), image: "internaldrive")
                    planMetric(title: "Recovery", value: "Restorable", image: "arrow.uturn.backward.circle")
                    planMetric(title: "Verified", value: "\(plan.provenanceCount)/\(plan.operations.count)", image: "checkmark.seal")
                    planMetric(title: "Plan", value: "#\(plan.lineage?.revisionNumber ?? 1)", image: "point.3.connected.trianglepath.dotted")
                }

                if let freshness = model.safetyPlanFreshness {
                    HStack(spacing: 10) {
                        Label(freshness.state.label, systemImage: freshness.permitsCommit ? "checkmark.shield.fill" : "arrow.triangle.2.circlepath")
                            .font(.callout.weight(.semibold))
                            .foregroundStyle(freshness.permitsCommit ? .green : .orange)
                        if freshness.expectedOperationCount != freshness.currentOperationCount {
                            Text("Plan \(freshness.expectedOperationCount) · current \(freshness.currentOperationCount)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            model.refreshSafetyPlanFreshness()
                        } label: {
                            Label("Recheck", systemImage: "arrow.clockwise")
                        }
                        if !freshness.permitsCommit {
                            Button {
                                model.regenerateSafetyPlan(access: store)
                            } label: {
                                Label("Regenerate Plan", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(12)
                    .background((freshness.permitsCommit ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }


                Label("Original keeper photos remain in place. Every duplicate copy is verified before moving, and photo families (like RAW+JPEG or Live Photos) stay together.", systemImage: "checkmark.shield.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if plan.operations.count > 1_000 {
                    Label("Large plan mode is active. Keptora renders 300 rows at a time while retaining the full signed plan for export and commit.", systemImage: "speedometer")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }

                if !plan.familyWarnings.isEmpty {
                    ForEach(plan.familyWarnings) { warning in
                        Label(warning.message, systemImage: "exclamationmark.triangle.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                HStack {
                    TextField("Filter plan by file or folder", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Picker("Sort", selection: $sortMode) {
                        ForEach(SortMode.allCases) { option in Text(LocalizedStringKey(option.rawValue)).tag(option) }
                    }
                    .frame(width: 145)
                }

                let matching = filteredOperations(plan)
                List(Array(matching.prefix(visibleLimit))) { operation in
                    HStack(spacing: 12) {
                        Image(systemName: "photo")
                            .foregroundStyle(.secondary)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(operation.displayName)
                                .font(.callout.weight(.medium))
                            Text(operation.originalURL.deletingLastPathComponent().path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            if let reason = operation.decisionReasonLabel {
                                Label(reason, systemImage: "checkmark.seal")
                                    .font(.caption2)
                                    .foregroundStyle(.green)
                            }
                            if let familyKind = operation.familyKind, let familyRole = operation.familyRole {
                                Text("\(familyKind.localizedLabel) · \(familyRole.localizedLabel)")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                        Spacer()
                        Text(ByteCountFormatter.string(fromByteCount: operation.byteCount, countStyle: .file))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.inset)

                if matching.count > visibleLimit {
                    HStack {
                        Text("Showing \(visibleLimit.formatted()) of \(matching.count.formatted()) matching files")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Show 300 More") { visibleLimit += 300 }
                    }
                }

                DisclosureGroup("Advanced Details") {
                    VStack(alignment: .leading, spacing: 5) {
                        if let lineage = plan.lineage {
                            Text("Plan Revision: R\(lineage.revisionNumber) · \(lineage.lineageID)")
                        }
                        if let volume = plan.sourceVolume {
                            Text("Volume: \(volume.name) · \(volume.stableID)")
                        }
                        Text("Recovery Bin: \(plan.quarantineRoot.path)")
                    }
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .padding(.top, 4)
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                HStack(spacing: 8) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundStyle(Color.green)
                    Text("Original photos are preserved and copies can be restored at any time.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .padding(22)
        } else {
            KeptoraUnavailableView("No plan available", systemImage: "shippingbox")
        }
    }

    private var footer: some View {
        HStack {
            if model.isCommittingCleanup {
                Text("Verifying and safely moving duplicate files…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("You can restore these files at any time from History & Restore.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                model.exportPendingSafetyPlan()
            } label: {
                Label("Export Plan…", systemImage: "square.and.arrow.up")
            }
            .disabled(model.pendingPlan == nil || model.isCommittingCleanup || model.safetyPlanFreshness?.permitsCommit != true)
            Button("Cancel") { model.cancelSafetyPlan() }
                .keyboardShortcut(.cancelAction)
                .disabled(model.isCommittingCleanup)
                .accessibilityIdentifier("mac.safetyPlan.close")
            Button {
                model.commitSafetyPlan(access: store)
            } label: {
                if model.isCommittingCleanup {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 110)
                } else {
                    Label("Move to Safe Bin", systemImage: "shippingbox.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(model.pendingPlan == nil || model.isCommittingCleanup || model.safetyPlanFreshness?.permitsCommit != true)
        }
        .padding(18)
    }

    private func filteredOperations(_ plan: CleanupPlanPreview) -> [CleanupOperationPreview] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered = trimmed.isEmpty ? plan.operations : plan.operations.filter { operation in
            operation.displayName.localizedCaseInsensitiveContains(trimmed) ||
            operation.originalURL.deletingLastPathComponent().path.localizedCaseInsensitiveContains(trimmed)
        }
        switch sortMode {
        case .path:
            return filtered.sorted { $0.originalURL.path.localizedStandardCompare($1.originalURL.path) == .orderedAscending }
        case .name:
            return filtered.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
        case .largest:
            return filtered.sorted { lhs, rhs in
                lhs.byteCount == rhs.byteCount
                    ? lhs.displayName.localizedStandardCompare(rhs.displayName) == .orderedAscending
                    : lhs.byteCount > rhs.byteCount
            }
        }
    }

    private func planMetric(title: String, value: String, image: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: image)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(KeptoraDesign.quiet, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
