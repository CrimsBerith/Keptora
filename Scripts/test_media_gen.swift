import AppKit
import AVFoundation
import CoreGraphics
import Foundation

let tmpDir = URL(fileURLWithPath: "/tmp/cullora_stress_gen")
try? FileManager.default.removeItem(at: tmpDir)
try? FileManager.default.createDirectory(at: tmpDir, withIntermediateDirectories: true)

func makeJPEG(url: URL, text: String, color: NSColor, size: CGSize = CGSize(width: 400, height: 400)) {
    let image = NSImage(size: NSSize(width: size.width, height: size.height))
    image.lockFocus()
    if let ctx = NSGraphicsContext.current?.cgContext {
        ctx.setFillColor(color.cgColor)
        ctx.fill(CGRect(origin: .zero, size: size))
        ctx.setFillColor(NSColor.white.withAlphaComponent(0.25).cgColor)
        ctx.fillEllipse(in: CGRect(x: size.width * 0.2, y: size.height * 0.2, width: size.width * 0.6, height: size.height * 0.6))
        
        let font = NSFont.boldSystemFont(ofSize: 24)
        let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: NSColor.white]
        let attrStr = NSAttributedString(string: text, attributes: attrs)
        attrStr.draw(at: NSPoint(x: 20, y: size.height / 2))
    }
    image.unlockFocus()
    
    if let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let data = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) {
        try? data.write(to: url)
    }
}

func makeMP4(url: URL, text: String, color: NSColor, duration: Double = 2.0) {
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

print("Testing photo & video generation...")
let samplePhoto = tmpDir.appendingPathComponent("test.jpg")
makeJPEG(url: samplePhoto, text: "Test", color: .systemBlue)
let sampleVideo = tmpDir.appendingPathComponent("test.mp4")
makeMP4(url: sampleVideo, text: "Video Test", color: .systemPurple)

print("Created test photo size: \(try? FileManager.default.attributesOfItem(atPath: samplePhoto.path)[.size] ?? 0) bytes")
print("Created test video size: \(try? FileManager.default.attributesOfItem(atPath: sampleVideo.path)[.size] ?? 0) bytes")
