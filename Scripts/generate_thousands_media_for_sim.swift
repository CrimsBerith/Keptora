import AppKit
import AVFoundation
import CoreGraphics
import Foundation

let outDir = URL(fileURLWithPath: "/tmp/keptora_simulator_corpus")
try? FileManager.default.removeItem(at: outDir)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let colors: [NSColor] = [
    .systemRed, .systemBlue, .systemGreen, .systemOrange, .systemPurple,
    .systemTeal, .systemPink, .systemIndigo, .systemYellow, .systemBrown
]

func makeJPEG(url: URL, text: String, color: NSColor, shift: CGFloat = 0, size: CGSize = CGSize(width: 480, height: 480)) {
    let image = NSImage(size: NSSize(width: size.width, height: size.height))
    image.lockFocus()
    if let ctx = NSGraphicsContext.current?.cgContext {
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.28).cgColor)
        ctx.fillEllipse(in: CGRect(x: size.width * 0.15 + shift, y: size.height * 0.15, width: size.width * 0.7, height: size.height * 0.7))
        
        let font = NSFont.boldSystemFont(ofSize: 22)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        attrStr.draw(at: NSPoint(x: 20, y: size.height / 2))
    }
    image.unlockFocus()
    
    if let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.82]) {
        try? data.write(to: url)
    }
}

func makeMP4(url: URL, text: String, color: NSColor, duration: Double = 1.5) {
    let size = CGSize(width: 360, height: 360)
    guard let writer = try? AVAssetWriter(outputURL: url, fileType: .mp4) else { return }
    let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: size.width,
        AVVideoHeightKey: size.height
    ]
    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
    let adaptor = AVAssetWriterInputPixelBufferAdaptor(
        assetWriterInput: writerInput,
        sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
            kCVPixelBufferWidthKey as String: size.width,
            kCVPixelBufferHeightKey as String: size.height
        ]
    )
    writer.add(writerInput)
    writer.startWriting()
    writer.startSession(atSourceTime: .zero)
    
    var buffer: CVPixelBuffer?
    CVPixelBufferCreate(kCFAllocatorDefault, Int(size.width), Int(size.height), kCVPixelFormatType_32ARGB, nil, &buffer)
    if let pixelBuffer = buffer {
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        let pxdata = CVPixelBufferGetBaseAddress(pixelBuffer)
        let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
        if let context = CGContext(data: pxdata, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue) {
            context.setFillColor(color.cgColor)
            context.fill(CGRect(origin: .zero, size: size))
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, [])
        adaptor.append(pixelBuffer, withPresentationTime: .zero)
        adaptor.append(pixelBuffer, withPresentationTime: CMTime(seconds: duration, preferredTimescale: 600))
    }
    writerInput.markAsFinished()
    let sema = DispatchSemaphore(value: 0)
    writer.finishWriting { sema.signal() }
    sema.wait()
}

print("1. Generating thousands of photos and videos...")
var fileURLs: [URL] = []
let startTime = Date()

// 1. Exact Duplicate Photo Groups (300 groups -> ~750 files)
print(" - Generating 300 exact photo duplicate groups...")
for i in 1...300 {
    let color = colors[i % colors.count]
    let origURL = outDir.appendingPathComponent("Photo_Group_\(i)_Original.jpg")
    makeJPEG(url: origURL, text: "Photo Group #\(i)", color: color)
    fileURLs.append(origURL)
    
    let copy1URL = outDir.appendingPathComponent("Photo_Group_\(i)_Copy_A.jpg")
    try? FileManager.default.copyItem(at: origURL, to: copy1URL)
    fileURLs.append(copy1URL)
    
    if i % 2 == 0 {
        let copy2URL = outDir.appendingPathComponent("Photo_Group_\(i)_Copy_B.jpg")
        try? FileManager.default.copyItem(at: origURL, to: copy2URL)
        fileURLs.append(copy2URL)
    }
    if i % 5 == 0 {
        let copy3URL = outDir.appendingPathComponent("Photo_Group_\(i)_Backup.jpg")
        try? FileManager.default.copyItem(at: origURL, to: copy3URL)
        fileURLs.append(copy3URL)
    }
}

// 2. Similar Photo Groups (100 burst sets -> 300 files)
print(" - Generating 100 similar burst sets...")
for i in 1...100 {
    let color = colors[(i + 3) % colors.count]
    let burst1 = outDir.appendingPathComponent("Burst_Set_\(i)_Shot_1.jpg")
    let burst2 = outDir.appendingPathComponent("Burst_Set_\(i)_Shot_2.jpg")
    let burst3 = outDir.appendingPathComponent("Burst_Set_\(i)_Shot_3.jpg")
    makeJPEG(url: burst1, text: "Burst #\(i) A", color: color, shift: 0)
    makeJPEG(url: burst2, text: "Burst #\(i) B", color: color, shift: 20)
    makeJPEG(url: burst3, text: "Burst #\(i) C", color: color, shift: 40)
    fileURLs.append(contentsOf: [burst1, burst2, burst3])
}

// 3. Unique Photos (250 unique files)
print(" - Generating 250 unique photos...")
for i in 1...250 {
    let color = colors[(i * 7) % colors.count]
    let uniqueURL = outDir.appendingPathComponent("Unique_Photo_\(i).jpg")
    makeJPEG(url: uniqueURL, text: "Unique Shot #\(i)", color: color, shift: CGFloat(i % 100))
    fileURLs.append(uniqueURL)
}

// 4. Exact Duplicate Videos (25 groups -> 60 video files)
print(" - Generating 25 exact video duplicate groups...")
for i in 1...25 {
    let color = colors[i % colors.count]
    let origVideo = outDir.appendingPathComponent("Video_Group_\(i)_Original.mp4")
    makeMP4(url: origVideo, text: "Video #\(i)", color: color, duration: 1.0 + Double(i % 5))
    fileURLs.append(origVideo)
    
    let copyVideo1 = outDir.appendingPathComponent("Video_Group_\(i)_Copy.mp4")
    try? FileManager.default.copyItem(at: origVideo, to: copyVideo1)
    fileURLs.append(copyVideo1)
    
    if i % 3 == 0 {
        let copyVideo2 = outDir.appendingPathComponent("Video_Group_\(i)_Backup.mp4")
        try? FileManager.default.copyItem(at: origVideo, to: copyVideo2)
        fileURLs.append(copyVideo2)
    }
}

// 5. Similar Videos (15 pairs -> 30 files)
print(" - Generating 15 similar video sets...")
for i in 1...15 {
    let color = colors[(i + 4) % colors.count]
    let vidA = outDir.appendingPathComponent("Similar_Video_\(i)_Take_1.mp4")
    let vidB = outDir.appendingPathComponent("Similar_Video_\(i)_Take_2.mp4")
    makeMP4(url: vidA, text: "Video Take 1", color: color, duration: 2.0)
    makeMP4(url: vidB, text: "Video Take 2", color: color, duration: 2.0)
    fileURLs.append(contentsOf: [vidA, vidB])
}

let elapsed = Date().timeIntervalSince(startTime)
print("✓ Generated total \(fileURLs.count) photo & video assets in \(String(format: "%.1f", elapsed))s.")
print("  Corpus path: \(outDir.path)")
