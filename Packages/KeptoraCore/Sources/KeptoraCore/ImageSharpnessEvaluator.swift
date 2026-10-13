import CoreGraphics
import Foundation

/// Shared preview detail metric; focus remains a review hint.
public enum ImageSharpnessEvaluator: Sendable {
    public static func evaluateSharpness(for image: CGImage) -> Float {
        let asset = UniversalMediaAsset(id: "preview", sourceID: "preview", reference: .photoLibrary(localIdentifier: "preview"),
                                        displayName: "preview", mediaKind: .image, pixelWidth: image.width, pixelHeight: image.height)
        let report = VisualQualityEngine.evaluateQuality(for: image, asset: asset)
        return report.assessment?.state == .evaluated ? report.sharpnessScore : 0
    }
}
