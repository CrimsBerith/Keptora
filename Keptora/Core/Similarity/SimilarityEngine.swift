import CoreGraphics
import Foundation
import ImageIO
import Vision

actor SimilarityEngine {
    enum EngineError: LocalizedError {
        case unsupportedImage
        case imageDecodeFailed
        case contextCreationFailed
        case noObservation
        case archiveFailed
        case incompatibleFeaturePrint

        var errorDescription: String? {
            switch self {
            case .unsupportedImage: return "This file format is not supported by the on-device similarity engine."
            case .imageDecodeFailed: return "The image could not be decoded for similarity analysis."
            case .contextCreationFailed: return "The perceptual hash image context could not be created."
            case .noObservation: return "Vision did not return an image feature print."
            case .archiveFailed: return "The Vision feature print could not be archived."
            case .incompatibleFeaturePrint: return "The stored Vision feature print is incompatible with this runtime."
            }
        }
    }

    static let pinnedRevision = VNGenerateImageFeaturePrintRequestRevision1
    static let cropScaleName = "scaleFit"

    func feature(for url: URL) throws -> PerceptualFeaturePayload {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { throw EngineError.unsupportedImage }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: 1024,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw EngineError.imageDecodeFailed
        }

        let request = VNGenerateImageFeaturePrintRequest()
        request.revision = Self.pinnedRevision
        request.imageCropAndScaleOption = .scaleFit
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        try handler.perform([request])
        guard let observation = request.results?.first else { throw EngineError.noObservation }

        let archive: Data
        do {
            archive = try NSKeyedArchiver.archivedData(withRootObject: observation, requiringSecureCoding: true)
        } catch {
            throw EngineError.archiveFailed
        }

        return PerceptualFeaturePayload(
            featureArchive: archive,
            perceptualHash: try differenceHash(for: image),
            pixelWidth: image.width,
            pixelHeight: image.height,
            visionRevision: request.revision,
            cropScale: Self.cropScaleName
        )
    }

    func distance(featureArchive lhsData: Data, to rhsData: Data) throws -> Float {
        let lhs = try observation(from: lhsData)
        let rhs = try observation(from: rhsData)
        guard lhs.requestRevision == rhs.requestRevision,
              lhs.elementType == rhs.elementType,
              lhs.elementCount == rhs.elementCount else {
            throw EngineError.incompatibleFeaturePrint
        }
        var value: Float = 0
        try lhs.computeDistance(&value, to: rhs)
        return value
    }

    func observation(from archive: Data) throws -> VNFeaturePrintObservation {
        do {
            guard let observation = try NSKeyedUnarchiver.unarchivedObject(
                ofClass: VNFeaturePrintObservation.self,
                from: archive
            ) else { throw EngineError.archiveFailed }
            return observation
        } catch let error as EngineError {
            throw error
        } catch {
            throw EngineError.archiveFailed
        }
    }

    private func differenceHash(for image: CGImage) throws -> UInt64 {
        let width = 9
        let height = 8
        var pixels = [UInt8](repeating: 0, count: width * height)
        return try pixels.withUnsafeMutableBytes { storage in
            let buffer = storage.bindMemory(to: UInt8.self)
            guard let baseAddress = storage.baseAddress,
                  let context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: width,
                    space: CGColorSpaceCreateDeviceGray(),
                    bitmapInfo: CGImageAlphaInfo.none.rawValue
                  ) else { throw EngineError.contextCreationFailed }

            context.interpolationQuality = .low
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            var result: UInt64 = 0
            for row in 0..<height {
                for column in 0..<(width - 1) {
                    result <<= 1
                    let left = buffer[(row * width) + column]
                    let right = buffer[(row * width) + column + 1]
                    if left > right { result |= 1 }
                }
            }
            return result
        }
    }
}
