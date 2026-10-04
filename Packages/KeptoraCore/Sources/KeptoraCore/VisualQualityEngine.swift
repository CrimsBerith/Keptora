@preconcurrency import CoreGraphics
import Foundation

/// Quality badges displayed in UI to explain why an asset is chosen as the keeper.
public enum VisualQualityBadge: String, Codable, Sendable, CaseIterable {
    case sharpestFocus = "sharpest_focus"
    case optimalExposure = "optimal_exposure"
    case eyesOpen = "eyes_open"
    case highDynamicRange = "high_dynamic_range"
    case proRawOriginal = "proraw_original"
    case highResolution = "high_resolution"
    
    public var title: String {
        switch self {
        case .sharpestFocus: return L10n.tr("Sharpest Focus")
        case .optimalExposure: return L10n.tr("Balanced Light")
        case .eyesOpen: return L10n.tr("Best Expression")
        case .highDynamicRange: return L10n.tr("High Dynamic Range")
        case .proRawOriginal: return L10n.tr("RAW Quality")
        case .highResolution: return L10n.tr("Highest Resolution")
        }
    }
    
    public var iconName: String {
        switch self {
        case .sharpestFocus: return "sparkle.magnifyingglass"
        case .optimalExposure: return "sun.max.fill"
        case .eyesOpen: return "eye.fill"
        case .highDynamicRange: return "camera.aperture"
        case .proRawOriginal: return "camera"
        case .highResolution: return "arrow.up.left.and.arrow.down.right"
        }
    }
}

/// Comprehensive visual quality assessment report for an image asset.
public struct VisualQualityReport: Codable, Sendable, Hashable {
    public let assetID: String
    public let sharpnessScore: Float       // 0 - 100
    public let exposureScore: Float        // 0 - 100
    public let faceScore: Float            // 0 - 100
    public let formatBonus: Float          // 0 - 20
    public let compositeScore: Float       // 0 - 100
    public let assessment: QualityAssessment?
    public let badges: [VisualQualityBadge]
    
    public init(
        assetID: String,
        sharpnessScore: Float,
        exposureScore: Float,
        faceScore: Float,
        formatBonus: Float,
        compositeScore: Float,
        badges: [VisualQualityBadge],
        assessment: QualityAssessment? = nil
    ) {
        self.assessment = assessment
        self.assetID = assetID
        self.sharpnessScore = sharpnessScore
        self.exposureScore = exposureScore
        self.faceScore = faceScore
        self.formatBonus = formatBonus
        self.compositeScore = compositeScore
        self.badges = badges
    }
}

/// On-device multi-factor visual quality evaluator.
public enum VisualQualityEngine: Sendable {
    
    /// Evaluates visual quality of an image against key photographic standards.
    public static func evaluateQuality(
        for image: CGImage,
        asset: UniversalMediaAsset
    ) -> VisualQualityReport {
        let size = QualityAssessment.sampleSize(width: image.width, height: image.height)
        let width = size.width, height = size.height
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard width > 8, height > 8, let context = CGContext(data: &pixels, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width, space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue) else {
            return VisualQualityReport(assetID: asset.id, sharpnessScore: 0, exposureScore: 0,
                faceScore: 0, formatBonus: 0, compositeScore: 0, badges: [], assessment: .unavailable)
        }
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let assessment = QualityAssessment.evaluate(luma: pixels, width: width, height: height,
            originalWidth: asset.pixelWidth, originalHeight: asset.pixelHeight)
        return VisualQualityReport(assetID: asset.id, sharpnessScore: Float(assessment.detailScore),
            exposureScore: Float(assessment.exposureScore), faceScore: 0, formatBonus: 0,
            compositeScore: Float(assessment.score ?? 0), badges: [], assessment: assessment)
    }
}
