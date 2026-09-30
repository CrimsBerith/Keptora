import SwiftUI

struct MobileHistoryView: View {
    @EnvironmentObject private var store: MobileKeptoraStore

    var body: some View {
        ZStack {
            MobileAuroraBackground()
            Group {
                if store.history.isEmpty {
                    ContentUnavailableView {
                        Label("No cleanup history", systemImage: "clock.badge.checkmark")
                    } description: {
                        Text("Completed cleanup and quarantine actions will appear here with full restoration records.")
                    } actions: {
                        Button {
                            store.selectedTab = 0
                        } label: {
                            Text("Scan Media")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MobileKeptoraDesign.accent)
                        .controlSize(.large)
                    }
                } else {
                    List(store.history) { entry in
                        VStack(alignment: .leading, spacing: 14) {
                            HStack(spacing: 14) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(
                                            LinearGradient(
                                                colors: [historyTint(entry), historyTint(entry).opacity(0.60)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                            .opacity(0.16)
                                        )
                                    Image(systemName: entry.kind == .photosRecentlyDeleted ? "photo.badge.checkmark" : "shippingbox.fill")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundStyle(historyTint(entry))
                                }
                                .frame(width: 48, height: 48)

                                VStack(alignment: .leading, spacing: 3) {
                                    if entry.kind == .photosRecentlyDeleted {
                                        Text("Photos Recently Deleted")
                                            .font(.system(.headline, design: .rounded).weight(.semibold))
                                    } else {
                                        Text("Keptora Quarantine")
                                            .font(.system(.headline, design: .rounded).weight(.semibold))
                                    }
                                    Text(entry.createdAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.system(.caption, design: .rounded))
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            HStack(spacing: 10) {
                                HStack(spacing: 5) {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(String(format: String(localized: "%@ items"), entry.itemCount.formatted()))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.primary.opacity(0.06), in: Capsule())

                                HStack(spacing: 5) {
                                    Image(systemName: "internaldrive")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text(ByteCountFormatter.string(fromByteCount: entry.byteCount, countStyle: .file))
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                }
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(Color.primary.opacity(0.06), in: Capsule())
                            }
                            .foregroundStyle(.secondary)

                            if entry.kind == .photosRecentlyDeleted {
                                Text("Recover items from Recently Deleted in Apple Photos. With iCloud Photos, recovery syncs across your devices.")
                                    .font(.system(.footnote, design: .rounded))
                                    .foregroundStyle(.secondary)
                            } else if entry.restoredAt != nil {
                                HStack(spacing: 6) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.system(size: 13, weight: .bold))
                                    Text("Restored")
                                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                }
                                .foregroundStyle(MobileKeptoraDesign.mint)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 5)
                                .background(MobileKeptoraDesign.mint.opacity(0.12), in: Capsule())
                            } else {
                                Button("Restore Files") { Task { await store.restore(entry) } }
                                    .buttonStyle(.borderedProminent)
                                    .tint(MobileKeptoraDesign.accent)
                                    .controlSize(.regular)
                                    .accessibilityIdentifier("ios.history.restore.\(entry.id.uuidString)")
                            }
                        }
                        .keptoraPanel(tint: historyTint(entry))
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .accessibilityIdentifier("ios.history.entry.\(entry.id.uuidString)")
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .navigationTitle("History")
        .accessibilityIdentifier("ios.page.history")
    }

    private func historyTint(_ entry: MobileKeptoraStore.CleanupHistoryEntry) -> Color {
        entry.kind == .photosRecentlyDeleted ? MobileKeptoraDesign.coral : MobileKeptoraDesign.amber
    }
}
