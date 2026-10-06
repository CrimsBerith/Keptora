import KeptoraCore
import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController
    @EnvironmentObject private var archive: MacArchiveModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusGrid
                performanceCard
                privacyCard
                supportCard
            }
            .padding(KeptoraDesign.pagePadding)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .background(KeptoraDesign.canvas)
        .navigationTitle("Support & Diagnostics")
        .accessibilityIdentifier("mac.page.diagnostics")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Useful diagnostics without exposing your library.")
                .font(KeptoraDesign.titleFont)
            Text("Current library diagnostics include scan progress, skipped items and recovery status. Filenames and paths are always redacted.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var statusGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
            MetricTile(title: "Scan state", value: archive.analysisPaused ? L10n.tr("Scan paused.") : archive.status ?? L10n.tr(archive.sessionProgress.isComplete ? "Scan complete. Choose what to keep." : "Ready"), systemImage: "magnifyingglass")
            MetricTile(title: "Sources", value: archive.selectedSourceIDs.count.formatted(), systemImage: "externaldrive")
            MetricTile(title: "Recovery issues", value: archive.history.reduce(0) { $0 + ($1.folderRecord?.unresolvedCount ?? ($1.operationState == .planned ? 1 : 0)) }.formatted(), systemImage: "arrow.triangle.2.circlepath")
            MetricTile(title: "Access", value: store.isLifetimeUnlocked ? "Pro" : "Free", systemImage: "checkmark.seal")
        }
    }

    private var performanceCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Current library analysis", systemImage: "speedometer")
                        .font(.headline)
                    Spacer()
                    Button {
                        archive.exportDiagnostics()
                    } label: {
                        Label("Export Diagnostics…", systemImage: "square.and.arrow.up")
                    }
                    .disabled(archive.workMetrics.isEmpty)
                }
                Text("These counters describe your current library scan. Exported diagnostics contain no filenames, paths, image bytes or account data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if archive.workMetrics.isEmpty {
                    Text("Start a library scan to see its analysis counters.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(AnalysisStage.allCases, id: \.self) { stage in
                        if let sample = archive.workMetrics[stage] {
                        HStack {
                            Text(LocalizedStringKey(stage.titleKey)).font(.callout.weight(.medium))
                            Spacer()
                            Text(L10n.format("Cache hits: %lld · Decoded previews: %lld · Hashed originals: %lld", sample.cacheHits, sample.decodedPreviews, sample.hashedOriginals)).font(.caption.monospacedDigit())
                        }
                        }
                    }
                }
            }
        }
    }

    private var privacyCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 12) {
                Label("Diagnostic privacy", systemImage: "lock.doc.fill")
                    .font(.headline)
                Text("Library diagnostics always redact filenames and paths. No image data is exported.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var supportCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                Text("Support package")
                    .font(.headline)
                Text("Export a structured JSON snapshot for debugging. It contains no image bytes, thumbnails, hashes, file contents, or account identifiers.")
                    .foregroundStyle(.secondary)
                HStack {
                    Button {
                        archive.copyDiagnostics()
                    } label: {
                        Label("Copy Redacted Diagnostics", systemImage: "doc.on.doc")
                    }
                    Button {
                        archive.exportDiagnostics()
                    } label: {
                        Label("Export Diagnostics…", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                Divider()
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow { Text("Version").foregroundStyle(.secondary); Text(model.displayVersion) }
                    GridRow { Text("Session format").foregroundStyle(.secondary); Text("1") }
                    GridRow { Text("Privacy manifest").foregroundStyle(.secondary); Text("Bundled") }
                    GridRow { Text("Permanent delete API").foregroundStyle(.secondary); Text("Not present") }
                    GridRow { Text("Analysis counters").foregroundStyle(.secondary); Text("Current session") }
                }
                .font(.callout)
            }
        }
    }
}
