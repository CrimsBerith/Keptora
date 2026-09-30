import CoreGraphics
import Foundation

/// Fast on-device sharpness and edge clarity evaluator.
/// Computes normalized Sobel gradient density across high-frequency luminance channels.
/// Higher score = sharp focus, crisp details, zero motion blur.
/// Lower score = blurry, out-of-focus, or camera shake.
public enum ImageSharpnessEvaluator: Sendable {
    public static func evaluateSharpness(for image: CGImage) -> Float {
        let width = min(image.width, 256)
        let height = min(image.height, 256)
        guard width > 4, height > 4 else { return 0 }
        
        var pixels = [UInt8](repeating: 0, count: width * height)
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else { return 0 }
        
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var sumGradient: Double = 0
        var count: Double = 0
        
        for y in 1..<(height - 1) {
            let row = y * width
            let prev = (y - 1) * width
            let next = (y + 1) * width
            for x in 1..<(width - 1) {
                let gx = abs(Int(pixels[row + x + 1]) - Int(pixels[row + x - 1]))
                let gy = abs(Int(pixels[next + x]) - Int(pixels[prev + x]))
                sumGradient += Double(gx + gy)
                count += 1
            }
        }
        
        guard count > 0 else { return 0 }
        return Float(sumGradient / count)
    }
}
