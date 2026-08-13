import SwiftUI

struct SafetyPlanSheet: View {
    private enum SortMode: String, CaseIterable, Identifiable {
        case path = "Path"
        case name = "Name"
        case largest = "Largest"
        var id: String { rawValue }
    }

    @State private var query = ""
    @State private var confirmed = false
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
        .onChange(of: query) { _ in visibleLimit = 300 }
        .onChange(of: sortMode) { _ in visibleLimit = 300 }
        .onAppear { model.refreshSafetyPlanFreshness() }
        .onChange(of: model.safetyPlanFreshness?.state) { state in
            if state != .current { confirmed = false }
        }
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
                Text("Review Safety Plan")
                    .font(.title2.weight(.semibold))
                Text("Cullora will move reviewed copies into a hidden quarantine folder beside the originals. Nothing is permanently deleted.")
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
                    planMetric(title: "Decision proof", value: "\(plan.provenanceCount)/\(plan.operations.count)", image: "checkmark.seal")
                    planMetric(title: "Revision", value: "R\(plan.lineage?.revisionNumber ?? 1)", image: "point.3.connected.trianglepath.dotted")
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
                        Button("Recheck") { model.refreshSafetyPlanFreshness() }
                        if !freshness.permitsCommit {
                            Button("Regenerate Plan") { model.regenerateSafetyPlan(access: store) }
                                .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(12)
                    .background((freshness.permitsCommit ? Color.green : Color.orange).opacity(0.08), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let lineage = plan.lineage {
                    Label("Safety Plan lineage R\(lineage.revisionNumber) · \(lineage.lineageID.prefix(10))", systemImage: "link")
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Label("Every operation carries its exact-review decision provenance and protected keeper identity into the signed manifest. RAW/sidecar and Live Photo families must move together. Each file is re-hashed immediately before it moves.", systemImage: "checkmark.shield.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)

                if plan.operations.count > 1_000 {
                    Label("Large plan mode is active. Cullora renders 300 rows at a time while retaining the full signed plan for export and commit.", systemImage: "speedometer")
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
                        ForEach(SortMode.allCases) { option in Text(option.rawValue).tag(option) }
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
                                Text("\(familyKind.rawValue) · \(familyRole.rawValue)")
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

                if let volume = plan.sourceVolume {
                    Text("Volume: \(volume.name) · \(volume.stableID)")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .textSelection(.enabled)
                }
                Text("Quarantine: \(plan.quarantineRoot.path)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)

                Toggle("I reviewed the destination, protected keepers, and recovery path.", isOn: $confirmed)
                    .toggleStyle(.checkbox)
            }
            .padding(22)
        } else {
            CulloraUnavailableView("No plan available", systemImage: "shippingbox")
        }
    }

    private var footer: some View {
        HStack {
            Text(model.isCommittingCleanup ? "Verifying and moving reviewed files…" : "You can restore this plan later from Quarantine & Restore.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Export Plan…") { model.exportPendingSafetyPlan() }
                .disabled(model.pendingPlan == nil || model.isCommittingCleanup || model.safetyPlanFreshness?.permitsCommit != true)
            Button("Cancel") { model.cancelSafetyPlan() }
                .keyboardShortcut(.cancelAction)
                .disabled(model.isCommittingCleanup)
            Button {
                model.commitSafetyPlan(access: store)
            } label: {
                if model.isCommittingCleanup {
                    ProgressView()
                        .controlSize(.small)
                        .frame(minWidth: 110)
                } else {
                    Label("Move to Quarantine", systemImage: "shippingbox.fill")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(model.pendingPlan == nil || model.isCommittingCleanup || !confirmed || model.safetyPlanFreshness?.permitsCommit != true)
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
        .background(CulloraDesign.quiet, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}
