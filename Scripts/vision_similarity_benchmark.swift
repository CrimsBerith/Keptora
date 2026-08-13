import AppKit
import CoreGraphics
import Foundation
import Vision

struct Sample {
    let distance: Float
    let similar: Bool
}

func image(seed: Int, variant: Int) -> CGImage {
    let width = 320
    let height = 240
    let space = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(
        data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
        space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let base = CGFloat((seed * 37) % 255) / 255
    context.setFillColor(CGColor(red: base, green: 0.22, blue: 0.44, alpha: 1))
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(CGColor(red: 0.82, green: 0.25 + CGFloat(variant) * 0.01, blue: 0.18, alpha: 1))
    context.fillEllipse(in: CGRect(x: 30 + variant, y: 40, width: 130, height: 130))
    context.setFillColor(CGColor(gray: 0.92, alpha: 1))
    context.fill(CGRect(x: 185, y: 55 + variant, width: 90, height: 110))
    return context.makeImage()!
}

func feature(_ image: CGImage) throws -> VNFeaturePrintObservation {
    let request = VNGenerateImageFeaturePrintRequest()
    request.revision = VNGenerateImageFeaturePrintRequestRevision1
    request.imageCropAndScaleOption = .scaleFit
    try VNImageRequestHandler(cgImage: image).perform([request])
    guard let result = request.results?.first else { throw NSError(domain: "CulloraBenchmark", code: 1) }
    return result
}

func distance(_ first: VNFeaturePrintObservation, _ second: VNFeaturePrintObservation) throws -> Float {
    var value: Float = 0
    try first.computeDistance(&value, to: second)
    return value
}

func percentile(_ values: [Float], _ fraction: Double) -> Float {
    let sorted = values.sorted()
    let index = min(sorted.count - 1, max(0, Int(Double(sorted.count - 1) * fraction)))
    return sorted[index]
}

let started = Date()
var positives: [Float] = []
var negatives: [Float] = []
let count = 80
for seed in 0..<count {
    let base = try feature(image(seed: seed, variant: 0))
    let transformed = try feature(image(seed: seed, variant: 2))
    let unrelated = try feature(image(seed: seed + 10_000, variant: 0))
    positives.append(try distance(base, transformed))
    negatives.append(try distance(base, unrelated))
}
let result: [String: Any] = [
    "phase": "5I",
    "visionRevision": VNGenerateImageFeaturePrintRequestRevision1,
    "cropScale": "scaleFit",
    "positiveSamples": positives.count,
    "negativeSamples": negatives.count,
    "positiveP50": percentile(positives, 0.50),
    "positiveP95": percentile(positives, 0.95),
    "negativeP05": percentile(negatives, 0.05),
    "negativeP50": percentile(negatives, 0.50),
    "elapsedSeconds": Date().timeIntervalSince(started),
    "note": "Synthetic calibration smoke; replace with labeled real-library pairs before shipping threshold claims."
]
let data = try JSONSerialization.data(withJSONObject: result, options: [.prettyPrinted, .sortedKeys])
print(String(decoding: data, as: UTF8.self))
