import KeptoraCore
import SwiftUI

struct MobileHistoryView: View {
    @EnvironmentObject private var store: MobileKeptoraStore
    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var entryToRestore: MobileKeptoraStore.CleanupHistoryEntry?
    @ScaledMetric(relativeTo: .title3) private var iconBoxSize: CGFloat = 48

    var body: some View {
        ZStack {
            MobileAuroraBackground()
            VStack(spacing: 0) {
                if !store.recoveryCatalogueIssues.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("A recovery record could not be read", systemImage: "exclamationmark.triangle")
                            .font(.headline)
                        Text("The files were kept. Open the recovery folder to inspect this record.")
                            .font(.footnote)
                        Button("Retry") { Task { await store.loadCatalogue() } }
                            .buttonStyle(.bordered)
                            .disabled(store.isLoadingCatalogue)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .keptoraMobileGlass(cornerRadius: 16, tint: MobileKeptoraDesign.amber)
                    .padding(.horizontal)
                    .accessibilityIdentifier("ios.history.recoveryWarning")
                }
                if store.history.isEmpty {
                    ContentUnavailableView {
                        Label("No cleanup history", systemImage: "clock.badge.checkmark")
                    } description: {
                        Text("Completed actions show their source, result and available recovery steps.")
                    } actions: {
                        Button {
                            store.selectedTab = .library
                        } label: {
                            Text("Browse Library")
                                .font(.headline)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(MobileKeptoraDesign.accent)
                        .controlSize(.large)
                    }
                } else {
                    List {
                        ForEach(store.history) { entry in
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 14) {
                                  if !typeSize.isAccessibilitySize {
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
                                            .font(.system(.title3, design: .rounded).weight(.semibold))
                                            .foregroundStyle(historyTint(entry))
                                            .accessibilityHidden(true)
                                    }
                                    .frame(width: iconBoxSize, height: iconBoxSize)
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .stroke(historyTint(entry).opacity(0.25), lineWidth: 0.8)
                                    }
                                  }

                                    VStack(alignment: .leading, spacing: 3) {
                                        if entry.kind == .photosRecentlyDeleted {
                                            Text("Photos Recently Deleted")
                                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                                .accessibilityIdentifier("ios.history.title.\(entry.id.uuidString)")
                                        } else {
                                            Text("Recovery Folder")
                                                .font(.system(.headline, design: .rounded).weight(.semibold))
                                                .accessibilityIdentifier("ios.history.title.\(entry.id.uuidString)")
                                        }
                                        Text(entry.createdAt.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened, locale: L10n.currentLocale)))
                                            .font(.system(.caption, design: .rounded))
                                            .foregroundStyle(MobileKeptoraDesign.secondaryInk)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }

                                let summaryLayout = typeSize.isAccessibilitySize
                                    ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
                                    : AnyLayout(HStackLayout(spacing: 10))
                                summaryLayout {
                                    HStack(spacing: 5) {
                                        Image(systemName: "doc.on.doc")
                                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                                            .accessibilityHidden(true)
                                        Text(L10n.plural("%lld items", entry.itemCount))
                                            .font(.system(.caption, design: .rounded).weight(.bold))
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.06), in: Capsule())

                                    HStack(spacing: 5) {
                                        Image(systemName: "internaldrive")
                                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                                            .accessibilityHidden(true)
                                        Text(entry.byteCount > 0 ? ByteCountFormatter.string(fromByteCount: entry.byteCount, countStyle: .file) : L10n.tr("Media size unavailable"))
                                            .font(.system(.caption, design: .rounded).weight(.bold))
                                    }
                                    .padding(.horizontal, 9)
                                    .padding(.vertical, 5)
                                    .background(Color.primary.opacity(0.06), in: Capsule())
                                }
                                .foregroundStyle(MobileKeptoraDesign.secondaryInk)

                                if entry.kind == .photosRecentlyDeleted {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Recover items in Apple Photos → Recently Deleted for up to 30 days unless permanently deleted sooner.")
                                            .font(.system(.footnote, design: .rounded))
                                            .foregroundStyle(MobileKeptoraDesign.secondaryInk)

                                        Button {
                                            if let url = URL(string: "photos-redirect://") {
                                                UIApplication.shared.open(url)
                                            }
                                        } label: {
                                            Label("Open Apple Photos", systemImage: "arrow.up.forward.app")
                                                .font(.system(.caption, design: .rounded).weight(.semibold))
                                        }
                                        .buttonStyle(MobileActionButtonStyle())
                                    }
                                } else if entry.restoredAt != nil {
                                    HStack(spacing: 6) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.subheadline.weight(.bold))
                                        Text("Restored")
                                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                                    }
                                    .foregroundStyle(MobileKeptoraDesign.mint)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(MobileKeptoraDesign.mint.opacity(0.12), in: Capsule())
                                } else {
                                    Text("Files remain in the recovery folder on the same storage.").font(.footnote).foregroundStyle(MobileKeptoraDesign.secondaryInk)
                                    Button("Restore Files") {
                                        entryToRestore = entry
                                    }
                                    .buttonStyle(MobilePrimaryButtonStyle())
                                    .accessibilityIdentifier("ios.history.restore.\(entry.id.uuidString)")
                                }
                            }
                            .keptoraPanel(tint: historyTint(entry))
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .accessibilityElement(children: .contain)
                            .accessibilityIdentifier("ios.history.entry.\(entry.id.uuidString)")
                        }
                        .onDelete(perform: store.deleteHistory)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
        }
        .overlay { if store.isCleaningUp { ProgressView(store.cleanupStatus ?? L10n.tr("Restoring files…")).padding(22).keptoraMobileGlass(cornerRadius: 18, tint: MobileKeptoraDesign.accent) } }
        .disabled(store.isCleaningUp)
        .navigationTitle("History")
        .accessibilityIdentifier("ios.page.history")
        .alert("Restore Files", isPresented: Binding(
            get: { entryToRestore != nil },
            set: { if !$0 { entryToRestore = nil } }
        )) {
            Button("Cancel", role: .cancel) { entryToRestore = nil }
            Button("Restore") {
                if let entry = entryToRestore {
                    Task { await store.restore(entry) }
                }
            }
        } message: {
            Text("This will move files back to their original locations.")
        }
    }

    private func historyTint(_ entry: MobileKeptoraStore.CleanupHistoryEntry) -> Color {
        entry.kind == .photosRecentlyDeleted ? MobileKeptoraDesign.coral : MobileKeptoraDesign.amber
    }
}
