import Foundation

struct SimilarityGroupBuilder: Sendable {
    let maximumMembersPerGroup: Int

    init(maximumMembersPerGroup: Int = 12) {
        self.maximumMembersPerGroup = maximumMembersPerGroup
    }

    func build(
        pairs: [SimilarityPairRecord],
        assets: [AssetID: ReviewAsset],
        profile: SimilarityCalibrationProfile
    ) -> [SimilarityReviewGroup] {
        let eligible = pairs.filter { $0.distance <= profile.reviewMaximum }
        var adjacency: [AssetID: [(AssetID, Float)]] = [:]
        for pair in eligible {
            adjacency[pair.firstAssetID, default: []].append((pair.secondAssetID, pair.distance))
            adjacency[pair.secondAssetID, default: []].append((pair.firstAssetID, pair.distance))
        }

        let anchors = adjacency.keys.sorted { lhs, rhs in
            let left = adjacency[lhs]?.count ?? 0
            let right = adjacency[rhs]?.count ?? 0
            return left == right ? lhs.rawValue < rhs.rawValue : left > right
        }
        var assigned: Set<AssetID> = []
        var groups: [SimilarityReviewGroup] = []

        for anchorID in anchors where !assigned.contains(anchorID) {
            guard let anchorAsset = assets[anchorID] else { continue }
            let neighbors = (adjacency[anchorID] ?? [])
                .filter { !assigned.contains($0.0) && assets[$0.0] != nil }
                .sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.0.rawValue < rhs.0.rawValue : lhs.1 < rhs.1 }
                .prefix(maximumMembersPerGroup - 1)
            guard !neighbors.isEmpty else { continue }

            var members = [SimilarityReviewMember(asset: anchorAsset, distanceToAnchor: 0)]
            for (assetID, distance) in neighbors {
                guard let asset = assets[assetID] else { continue }
                members.append(SimilarityReviewMember(asset: asset, distanceToAnchor: distance))
            }
            guard members.count > 1 else { continue }

            let maximumDistance = members.map(\.distanceToAnchor).max() ?? 0
            guard let tier = profile.tier(for: maximumDistance) else { continue }
            let memberIDs = members.map { $0.asset.id.rawValue }.sorted().joined(separator: "|")
            let id = "similar:\(stableDigest(profile.id + "|" + memberIDs))"
            groups.append(
                SimilarityReviewGroup(
                    id: id,
                    anchorAssetID: anchorID,
                    tier: tier,
                    maximumDistance: maximumDistance,
                    profileID: profile.id,
                    isCalibrated: profile.isCalibrated,
                    members: members
                )
            )
            assigned.formUnion(members.map { $0.asset.id })
        }

        return groups.sorted { lhs, rhs in
            if lhs.tier != rhs.tier {
                return tierRank(lhs.tier) < tierRank(rhs.tier)
            }
            if lhs.maximumDistance != rhs.maximumDistance { return lhs.maximumDistance < rhs.maximumDistance }
            return lhs.id < rhs.id
        }
    }

    private func tierRank(_ tier: SimilarityTier) -> Int {
        switch tier {
        case .veryStrong: return 0
        case .strong: return 1
        case .review: return 2
        }
    }

    private func stableDigest(_ value: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }
}
