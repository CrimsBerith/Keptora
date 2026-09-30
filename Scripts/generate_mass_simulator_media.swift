import AppKit
import AVFoundation
import CoreGraphics
import CoreMedia
import Foundation

let outputDir = URL(fileURLWithPath: "/tmp/cullora_mass_media")
try? FileManager.default.removeItem(at: outputDir)
try? FileManager.default.createDirectory(at: outputDir, withIntermediateDirectories: true)

print("Starting mass media generation at \(outputDir.path)...")

// Helper: Create a JPEG image
func createTestImage(filename: String, width: Int, height: Int, color1: (CGFloat, CGFloat, CGFloat), color2: (CGFloat, CGFloat, CGFloat), label: String, shapeType: Int, shapeOffset: CGFloat) -> URL {
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: colorSpace, bitmapInfo: bitmapInfo) else {
        fatalError("Failed to create CGContext")
    }
    
    // Gradient background
    let components: [CGFloat] = [
        color1.0, color1.1, color1.2, 1.0,
        color2.0, color2.1, color2.2, 1.0
    ]
    if let gradient = CGGradient(colorSpace: colorSpace, colorComponents: components, locations: [0.0, 1.0], count: 2) {
        ctx.drawLinearGradient(gradient, start: CGPoint.zero, end: CGPoint(x: width, y: height), options: [])
    }
    
    // Shapes
    ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.35))
    switch shapeType % 4 {
    case 0:
        ctx.fillEllipse(in: CGRect(x: CGFloat(width)/4.0 + shapeOffset, y: CGFloat(height)/4.0, width: CGFloat(width)/2.0, height: CGFloat(height)/2.0))
    case 1:
        ctx.fill(CGRect(x: CGFloat(width)/4.0 + shapeOffset, y: CGFloat(height)/4.0, width: CGFloat(width)/2.0, height: CGFloat(height)/2.0))
    case 2:
        ctx.beginPath()
        ctx.move(to: CGPoint(x: CGFloat(width)/2.0 + shapeOffset, y: CGFloat(height)/5.0))
        ctx.addLine(to: CGPoint(x: CGFloat(width)/5.0, y: CGFloat(height)*0.8))
        ctx.addLine(to: CGPoint(x: CGFloat(width)*0.8, y: CGFloat(height)*0.8))
        ctx.closePath()
        ctx.fillPath()
    default:
        ctx.fillEllipse(in: CGRect(x: CGFloat(width)/3.0 + shapeOffset, y: CGFloat(height)/3.0, width: CGFloat(width)/3.0, height: CGFloat(width)/3.0))
    }
    
    // Text drawing using NSGraphicsContext
    let fileURL = outputDir.appendingPathComponent(filename)
    if let cgImage = ctx.makeImage() {
        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: width, height: height))
        nsImage.lockFocus()
        let font = NSFont.systemFont(ofSize: CGFloat(min(width, height)) * 0.05, weight: .bold)
        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.white
        ]
        let attrStr = NSAttributedString(string: label, attributes: attrs)
        attrStr.draw(at: NSPoint(x: 20, y: 20))
        nsImage.unlockFocus()
        
        if let tiff = nsImage.tiffRepresentation,
           let rep = NSBitmapImageRep(data: tiff),
           let jpgData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
            try? jpgData.write(to: fileURL)
        }
    }
    return fileURL
}

// Helper: Create a short MP4 video
func createTestVideo(filename: String, width: Int, height: Int, durationSeconds: Double, fps: Int32 = 10, color1: (CGFloat, CGFloat, CGFloat), color2: (CGFloat, CGFloat, CGFloat), label: String) {
    let fileURL = outputDir.appendingPathComponent(filename)
    try? FileManager.default.removeItem(at: fileURL)
    
    guard let writer = try? AVAssetWriter(outputURL: fileURL, fileType: .mp4) else { return }
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: width,
        AVVideoHeightKey: height
    ]
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: writerInput,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]
    )
    writer.add(writerInput)
    guard writer.startWriting() else { return }
    writer.startSession(atSourceTime: .zero)
    
    let totalFrames = Int(durationSeconds * Double(fps))
    let frameDuration = CMTime(value: 1, timescale: fps)
    
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let components: [CGFloat] = [
        color1.0, color1.1, color1.2, 1.0,
        color2.0, color2.1, color2.2, 1.0
    ]
    
    for frameIndex in 0..<totalFrames {
        while !writerInput.isReadyForMoreMediaData {
            usleep(1000)
        }
        
        var pixelBuffer: CVPixelBuffer?
        let pool = adaptor.pixelBufferPool
        let status: CVReturn
        if let pool = pool {
            status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        } else {
            status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32ARGB, nil, &pixelBuffer)
        }
        
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { continue }
        
        CVPixelBufferLockBaseAddress(buffer, [])
        let data = CVPixelBufferGetBaseAddress(buffer)
        if let ctx = CGContext(data: data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: colorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
            
            if let gradient = CGGradient(colorSpace: colorSpace, colorComponents: components, locations: [0.0, 1.0], count: 2) {
                ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: width, y: height), options: [])
            }
            
            // Moving circle
            let progress = CGFloat(frameIndex) / CGFloat(max(1, totalFrames - 1))
            let circleX = CGFloat(width) * 0.2 + progress * CGFloat(width) * 0.6
            ctx.setFillColor(CGColor(red: 1.0, green: 1.0, blue: 1.0, alpha: 0.7))
            ctx.fillEllipse(in: CGRect(x: circleX - 30, y: CGFloat(height)/2.0 - 30, width: 60, height: 60))
        }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        
        let presentTime = CMTimeMultiply(frameDuration, multiplier: Int32(frameIndex))
        adaptor.append(buffer, withPresentationTime: presentTime)
    }
    
    writerInput.markAsFinished()
    let semaphore = DispatchSemaphore(value: 0)
    writer.finishWriting {
        semaphore.signal()
    }
    semaphore.wait()
}

print("1. Generating 1,500 Unique Photos...")
DispatchQueue.concurrentPerform(iterations: 1500) { i in
    let hue1 = CGFloat(i % 100) / 100.0
    let hue2 = CGFloat((i + 33) % 100) / 100.0
    let color1: (CGFloat, CGFloat, CGFloat) = (hue1, 0.6, 0.8)
    let color2: (CGFloat, CGFloat, CGFloat) = (hue2, 0.8, 0.5)
    let w = (i % 3 == 0) ? 1200 : ((i % 3 == 1) ? 1080 : 1440)
    let h = (i % 3 == 0) ? 1200 : ((i % 3 == 1) ? 1920 : 960)
    _ = createTestImage(
        filename: String(format: "IMG_UNIQUE_%04d.jpg", i),
        width: w,
        height: h,
        color1: color1,
        color2: color2,
        label: "Unique Photo #\(i)",
        shapeType: i % 4,
        shapeOffset: CGFloat(i % 50)
    )
}

print("2. Generating 100 Exact Duplicate Photo Sets (300 photos total)...")
for groupIdx in 0..<100 {
    let original = createTestImage(
        filename: String(format: "IMG_DUP_ORIG_%03d.jpg", groupIdx),
        width: 1280,
        height: 720,
        color1: (CGFloat(groupIdx % 10) / 10.0, CGFloat(0.7), CGFloat(0.9)),
        color2: (CGFloat(0.1), CGFloat(0.5), CGFloat(groupIdx % 10) / 10.0),
        label: "Duplicate Group \(groupIdx)",
        shapeType: groupIdx % 4,
        shapeOffset: 0
    )
    for copyIdx in 1...2 {
        let copyURL = outputDir.appendingPathComponent(String(format: "IMG_DUP_COPY_%03d_%d.jpg", groupIdx, copyIdx))
        try? FileManager.default.copyItem(at: original, to: copyURL)
    }
}

print("3. Generating 100 Similar Photo Burst Groups (500 photos total)...")
for burstIdx in 0..<100 {
    let baseHue = CGFloat(burstIdx % 20) / 20.0
    for frameIdx in 0..<5 {
        _ = createTestImage(
            filename: String(format: "IMG_BURST_%03d_FRAME_%d.jpg", burstIdx, frameIdx),
            width: 1200,
            height: 900,
            color1: (baseHue, CGFloat(0.65), CGFloat(0.8)),
            color2: (baseHue + 0.1, CGFloat(0.75), CGFloat(0.4)),
            label: "Burst #\(burstIdx) Frame \(frameIdx)",
            shapeType: burstIdx % 4,
            shapeOffset: CGFloat(frameIdx * 15)
        )
    }
}

print("4. Generating 50 Unique MP4 Videos...")
DispatchQueue.concurrentPerform(iterations: 50) { i in
    let hue1 = CGFloat(i % 20) / 20.0
    let hue2 = CGFloat((i + 7) % 20) / 20.0
    createTestVideo(
        filename: String(format: "VID_UNIQUE_%03d.mp4", i),
        width: 640,
        height: 360,
        durationSeconds: 1.5,
        fps: 10,
        color1: (hue1, CGFloat(0.7), CGFloat(0.9)),
        color2: (hue2, CGFloat(0.9), CGFloat(0.6)),
        label: "Video #\(i)"
    )
}

print("5. Generating 20 Exact Duplicate Video Sets (40 videos total)...")
for groupIdx in 0..<20 {
    let originalName = String(format: "VID_DUP_ORIG_%02d.mp4", groupIdx)
    createTestVideo(
        filename: originalName,
        width: 640,
        height: 360,
        durationSeconds: 1.5,
        fps: 10,
        color1: (CGFloat(groupIdx % 5) / 5.0, CGFloat(0.5), CGFloat(0.8)),
        color2: (CGFloat(0.8), CGFloat(groupIdx % 5) / 5.0, CGFloat(0.5)),
        label: "Dup Video \(groupIdx)"
    )
    let origURL = outputDir.appendingPathComponent(originalName)
    let copyURL = outputDir.appendingPathComponent(String(format: "VID_DUP_COPY_%02d.mp4", groupIdx))
    try? FileManager.default.copyItem(at: origURL, to: copyURL)
}

print("6. Generating 10 Similar Video Series (30 videos total)...")
for seriesIdx in 0..<10 {
    for varIdx in 0..<3 {
        createTestVideo(
            filename: String(format: "VID_SIMILAR_%02d_V%d.mp4", seriesIdx, varIdx),
            width: 640,
            height: 360,
            durationSeconds: 1.5 + Double(varIdx) * 0.3,
            fps: 10,
            color1: (CGFloat(seriesIdx % 10) / 10.0, CGFloat(0.6), CGFloat(0.7)),
            color2: (CGFloat(0.4), CGFloat(0.7), CGFloat(seriesIdx % 10) / 10.0),
            label: "Similar Vid \(seriesIdx) v\(varIdx)"
        )
    }
}

let allFiles = try FileManager.default.contentsOfDirectory(atPath: outputDir.path)
print("✓ Successfully generated \(allFiles.count) media items (photos and videos) in \(outputDir.path)!")
