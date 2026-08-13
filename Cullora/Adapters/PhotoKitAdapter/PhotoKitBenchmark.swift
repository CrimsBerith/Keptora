import Foundation
import Photos

struct PhotoKitBenchmarkResult: Codable, Sendable {
    let authorization: String
    let fetchedAssets: Int
    let elapsedSeconds: Double
    let assetsPerSecond: Double
}

actor PhotoKitBenchmark {
    func run(limit: Int? = nil) async -> PhotoKitBenchmarkResult {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        let clock = ContinuousClock()
        let started = clock.now
        let result = PHAsset.fetchAssets(with: nil)
        let count = min(limit ?? result.count, result.count)
        for index in 0..<count { _ = result.object(at: index).localIdentifier }
        let duration = started.duration(to: clock.now)
        let seconds = Double(duration.components.seconds) + Double(duration.components.attoseconds) / 1e18
        return PhotoKitBenchmarkResult(
            authorization: String(describing: status),
            fetchedAssets: count,
            elapsedSeconds: seconds,
            assetsPerSecond: seconds > 0 ? Double(count) / seconds : 0
        )
    }
}
