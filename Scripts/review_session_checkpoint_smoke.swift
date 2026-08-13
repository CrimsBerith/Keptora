import Foundation

@main
struct ReviewSessionCheckpointSmoke {
    static func main() throws {
        let start = Date(timeIntervalSince1970: 10_000)
        let checkpoint = ReviewSessionCheckpoint(
            sourceID: SourceID(rawValue: "source-demo"),
            sourceName: "Demo Library",
            groupID: "group-4",
            focusedAssetID: AssetID(rawValue: "asset-2"),
            groupPosition: 4,
            totalGroups: 8,
            reviewedAssets: 30,
            completedGroups: 5,
            plannedBytes: 2_000_000,
            startedAt: start,
            updatedAt: start.addingTimeInterval(150)
        )
        let data = try JSONEncoder().encode(checkpoint)
        let decoded = try JSONDecoder().decode(ReviewSessionCheckpoint.self, from: data)
        precondition(decoded == checkpoint)
        precondition(abs(decoded.progressFraction - 0.625) < 0.0001)
        precondition(abs(decoded.reviewedPerMinute - 12) < 0.0001)
        precondition(decoded.positionLabel == "Group 4 of 8")
        print("Phase 5M review-session checkpoint smoke passed.")
    }
}
