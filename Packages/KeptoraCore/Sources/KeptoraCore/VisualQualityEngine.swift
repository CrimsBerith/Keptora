@preconcurrency import CoreGraphics
@preconcurrency import Vision
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
        case .sharpestFocus: return String(localized: "Sharpest Focus")
        case .optimalExposure: return String(localized: "Balanced Light")
        case .eyesOpen: return String(localized: "Best Expression")
        case .highDynamicRange: return String(localized: "High Dynamic Range")
        case .proRawOriginal: return String(localized: "RAW Quality")
        case .highResolution: return String(localized: "Highest Resolution")
        }
    }
    
    public var iconName: String {
        switch self {
        case .sharpestFocus: return "sparkle.magnifyingglass"
        case .optimalExposure: return "sun.max.fill"
        case .eyesOpen: return "eye.fill"
        case .highDynamicRange: return "camera.aperture"
        case .proRawOriginal: return "raw.fill"
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
    public let badges: [VisualQualityBadge]
    
    public init(
        assetID: String,
        sharpnessScore: Float,
        exposureScore: Float,
        faceScore: Float,
        formatBonus: Float,
        compositeScore: Float,
        badges: [VisualQualityBadge]
    ) {
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
        let width = min(image.width, 256)
        let height = min(image.height, 256)
        guard width > 8, height > 8 else {
            return VisualQualityReport(
                assetID: asset.id,
                sharpnessScore: 0,
                exposureScore: 50,
                faceScore: 0,
                formatBonus: 0,
                compositeScore: 20,
                badges: []
            )
        }
        
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return VisualQualityReport(
                assetID: asset.id,
                sharpnessScore: 0,
                exposureScore: 50,
                faceScore: 0,
                formatBonus: 0,
                compositeScore: 20,
                badges: []
            )
        }
        
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 1. Sharpness & Edge Clarity (Sobel gradient density)
        var sumGradient: Double = 0
        var countGradient: Double = 0
        var sumLuminance: Double = 0
        
        for y in 1..<(height - 1) {
            let row = y * width
            let prev = (y - 1) * width
            let next = (y + 1) * width
            for x in 1..<(width - 1) {
                let p = Double(pixels[row + x])
                sumLuminance += p
                let gx = abs(Int(pixels[row + x + 1]) - Int(pixels[row + x - 1]))
                let gy = abs(Int(pixels[next + x]) - Int(pixels[prev + x]))
                sumGradient += Double(gx + gy)
                countGradient += 1
            }
        }
        
        let meanGradient = countGradient > 0 ? (sumGradient / countGradient) : 0
        let rawSharpness = Float(min(100.0, max(0.0, (meanGradient / 14.0) * 100.0)))
        
        // 2. Exposure & Dynamic Range Balance
        let meanLum = countGradient > 0 ? (sumLuminance / (countGradient * 255.0)) : 0.5
        let exposureDiff = abs(meanLum - 0.52)
        let rawExposure = Float(max(0.0, min(100.0, (1.0 - (exposureDiff * 2.2)) * 100.0)))
        
        // 3. Face & Expression Quality (Vision API)
        var faceScore: Float = 0
        var hasDetectedFace = false
        var eyesOpenDetected = false
        
        let faceRequest = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        if let _ = try? handler.perform([faceRequest]),
           let results = faceRequest.results, !results.isEmpty {
            hasDetectedFace = true
            faceScore = 60.0
            
            if let firstFace = results.first, firstFace.confidence > 0.5 {
                let landmarkRequest = VNDetectFaceLandmarksRequest()
                landmarkRequest.inputFaceObservations = [firstFace]
                if let _ = try? handler.perform([landmarkRequest]),
                   let landmarkResults = landmarkRequest.results,
                   let landmarks = landmarkResults.first?.landmarks,
                   let leftEye = landmarks.leftEye, let rightEye = landmarks.rightEye,
                   leftEye.pointCount > 0, rightEye.pointCount > 0 {
                    eyesOpenDetected = true
                    faceScore = min(100.0, faceScore + 35.0)
                }
            }
        }
        
        // 4. Format & Resolution Bonus
        var formatBonus: Float = 0
        let ext = (asset.displayName as NSString).pathExtension.lowercased()
        let isRaw = ["cr2", "cr3", "nef", "arw", "dng", "raw", "raf", "orf", "rw2"].contains(ext)
        if isRaw { formatBonus += 10.0 }
        if asset.pixelWidth >= 3840 || asset.pixelHeight >= 2160 { formatBonus += 5.0 }
        
        // 5. Composite Weighted Quality Score (0 - 100)
        let composite: Float
        if hasDetectedFace {
            composite = min(100.0, (rawSharpness * 0.35) + (rawExposure * 0.25) + (faceScore * 0.30) + formatBonus)
        } else {
            composite = min(100.0, (rawSharpness * 0.55) + (rawExposure * 0.35) + formatBonus)
        }
        
        // 6. Generate Badges
        var badges: [VisualQualityBadge] = []
        if rawSharpness >= 65.0 { badges.append(.sharpestFocus) }
        if rawExposure >= 75.0 { badges.append(.optimalExposure) }
        if eyesOpenDetected { badges.append(.eyesOpen) }
        if isRaw { badges.append(.proRawOriginal) }
        if asset.pixelWidth >= 3840 || asset.pixelHeight >= 2160 { badges.append(.highResolution) }
        
        return VisualQualityReport(
            assetID: asset.id,
            sharpnessScore: rawSharpness,
            exposureScore: rawExposure,
            faceScore: faceScore,
            formatBonus: formatBonus,
            compositeScore: composite,
            badges: badges
        )
    }
}
