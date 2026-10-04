@preconcurrency import CoreGraphics
@preconcurrency import Vision
import Foundation

public actor VisualSimilarityAnalyzer {
    private typealias Cluster = (representative: VNFeaturePrintObservation?, coarseHash: UInt64, members: [UniversalMediaAsset], maximumDistance: Float, visionOnly: Bool)
    public private(set) var skippedPreviewCount = 0
    public private(set) var metrics = AnalysisWorkMetrics()
    public private(set) var qualityAssessments: [String: QualityAssessment] = [:]
    public private(set) var issues: [AnalysisIssue] = []
    public init() {}

    public func analyze(
        assets: [UniversalMediaAsset],
        provider: any SimilarityImageProviding,
        allowNetwork: Bool = false,
        threshold: Float = 0.30,
        maximumAssets: Int = .max,
        groupsUpdate: @escaping @Sendable ([UniversalSimilarityGroup]) -> Void = { _ in },
        findings: @escaping @Sendable ([String: QualityAssessment], [AnalysisIssue]) -> Void = { _, _ in },
        progress: @escaping @Sendable (_ processed: Int, _ total: Int) -> Void
    ) async throws -> [UniversalSimilarityGroup] {
        let candidates = Array(assets.lazy.filter { $0.mediaKind == .image }.prefix(maximumAssets))
        var clusters: [Cluster] = []
        skippedPreviewCount = 0
        metrics = .init()
        qualityAssessments = [:]; issues = []
        var bandIndex: [UInt32: Set<Int>] = [:]
        var timeIndex: [Int: Set<Int>] = [:]
        var burstIndex: [String: Set<Int>] = [:]
        var locationIndex: [String: Set<Int>] = [:]
        var descriptors: [String: (feature: VNFeaturePrintObservation?, hash: UInt64)] = [:]
        var qualityByAssetID: [String: VisualQualityReport] = [:]

        for (index, asset) in candidates.enumerated() {
            try Task.checkCancellation()
            progress(index, candidates.count)
            let value: (feature: VNFeaturePrintObservation?, hash: UInt64, quality: QualityAssessment)
            do { value = try await descriptor(for: asset, provider: provider, allowNetwork: allowNetwork) }
            catch is CancellationError { throw CancellationError() }
            catch {
                skippedPreviewCount += 1
                issues.append(.init(asset: asset, stage: .photos, error: error))
                qualityAssessments[asset.id] = .unavailable
                if index % 50 == 0 { findings(qualityAssessments, issues) }
                continue
            }
            let feature = value.feature, hash = value.hash
            descriptors[asset.id] = (feature, hash)
            qualityByAssetID[asset.id] = VisualQualityReport(assetID: asset.id,
                sharpnessScore: Float(value.quality.detailScore), exposureScore: Float(value.quality.exposureScore),
                faceScore: 0, formatBonus: 0, compositeScore: Float(value.quality.score ?? 0), badges: [], assessment: value.quality)
            qualityAssessments[asset.id] = value.quality
            if index % 50 == 0 { findings(qualityAssessments, issues) }
            
            var bestIndex: Int?
            var bestDistance = Float.greatestFiniteMagnitude
            var bestRank = Float.greatestFiniteMagnitude
            var bestVisionOnly = false
            var candidateIndices = Set(bandKeys(for: hash, neighbors: true).flatMap { bandIndex[$0] ?? [] })
            let minute = asset.context?.captureTimeIsReliable == true ? asset.context?.captureDate.map { Int($0.timeIntervalSince1970 / 60) } : nil
            if let minute { for bucket in (minute - 1)...(minute + 1) { candidateIndices.formUnion(timeIndex[bucket] ?? []) } }
            if let burst = asset.context?.burstID { candidateIndices.formUnion(burstIndex[burst] ?? []) }
            let locationKeys = nearbyLocationKeys(asset.context?.location)
            for key in locationKeys { candidateIndices.formUnion(locationIndex[key] ?? []) }
            
            for clusterIndex in candidateIndices {
                let rep = clusters[clusterIndex]
                let fallbackThreshold: Float = 0.08
                var distance: Float = 1.0
                var comparisonThreshold = fallbackThreshold
                var visionOnly = false
                if let feature, let repFeature = rep.representative {
                    var visionDistance: Float = 0
                    if (try? feature.computeDistance(&visionDistance, to: repFeature)) != nil, visionDistance.isFinite, visionDistance >= 0 {
                        distance = visionDistance
                        comparisonThreshold = max(0.01, threshold)
                        visionOnly = true
                    } else {
                        distance = Float((hash ^ rep.coarseHash).nonzeroBitCount) / 64.0
                    }
                } else {
                    distance = Float((hash ^ rep.coarseHash).nonzeroBitCount) / 64.0
                }
                
                // Every member must still be visually close. This prevents a chain
                // of intermediate shots from merging two distinct scenes.
                guard visionOnly || qualityAssessments[asset.id]?.state == .evaluated else { continue }
                let aspect = Double(asset.pixelWidth) / Double(max(1, asset.pixelHeight))
                let repAspect = Double(rep.members[0].pixelWidth) / Double(max(1, rep.members[0].pixelHeight))
                guard abs(aspect - repAspect) < max(0.12, repAspect * 0.15) else { continue }
                var pairwiseMaximum = distance / comparisonThreshold
                // Zero Vision distance means the same feature vector. Existing
                // pairwise bounds still apply without rechecking every identical copy.
                let identicalVector = visionOnly && distance == 0 && rep.visionOnly
                for member in rep.members.dropFirst() where !identicalVector {
                    guard let descriptor = descriptors[member.id] else { continue }
                    var memberDistance = Float((hash ^ descriptor.hash).nonzeroBitCount) / 64
                    var memberThreshold = fallbackThreshold
                    if let feature, let other = descriptor.feature {
                        var measured: Float = 0
                        if (try? feature.computeDistance(&measured, to: other)) != nil, measured.isFinite, measured >= 0 { memberDistance = measured; memberThreshold = max(0.01, threshold) } else { visionOnly = false }
                    }
                    if feature == nil || descriptor.feature == nil { visionOnly = false }
                    pairwiseMaximum = max(pairwiseMaximum, memberDistance / memberThreshold)
                    if pairwiseMaximum >= 1 { break }
                }
                guard pairwiseMaximum < 1 else { continue }
                let context = SimilarityContext(asset, rep.members[0])
                let rank = distance - context.rankingAdjustment(visualDistance: distance, threshold: threshold)
                if distance < comparisonThreshold, rank < bestRank {
                    bestDistance = pairwiseMaximum
                    bestRank = rank
                    bestIndex = clusterIndex
                    bestVisionOnly = visionOnly
                }
            }
            
            if let bestIndex {
                clusters[bestIndex].members.append(asset)
                clusters[bestIndex].visionOnly = clusters[bestIndex].visionOnly && bestVisionOnly
                clusters[bestIndex].maximumDistance = max(clusters[bestIndex].maximumDistance, bestDistance)
                for key in bandKeys(for: hash) { bandIndex[key, default: []].insert(bestIndex) }
                if let minute { timeIndex[minute, default: []].insert(bestIndex) }
                if let burst = asset.context?.burstID { burstIndex[burst, default: []].insert(bestIndex) }
                if let key = locationKeys.first { locationIndex[key, default: []].insert(bestIndex) }
            } else {
                let newIndex = clusters.count
                clusters.append((feature, hash, [asset], 0, feature != nil))
                for key in bandKeys(for: hash) { bandIndex[key, default: []].insert(newIndex) }
                if let minute { timeIndex[minute, default: []].insert(newIndex) }
                if let burst = asset.context?.burstID { burstIndex[burst, default: []].insert(newIndex) }
                if let key = locationKeys.first { locationIndex[key, default: []].insert(newIndex) }
            }
            if index % 50 == 0 { groupsUpdate(Self.groups(clusters, qualityByAssetID: qualityByAssetID)) }
        }

        progress(candidates.count, candidates.count)
        findings(qualityAssessments, issues)
        return Self.groups(clusters, qualityByAssetID: qualityByAssetID)
    }

    private static func groups(_ clusters: [Cluster], qualityByAssetID: [String: VisualQualityReport]) -> [UniversalSimilarityGroup] {
        return clusters.compactMap { cluster in
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
                strength: cluster.visionOnly && cluster.maximumDistance <= 0.4 ? .verySimilar : .similar,
                keeperID: sortedMembers.first?.id
            )
        }
    }

    private func descriptor(for asset: UniversalMediaAsset, provider: any SimilarityImageProviding,
                            allowNetwork: Bool) async throws -> (feature: VNFeaturePrintObservation?, hash: UInt64, quality: QualityAssessment) {
        if let cached = await MediaFingerprintDiskCache.shared.get(asset: asset, algorithm: MediaAnalysisVersion.visual),
           let hash = cached.coarseHash, let quality = cached.quality,
           let data = cached.featurePrintData,
           let feature = try? NSKeyedUnarchiver.unarchivedObject(ofClass: VNFeaturePrintObservation.self, from: data) {
            metrics.cacheHits += 1
            return (feature, hash, quality)
        }
        metrics.decodedPreviews += 1
        let image = try await provider.similarityImage(for: asset, maximumPixelSize: 384, allowNetwork: allowNetwork)
        try Task.checkCancellation()
        metrics.featurePrintRequests += 1
        let value = try autoreleasepool { () throws -> (VNFeaturePrintObservation?, UInt64, QualityAssessment) in
            (featurePrint(for: image), try coarseHash(for: image), VisualQualityEngine.evaluateQuality(for: image, asset: asset).assessment ?? .unavailable)
        }
        let data = value.0.flatMap { try? NSKeyedArchiver.archivedData(withRootObject: $0, requiringSecureCoding: true) }
        var entry = MediaFingerprintDiskCache.CacheEntry(assetID: asset.id, digest: "", byteCount: asset.byteCount ?? 0,
                                                        coarseHash: value.1, featurePrintData: data)
        entry.quality = value.2
        await MediaFingerprintDiskCache.shared.store(asset: asset, algorithm: MediaAnalysisVersion.visual, entry: entry)
        return (value.0, value.1, value.2)
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

    private func bandKeys(for hash: UInt64, neighbors: Bool = false) -> [UInt32] {
        (0..<8).flatMap { band -> [UInt32] in
            let value = UInt32((hash >> UInt64(band * 8)) & 0xff)
            let prefix = UInt32(band) << 8
            return [prefix | value] + (neighbors ? (0..<8).map { prefix | (value ^ (1 << $0)) } : [])
        }
    }
}
