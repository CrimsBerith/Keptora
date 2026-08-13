import SwiftUI

struct ReviewInsightsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                metricGrid
                sessionCard
                reviewPipeline
                safetyBoundary
            }
            .padding(CulloraDesign.pagePadding)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .background(CulloraDesign.canvas)
        .navigationTitle("Review Insights")
    }

    private var insights: ReviewInsights { model.reviewInsights }

    private var header: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 7) {
                Text("Know what is ready before cleanup.")
                    .font(CulloraDesign.titleFont)
                Text("Track exact-set review progress, planned recovery, and conservative similarity evidence without turning suggestions into deletion decisions.")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: 760, alignment: .leading)
            }
            Spacer()
            Button {
                model.selectedRoute = .review
            } label: {
                Label("Open Review Studio", systemImage: "square.grid.2x2")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 14)], spacing: 14) {
            MetricTile(title: "Exact groups", value: insights.totalGroups.formatted(), systemImage: "square.on.square")
            MetricTile(title: "Unreviewed", value: insights.unreviewedGroups.formatted(), systemImage: "circle.dashed")
            MetricTile(title: "In progress", value: insights.inProgressGroups.formatted(), systemImage: "circle.lefthalf.filled")
            MetricTile(title: "Planned groups", value: insights.plannedGroups.formatted(), systemImage: "shippingbox.fill")
            MetricTile(title: "Potential recovery", value: ByteCountFormatter.string(fromByteCount: insights.totalPotentialBytes, countStyle: .file), systemImage: "internaldrive")
            MetricTile(title: "Planned recovery", value: ByteCountFormatter.string(fromByteCount: insights.plannedBytes, countStyle: .file), systemImage: "checkmark.circle")
            MetricTile(title: "Exact assets", value: insights.exactAssets.formatted(), systemImage: "photo.stack")
            MetricTile(title: "Similar sets", value: insights.similarGroups.formatted(), systemImage: "sparkles.rectangle.stack")
        }
    }

    @ViewBuilder
    private var sessionCard: some View {
        if let checkpoint = model.reviewSessionCheckpoint, model.hasResumableReviewSession {
            PremiumCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Label("Local review session", systemImage: "timer")
                            .font(.headline)
                        Spacer()
                        Text(checkpoint.positionLabel)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: checkpoint.progressFraction)
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 170), spacing: 12)], spacing: 12) {
                        sessionMetric("Decisions", value: checkpoint.reviewedAssets.formatted())
                        sessionMetric("Completed groups", value: checkpoint.completedGroups.formatted())
                        sessionMetric("Planned recovery", value: ByteCountFormatter.string(fromByteCount: checkpoint.plannedBytes, countStyle: .file))
                        sessionMetric("Local pace", value: checkpoint.reviewedPerMinute > 0 ? "\(checkpoint.reviewedPerMinute.formatted(.number.precision(.fractionLength(1)))) / min" : "Warming up")
                    }
                    HStack {
                        Text("These metrics are computed from the on-device decision ledger and are never uploaded.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Resume Session") { model.resumeReviewSession() }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
    }

    private func sessionMetric(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline.monospacedDigit())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(CulloraDesign.quiet, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var reviewPipeline: some View {
        PremiumCard {
            VStack(alignment: .leading, spacing: 16) {
                Label("Exact review pipeline", systemImage: "chart.bar.xaxis")
                    .font(.headline)
                pipelineRow("Unreviewed", value: insights.unreviewedGroups, total: insights.totalGroups, color: .gray)
                pipelineRow("In progress", value: insights.inProgressGroups, total: insights.totalGroups, color: .blue)
                pipelineRow("Planned", value: insights.plannedGroups, total: insights.totalGroups, color: .orange)
                pipelineRow("Reviewed without plan", value: insights.completeGroups, total: insights.totalGroups, color: .green)
                Text("Filters in Review Studio let you return directly to unreviewed, planned, or completed sets. Decisions remain stored in the local SQLite ledger across incremental rescans.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var safetyBoundary: some View {
        PremiumCard {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "hand.raised.square.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 6) {
                    Text("Suggestions and cleanup remain separate")
                        .font(.headline)
                    Text("Only byte-identical SHA-256 sets support batch planning. Similar-photo results remain review-only, and every cleanup operation still passes keeper, family, collision, volume, manifest, and restore checks.")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func pipelineRow(_ title: String, value: Int, total: Int, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.callout.weight(.medium))
                Spacer()
                Text("\(value) / \(total)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: Double(value), total: Double(max(1, total)))
                .tint(color == .blue ? CulloraDesign.accent : color)
        }
    }
}
