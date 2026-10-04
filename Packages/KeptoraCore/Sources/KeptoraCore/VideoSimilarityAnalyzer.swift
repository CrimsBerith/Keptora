@preconcurrency import AVFoundation
@preconcurrency import Vision
import CoreGraphics
import Foundation

enum UniversalVideoFrameSampler {
    static func sample(
        avAsset: AVAsset,
        maximumPixelSize: Int
    ) async throws -> UniversalVideoSimilaritySample {
        let duration = try await avAsset.load(.duration)
        let seconds = duration.seconds
        guard seconds.isFinite, seconds > 0 else {
            throw UniversalScanError.inaccessibleAsset("video duration")
        }

        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: maximumPixelSize, height: maximumPixelSize)
        generator.requestedTimeToleranceBefore = CMTime(seconds: 0.25, preferredTimescale: 600)
        generator.requestedTimeToleranceAfter = CMTime(seconds: 0.25, preferredTimescale: 600)

        let fractions: [Double] = seconds < 2 ? [0.5] : [0.12, 0.50, 0.88]
        var frames: [CGImage] = []
        for fraction in fractions {
            try Task.checkCancellation()
            let time = CMTime(seconds: max(0, seconds * fraction), preferredTimescale: 600)
            let result = try await generator.image(at: time)
            frames.append(result.image)
        }
        guard let first = frames.first else {
            throw UniversalScanError.inaccessibleAsset("video preview")
        }
        return UniversalVideoSimilaritySample(
            duration: seconds,
            pixelWidth: first.width,
            pixelHeight: first.height,
            frames: frames
        )
    }
}

public actor VideoSimilarityAnalyzer {
    public private(set) var issues: [AnalysisIssue] = []
    private struct Signature {
        let asset: UniversalMediaAsset
        let duration: TimeInterval
        let aspectRatio: Double
        let features: [VNFeaturePrintObservation]
    }

    public init() {}

    public func analyze(
        assets: [UniversalMediaAsset],
        provider: any SimilarityVideoProviding,
        allowNetwork: Bool = false,
        averageThreshold: Float = 0.31,
        maximumFrameDistance: Float = 0.48,
        maximumAssets: Int = .max,
        progress: @escaping @Sendable (_ processed: Int, _ total: Int) -> Void
    ) async throws -> [UniversalSimilarityGroup] {
        let candidates = Array(assets.lazy.filter { $0.mediaKind == .video }.prefix(maximumAssets))
        issues = []
        var clusters: [(representative: Signature, members: [UniversalMediaAsset], maximumDistance: Float)] = []
        var durationIndex: [Int: Set<Int>] = [:]

        for (offset, asset) in candidates.enumerated() {
            try Task.checkCancellation()
            progress(offset, candidates.count)
            let sample: UniversalVideoSimilaritySample
            do {
                sample = try await provider.similarityVideoSample(
                    for: asset,
                    maximumPixelSize: 320,
                    allowNetwork: allowNetwork
                )
            } catch is CancellationError { throw CancellationError() }
            catch {
                issues.append(.init(asset: asset, stage: .videos, error: error))
                continue
            }
            let features = sample.frames.compactMap(featurePrint)
            guard !features.isEmpty else { issues.append(.init(assetID: asset.id, sourceID: asset.sourceID, stage: .videos, reason: .unreadable)); continue }
            
            let signature = Signature(
                asset: asset,
                duration: sample.duration,
                aspectRatio: Double(sample.pixelWidth) / Double(max(sample.pixelHeight, 1)),
                features: features
            )
            let bucket = durationBucket(sample.duration)
            let possible = Set((-1...1).flatMap { durationIndex[bucket + $0] ?? [] })
            var best: (index: Int, distance: Float)?

            for index in possible {
                let representative = clusters[index].representative
                guard durationMatches(signature.duration, representative.duration),
                      abs(signature.aspectRatio - representative.aspectRatio) <= 0.08,
                      signature.features.count == representative.features.count else { continue }
                let distances = zip(signature.features, representative.features).compactMap { lhs, rhs -> Float? in
                    var distance: Float = 0
                    guard (try? lhs.computeDistance(&distance, to: rhs)) != nil else { return nil }
                    return distance
                }
                guard distances.count == signature.features.count,
                      let largest = distances.max(), largest <= maximumFrameDistance else { continue }
                let average = distances.reduce(0, +) / Float(max(distances.count, 1))
                guard average <= averageThreshold else { continue }
                if average < (best?.distance ?? .infinity) { best = (index, average) }
            }

            if let best {
                clusters[best.index].members.append(asset)
                clusters[best.index].maximumDistance = max(clusters[best.index].maximumDistance, best.distance)
            } else {
                let index = clusters.count
                clusters.append((signature, [asset], 0))
                durationIndex[bucket, default: []].insert(index)
            }
        }

        progress(candidates.count, candidates.count)
        return clusters.enumerated().compactMap { index, cluster in
            guard cluster.members.count > 1 else { return nil }
            return UniversalSimilarityGroup(
                id: "similar-video:\(index):\(cluster.members.first?.id ?? "")",
                assets: cluster.members,
                maximumDistance: cluster.maximumDistance,
                mediaKind: .video
            )
        }
    }

    private func featurePrint(_ image: CGImage) -> VNFeaturePrintObservation? {
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

    private func durationBucket(_ duration: TimeInterval) -> Int { Int((duration / 2).rounded()) }

    private func durationMatches(_ lhs: TimeInterval, _ rhs: TimeInterval) -> Bool {
        abs(lhs - rhs) <= max(1.5, max(lhs, rhs) * 0.08)
    }
}
