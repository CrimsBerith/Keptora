import Foundation

/// Preview measurements are review hints, never a reason to delete automatically.
public struct QualityAssessment: Codable, Hashable, Sendable {
    public enum State: String, Codable, Sendable { case evaluated, insufficientDetail, unavailable }
    public enum Finding: String, Codable, Sendable, CaseIterable {
        case possibleBlur, lowResolution, dark, bright
        public var titleKey: String {
            switch self {
            case .possibleBlur: return "Possibly Blurry"
            case .lowResolution: return "Low Resolution"
            case .dark: return "Very Dark"
            case .bright: return "Very Bright"
            }
        }
        public var symbol: String {
            switch self {
            case .possibleBlur: return "camera.metering.center.weighted"
            case .lowResolution: return "arrow.down.right.and.arrow.up.left"
            case .dark: return "moon.fill"
            case .bright: return "sun.max.fill"
            }
        }
    }
    public let state: State
    public let findings: [Finding]
    public let detailScore: Double
    public let exposureScore: Double
    public var needsReview: Bool { !findings.isEmpty }
    public var score: Double? { state == .evaluated ? detailScore * 0.7 + exposureScore * 0.3 : nil }
    public static let unavailable = Self(state: .unavailable, findings: [], detailScore: 0, exposureScore: 0)

    public static func sampleSize(width: Int, height: Int, maximum: Int = 256) -> (width: Int, height: Int) {
        guard width > 0, height > 0, maximum > 0 else { return (0, 0) }
        let scale = min(1, Double(maximum) / Double(max(width, height)))
        return (max(1, Int(Double(width) * scale)), max(1, Int(Double(height) * scale)))
    }

    public static func evaluate(luma: [UInt8], width: Int, height: Int, originalWidth: Int, originalHeight: Int) -> Self {
        guard width > 8, height > 8, width <= 4096, height <= 4096, luma.count == width * height else { return .unavailable }
        var sum = 0.0, squared = 0.0, darkCount = 0, brightCount = 0
        for pixel in luma {
            let value = Double(pixel); sum += value; squared += value * value
            if pixel < 10 { darkCount += 1 }
            if pixel > 245 { brightCount += 1 }
        }
        let count = Double(luma.count), mean = sum / count
        let variance = max(0, squared / count - mean * mean)
        var gradients = 0, edges = 0, laplacian = 0
        let interior = Double((width - 2) * (height - 2))
        for y in 1..<(height - 1) { for x in 1..<(width - 1) {
            let i = y * width + x
            let gradient = abs(Int(luma[i + 1]) - Int(luma[i - 1])) + abs(Int(luma[i + width]) - Int(luma[i - width]))
            gradients += gradient
            if gradient > 24 { edges += 1 }
            laplacian += abs(Int(luma[i - 1]) + Int(luma[i + 1]) + Int(luma[i - width]) + Int(luma[i + width]) - 4 * Int(luma[i]))
        } }
        let gradient = Double(gradients) / interior, curvature = Double(laplacian) / interior
        let darkFraction = Double(darkCount) / count, brightFraction = Double(brightCount) / count
        var findings: [Finding] = []
        if originalWidth > 0, originalHeight > 0, max(originalWidth, originalHeight) < 1000 { findings.append(.lowResolution) }
        if mean < 24, darkFraction > 0.65 { findings.append(.dark) }
        if mean > 234, brightFraction > 0.65 { findings.append(.bright) }
        // Flat backgrounds and high-frequency noise provide insufficient focus evidence.
        let informative = variance > 400 && Double(edges) / interior > 0.005 && curvature < max(18, gradient * 1.25)
        if informative, gradient < 8, curvature < 3, width >= 96, height >= 96 { findings.append(.possibleBlur) }
        return Self(state: informative ? .evaluated : .insufficientDetail, findings: findings,
                    detailScore: min(100, gradient / 20 * 100),
                    exposureScore: max(0, 100 * (1 - max(darkFraction, brightFraction))))
    }
}
