import SwiftUI

struct RestorePreviewSheet: View {
    private enum Filter: String, CaseIterable, Identifiable {
        case all = "All"
        case ready = "Ready"
        case blocked = "Blocked"
        case restored = "Already Restored"
        var id: String { rawValue }
    }

    @EnvironmentObject private var model: AppModel
    @State private var query = ""
    @State private var filter: Filter = .all
    @State private var confirmed = false
    @State private var visibleLimit = 300

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            content
            Divider()
            footer
        }
        .frame(minWidth: 760, idealWidth: 920, minHeight: 560, idealHeight: 680)
        .interactiveDismissDisabled(model.restoringPlanID != nil)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.green.opacity(0.12))
                Image(systemName: "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 28))
                    .foregroundStyle(.green)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 5) {
                Text("Review Restore")
                    .font(.title2.weight(.semibold))
                Text("Keptora verifies the signed manifest, original paths, quarantine files, byte counts, and SHA-256 digests before enabling restore.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(22)
    }

    @ViewBuilder
    private var content: some View {
        if let preview = model.restorePreview {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    metric("Ready", preview.readyCount.formatted(), "checkmark.shield")
                    metric("Blocked", preview.blockedCount.formatted(), "exclamationmark.triangle")
                    metric("Space", ByteCountFormatter.string(fromByteCount: preview.restorableBytes, countStyle: .file), "internaldrive")
                    metric("Already restored", preview.alreadyRestoredCount.formatted(), "checkmark.circle")
                }

                if preview.blockedCount > 0 {
                    Label("Restore is blocked until every remaining quarantined file is safe. Keptora will not overwrite occupied original paths or restore changed content.", systemImage: "hand.raised.fill")
                        .font(.callout)
                        .foregroundStyle(.orange)
                } else {
                    Label("Every ready file matches the signed manifest and has an unoccupied original destination.", systemImage: "checkmark.shield.fill")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    TextField("Filter by file, path, or status", text: $query)
                        .textFieldStyle(.roundedBorder)
                    Picker("Status", selection: $filter) {
                        ForEach(Filter.allCases) { option in Text(LocalizedStringKey(option.rawValue)).tag(option) }
                    }
                    .frame(width: 180)
                }

                let matching = filteredOperations(preview)
                List(Array(matching.prefix(visibleLimit))) { operation in
                    HStack(spacing: 12) {
                        Image(systemName: icon(for: operation.readiness))
                            .foregroundStyle(color(for: operation.readiness))
                            .frame(width: 22)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(operation.displayName)
                                .font(.callout.weight(.medium))
                            Text(operation.originalURL.deletingLastPathComponent().path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Text(operation.detail)
                                .font(.caption2)
                                .foregroundStyle(operation.readiness.isRestorable ? .secondary : color(for: operation.readiness))
                                .lineLimit(2)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(operation.readiness.label)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(color(for: operation.readiness))
                            Text(ByteCountFormatter.string(fromByteCount: operation.byteCount, countStyle: .file))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
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

                Text("Source: \(preview.sourceRoot.path)")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .textSelection(.enabled)

                Toggle("I reviewed all restore conflicts and understand that Keptora will never overwrite an occupied original path.", isOn: $confirmed)
                    .toggleStyle(.checkbox)
            }
            .padding(22)
        } else if model.isPreparingRestorePreview {
            VStack(spacing: 14) {
                ProgressView()
                Text("Verifying restore safety…")
                    .font(.headline)
                Text("Large plans may take time because every quarantined file is re-hashed locally.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            KeptoraUnavailableView("No restore preview available", systemImage: "arrow.uturn.backward.circle")
        }
    }

    private var footer: some View {
        HStack {
            Text(model.restoringPlanID == nil ? "Nothing moves until you confirm this verified preview." : "Restoring verified files…")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Cancel") { model.cancelRestorePreview() }
                .keyboardShortcut(.cancelAction)
                .disabled(model.restoringPlanID != nil)
            Button {
                model.confirmRestorePreview()
            } label: {
                if model.restoringPlanID != nil {
                    ProgressView().controlSize(.small).frame(minWidth: 100)
                } else {
                    Label("Restore Verified Files", systemImage: "arrow.uturn.backward")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(model.restorePreview?.canRestore != true || !confirmed || model.restoringPlanID != nil)
        }
        .padding(18)
    }

    private func filteredOperations(_ preview: RestorePlanPreview) -> [RestoreOperationCheck] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return preview.operations.filter { operation in
            let filterMatches: Bool
            switch filter {
            case .all: filterMatches = true
            case .ready: filterMatches = operation.readiness == .ready
            case .blocked: filterMatches = !operation.readiness.isRestorable && operation.readiness != .alreadyRestored
            case .restored: filterMatches = operation.readiness == .alreadyRestored
            }
            guard filterMatches else { return false }
            guard !trimmed.isEmpty else { return true }
            return operation.displayName.localizedCaseInsensitiveContains(trimmed)
                || operation.originalURL.path.localizedCaseInsensitiveContains(trimmed)
                || operation.readiness.label.localizedCaseInsensitiveContains(trimmed)
        }
    }

    private func metric(_ title: String, _ value: String, _ image: String) -> some View {
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

    private func icon(for readiness: RestoreOperationReadiness) -> String {
        switch readiness {
        case .ready: return "checkmark.shield.fill"
        case .alreadyRestored: return "checkmark.circle.fill"
        case .originalOccupied: return "square.on.square"
        case .quarantineMissing: return "questionmark.folder"
        case .contentChanged: return "exclamationmark.triangle.fill"
        case .notQuarantined: return "minus.circle"
        }
    }

    private func color(for readiness: RestoreOperationReadiness) -> Color {
        switch readiness {
        case .ready, .alreadyRestored: return .green
        case .originalOccupied, .quarantineMissing, .contentChanged: return .orange
        case .notQuarantined: return .secondary
        }
    }
}
