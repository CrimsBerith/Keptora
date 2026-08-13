import SwiftUI

struct DiagnosticsView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var store: StoreEntitlementController
    @AppStorage("Cullora.ShowFilePaths") private var showFilePaths = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                statusGrid
                performanceCard
                privacyCard
                supportCard
            }
            .padding(CulloraDesign.pagePadding)
            .frame(maxWidth: 980, alignment: .leading)
        }
        .background(CulloraDesign.canvas)
        .navigationTitle("Support & Diagnostics")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Useful diagnostics without exposing your library.")
                .font(CulloraDesign.titleFont)
            Text("Cullora exports app state, counters, and bounded local performance samples. Full local paths are excluded unless you explicitly enable them below.")
                .font(.title3)
                .foregroundStyle(.secondary)
        }
    }

    private var statusGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 14)], spacing: 14) {
            MetricTile(title: "Scan state", value: model.scanProgress.label, systemImage: "magnifyingglass")
            MetricTile(title: "Source", value: model.sourceAvailability.label, systemImage: "externaldrive")
            MetricTile(title: "Recovery issues", value: model.recoveryIssues.count.formatted(), systemImage: "arrow.triangle.2.circlepath")
            MetricTile(title: "Access", value: store.isLifetimeUnlocked ? "Pro" : "Free", systemImage: "checkmark.seal")
        }
    }

    private var performanceCard: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Label("Local performance history", systemImage: "speedometer")
                        .font(.headline)
                    Spacer()
                    Button("Export History…") { model.exportPerformanceHistory() }
                        .disabled(model.performanceSamples.isEmpty)
                }
                Text("Cullora stores at most 200 timing samples on this Mac. No filenames, paths, hashes, image bytes, or account data are recorded.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if model.performanceSamples.isEmpty {
                    Text("Run a scan, similarity analysis, quarantine commit, or restore to create a local sample.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(model.performanceSamples.suffix(5).reversed())) { sample in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(sample.label).font(.callout.weight(.medium))
                                Text(sample.recordedAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(sample.itemCount.formatted()) items")
                                .font(.caption.monospacedDigit())
                            Text(sample.elapsedSeconds.formatted(.number.precision(.fractionLength(2))) + " s")
                                .font(.caption.monospacedDigit())
                            Text(sample.result.capitalized)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(sample.result == "completed" ? .green : .orange)
                        }
                        if sample.id != model.performanceSamples.last?.id { Divider() }
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
                Toggle("Include full local paths in exported diagnostics", isOn: $showFilePaths)
                Text(showFilePaths
                     ? "Exported JSON can include the selected source path and current filename. Review it before sharing."
                     : "Paths and current filenames are redacted. This is the recommended support setting.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                    Button(showFilePaths ? "Copy Diagnostics" : "Copy Redacted Diagnostics") { model.copyDiagnostics() }
                    Button("Export Diagnostics…") { model.exportDiagnostics() }
                        .buttonStyle(.borderedProminent)
                }
                Divider()
                Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 8) {
                    GridRow { Text("Version").foregroundStyle(.secondary); Text(model.displayVersion) }
                    GridRow { Text("Database").foregroundStyle(.secondary); Text("Schema 4") }
                    GridRow { Text("Privacy manifest").foregroundStyle(.secondary); Text("Bundled") }
                    GridRow { Text("Permanent delete API").foregroundStyle(.secondary); Text("Not present") }
                    GridRow { Text("Performance retention").foregroundStyle(.secondary); Text("200 local samples") }
                }
                .font(.callout)
            }
        }
    }
}
