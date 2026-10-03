@preconcurrency import CoreGraphics
@preconcurrency import Vision
import Foundation

public actor VisualSimilarityAnalyzer {
    public private(set) var skippedPreviewCount = 0
    public init() {}

    public func analyze(
        assets: [UniversalMediaAsset],
        provider: any SimilarityImageProviding,
        allowNetwork: Bool = false,
        threshold: Float = 0.30,
        maximumAssets: Int = .max,
        progress: @escaping @Sendable (_ processed: Int, _ total: Int) -> Void
    ) async throws -> [UniversalSimilarityGroup] {
        let candidates = Array(assets.lazy.filter { $0.mediaKind == .image }.prefix(maximumAssets))
        var clusters: [(representative: VNFeaturePrintObservation?, coarseHash: UInt64, members: [UniversalMediaAsset], maximumDistance: Float)] = []
        skippedPreviewCount = 0
        var bandIndex: [UInt32: Set<Int>] = [:]
        var timeIndex: [Int: Set<Int>] = [:]
        var burstIndex: [String: Set<Int>] = [:]
        var locationIndex: [String: Set<Int>] = [:]
        var descriptors: [String: (feature: VNFeaturePrintObservation?, hash: UInt64)] = [:]
        var qualityByAssetID: [String: VisualQualityReport] = [:]

        for (index, asset) in candidates.enumerated() {
            try Task.checkCancellation()
            progress(index, candidates.count)
            let image: CGImage
            do {
                image = try await provider.similarityImage(
                    for: asset,
                    maximumPixelSize: 384,
                    allowNetwork: allowNetwork
                )
            } catch is CancellationError { throw CancellationError() }
            catch { skippedPreviewCount += 1; continue }
            guard let hash = try? coarseHash(for: image) else { skippedPreviewCount += 1; continue }
            let feature = featurePrint(for: image)
            descriptors[asset.id] = (feature, hash)
            let qualityReport = VisualQualityEngine.evaluateQuality(for: image, asset: asset)
            qualityByAssetID[asset.id] = qualityReport
            
            var bestIndex: Int?
            var bestDistance = Float.greatestFiniteMagnitude
            var bestRank = Float.greatestFiniteMagnitude
            var candidateIndices = Set(bandKeys(for: hash).flatMap { bandIndex[$0] ?? [] })
            let minute = asset.context?.captureTimeIsReliable == true ? asset.context?.captureDate.map { Int($0.timeIntervalSince1970 / 60) } : nil
            if let minute { for bucket in (minute - 1)...(minute + 1) { candidateIndices.formUnion(timeIndex[bucket] ?? []) } }
            if let burst = asset.context?.burstID { candidateIndices.formUnion(burstIndex[burst] ?? []) }
            let locationKeys = nearbyLocationKeys(asset.context?.location)
            for key in locationKeys { candidateIndices.formUnion(locationIndex[key] ?? []) }
            
            for clusterIndex in candidateIndices {
                let rep = clusters[clusterIndex]
                var distance: Float = 1.0
                if let feature, let repFeature = rep.representative {
                    var visionDistance: Float = 0
                    if (try? feature.computeDistance(&visionDistance, to: repFeature)) != nil {
                        distance = visionDistance
                    } else {
                        distance = Float((hash ^ rep.coarseHash).nonzeroBitCount) / 64.0
                    }
                } else {
                    distance = Float((hash ^ rep.coarseHash).nonzeroBitCount) / 64.0
                }
                
                // Every member must still be visually close. This prevents a chain
                // of intermediate shots from merging two distinct scenes.
                var pairwiseMaximum = distance
                for member in rep.members.dropFirst() {
                    guard let descriptor = descriptors[member.id] else { continue }
                    var memberDistance = Float((hash ^ descriptor.hash).nonzeroBitCount) / 64
                    if let feature, let other = descriptor.feature {
                        var measured: Float = 0
                        if (try? feature.computeDistance(&measured, to: other)) != nil { memberDistance = measured }
                    }
                    pairwiseMaximum = max(pairwiseMaximum, memberDistance)
                    if pairwiseMaximum >= threshold { break }
                }
                guard pairwiseMaximum < threshold else { continue }
                let context = SimilarityContext(asset, rep.members[0])
                let rank = distance - context.rankingAdjustment(visualDistance: distance, threshold: threshold)
                if distance < threshold, rank < bestRank {
                    bestDistance = pairwiseMaximum
                    bestRank = rank
                    bestIndex = clusterIndex
                }
            }
            
            if let bestIndex {
                clusters[bestIndex].members.append(asset)
                clusters[bestIndex].maximumDistance = max(clusters[bestIndex].maximumDistance, bestDistance)
                for key in bandKeys(for: hash) { bandIndex[key, default: []].insert(bestIndex) }
                if let minute { timeIndex[minute, default: []].insert(bestIndex) }
                if let burst = asset.context?.burstID { burstIndex[burst, default: []].insert(bestIndex) }
                if let key = locationKeys.first { locationIndex[key, default: []].insert(bestIndex) }
            } else {
                let newIndex = clusters.count
                clusters.append((feature, hash, [asset], 0))
                for key in bandKeys(for: hash) { bandIndex[key, default: []].insert(newIndex) }
                if let minute { timeIndex[minute, default: []].insert(newIndex) }
                if let burst = asset.context?.burstID { burstIndex[burst, default: []].insert(newIndex) }
                if let key = locationKeys.first { locationIndex[key, default: []].insert(newIndex) }
            }
        }

        progress(candidates.count, candidates.count)
        return clusters.enumerated().compactMap { index, cluster in
            guard cluster.members.count > 1 else { return nil }
            let sortedMembers = cluster.members.sorted { lhs, rhs in
                let lhsScore = UniversalKeeperPolicy.qualityScore(for: lhs)
                let rhsScore = UniversalKeeperPolicy.qualityScore(for: rhs)
                if lhsScore != rhsScore { return lhsScore > rhsScore }
                
                let lhsReport = qualityByAssetID[lhs.id]?.compositeScore ?? 0
                let rhsReport = qualityByAssetID[rhs.id]?.compositeScore ?? 0
                if abs(lhsReport - rhsReport) > 2.0 {
                    return lhsReport > rhsReport
                }
                
                let lhsPixels = lhs.pixelWidth * lhs.pixelHeight
                let rhsPixels = rhs.pixelWidth * rhs.pixelHeight
                if lhsPixels != rhsPixels { return lhsPixels > rhsPixels }
                
                let lhsBytes = lhs.byteCount ?? 0
                let rhsBytes = rhs.byteCount ?? 0
                if lhsBytes != rhsBytes { return lhsBytes > rhsBytes }
                
                let lhsDate = lhs.creationDate ?? lhs.modificationDate ?? .distantFuture
                let rhsDate = rhs.creationDate ?? rhs.modificationDate ?? .distantFuture
                return lhsDate < rhsDate
            }
            return UniversalSimilarityGroup(
                id: "similar:" + StableDigest.fnv1a64(sortedMembers.map(\.id).sorted().joined(separator: "|")),
                assets: sortedMembers,
                maximumDistance: cluster.maximumDistance,
                keeperID: sortedMembers.first?.id
            )
        }
    }

    private func featurePrint(for image: CGImage) -> VNFeaturePrintObservation? {
        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = VNGenerateImageFeaturePrintRequestRevision1
        request.imageCropAndScaleOption = .scaleFit
        do {
            try VNImageRequestHandler(cgImage: image, options: [:]).perform([request])
            return request.results?.first as? VNFeaturePrintObservation
        } catch {
            return nil
        }
    }

    private func coarseHash(for image: CGImage) throws -> UInt64 {
        let width = 9
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { throw UniversalScanError.inaccessibleAsset("image preview") }
        context.interpolationQuality = .low
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        var hash: UInt64 = 0
        for row in 0..<height {
            for column in 0..<(width - 1) {
                hash <<= 1
                if pixels[row * width + column] > pixels[row * width + column + 1] { hash |= 1 }
            }
        }
        return hash
    }

    private func nearbyLocationKeys(_ location: MediaLocation?) -> [String] {
        guard let location, location.latitude.isFinite, location.longitude.isFinite,
              abs(location.latitude) <= 90, abs(location.longitude) <= 180 else { return [] }
        let lat = Int(floor(location.latitude * 1_000)), lon = Int(floor(location.longitude * 1_000))
        var keys = ["\(lat):\(lon)"]
        for a in -1...1 { for b in -1...1 where a != 0 || b != 0 { keys.append("\(lat + a):\(lon + b)") } }
        return keys
    }

    private func bandKeys(for hash: UInt64) -> [UInt32] {
        (0..<4).map { band in
            let value = UInt32((hash >> UInt64(band * 16)) & 0xffff)
            return (UInt32(band) << 16) | value
        }
    }
}
