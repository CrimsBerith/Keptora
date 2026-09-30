import Foundation

/// Represents a rapid succession / burst shot cluster where multiple similar photos were taken in seconds.
public struct BurstSequenceGroup: Identifiable, Hashable, Codable, Sendable {
    public let id: String
    public let assets: [UniversalMediaAsset]
    public let keeperID: String
    public let timeSpanSeconds: Double
    
    public init(
        id: String,
        assets: [UniversalMediaAsset],
        keeperID: String,
        timeSpanSeconds: Double
    ) {
        self.id = id
        self.assets = assets
        self.keeperID = keeperID
        self.timeSpanSeconds = timeSpanSeconds
    }
    
    public var keeper: UniversalMediaAsset? {
        assets.first { $0.id == keeperID }
    }
    
    public var removableCopies: [UniversalMediaAsset] {
        assets.filter { $0.id != keeperID && !$0.isProtectedFromGlobalSelection }
    }
    
    public var reclaimableBytes: Int64 {
        removableCopies.reduce(0) { $0 + ($1.byteCount ?? 0) }
    }
}

/// Analyzer for detecting rapid sequential bursts and selecting the single sharpest keeper.
public enum BurstSequenceAnalyzer: Sendable {
    
    /// Groups images captured within `maximumInterval` (default: 2.5s) of adjacent photos.
    public static func analyzeBursts(
        assets: [UniversalMediaAsset],
        maximumInterval: TimeInterval = 2.5
    ) -> [BurstSequenceGroup] {
        let datedAssets = assets
            .filter { $0.mediaKind == .image && $0.creationDate != nil }
            .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        
        guard datedAssets.count > 1 else { return [] }
        
        var clusters: [[UniversalMediaAsset]] = []
        var currentCluster: [UniversalMediaAsset] = [datedAssets[0]]
        
        for i in 1..<datedAssets.count {
            let prev = datedAssets[i - 1]
            let curr = datedAssets[i]
            
            let timeDiff = (curr.creationDate ?? .distantFuture).timeIntervalSince(prev.creationDate ?? .distantPast)
            
            // Check if within rapid sequence window and same dimension aspect ratio
            let aspectPrev = Float(prev.pixelWidth) / Float(max(prev.pixelHeight, 1))
            let aspectCurr = Float(curr.pixelWidth) / Float(max(curr.pixelHeight, 1))
            let sameAspect = abs(aspectPrev - aspectCurr) < 0.05
            
            if timeDiff <= maximumInterval && sameAspect {
                currentCluster.append(curr)
            } else {
                if currentCluster.count >= 2 {
                    clusters.append(currentCluster)
                }
                currentCluster = [curr]
            }
        }
        
        if currentCluster.count >= 2 {
            clusters.append(currentCluster)
        }
        
        return clusters.enumerated().map { index, cluster in
            let sortedMembers = cluster.sorted { lhs, rhs in
                let lhsScore = UniversalKeeperPolicy.qualityScore(for: lhs)
                let rhsScore = UniversalKeeperPolicy.qualityScore(for: rhs)
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                
                let lhsPixels = lhs.pixelWidth * lhs.pixelHeight
                let rhsPixels = rhs.pixelWidth * rhs.pixelHeight
                if lhsPixels != rhsPixels { return lhsPixels > rhsPixels }
                
                let lhsBytes = lhs.byteCount ?? 0
                let rhsBytes = rhs.byteCount ?? 0
                return lhsBytes > rhsBytes
            }
            
            let startTime = cluster.first?.creationDate ?? Date()
            let endTime = cluster.last?.creationDate ?? Date()
            let span = max(0.1, endTime.timeIntervalSince(startTime))
            
            return BurstSequenceGroup(
                id: "burst:\(index):\(sortedMembers.first?.id ?? "")",
                assets: sortedMembers,
                keeperID: sortedMembers.first?.id ?? "",
                timeSpanSeconds: span
            )
        }
    }
}
