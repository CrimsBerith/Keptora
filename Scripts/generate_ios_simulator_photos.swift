import AppKit
import AVFoundation
import CoreGraphics
import Foundation

let outDir = URL(fileURLWithPath: "/tmp/cullora_ios_photos")
try? FileManager.default.removeItem(at: outDir)
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func createPhoto(name: String, title: String, colorA: NSColor, colorB: NSColor, shift: CGFloat = 0) -> URL {
    let size = NSSize(width: 1920, height: 1080)
    let image = NSImage(size: size)
    image.lockFocus()
    
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return outDir.appendingPathComponent(name)
    }
    
    // Gradient Background
    let colors = [colorA.cgColor, colorB.cgColor] as CFArray
    let space = CGColorSpaceCreateDeviceRGB()
    if let grad = CGGradient(colorsSpace: space, colors: colors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(grad, start: .zero, end: CGPoint(x: size.width, y: size.height), options: [])
    }
    
    // Geometric Elements
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.25).cgColor)
    ctx.fillEllipse(in: CGRect(x: 300 + shift, y: 300, width: 400, height: 400))
    
    // Label Text
    let font = NSFont.systemFont(ofSize: 48, weight: .bold)
    let attrs: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white
    ]
    let attrStr = NSAttributedString(string: title, attributes: attrs)
    attrStr.draw(at: NSPoint(x: 100, y: 100))
    
    image.unlockFocus()
    
    let fileURL = outDir.appendingPathComponent(name)
    if let tiff = image.tiffRepresentation,
       let rep = NSBitmapImageRep(data: tiff),
       let png = rep.representation(using: .png, properties: [:]) {
        try? png.write(to: fileURL)
    }
    return fileURL
}

print("1. Generating sample photo groups...")

// Exact Duplicate Group 1 (Beach)
let beachOriginal = createPhoto(name: "Beach_Sunset_Original.jpg", title: "Sunset at Malibu Beach", colorA: .systemOrange, colorB: .systemPurple)
let beachCopy1 = outDir.appendingPathComponent("Beach_Sunset_Copy_1.jpg")
let beachCopy2 = outDir.appendingPathComponent("Beach_Sunset_Copy_2.jpg")
try? FileManager.default.copyItem(at: beachOriginal, to: beachCopy1)
try? FileManager.default.copyItem(at: beachOriginal, to: beachCopy2)

// Exact Duplicate Group 2 (Skyline)
let cityOriginal = createPhoto(name: "City_Skyline_Original.jpg", title: "New York Skyline Night", colorA: .systemBlue, colorB: .systemIndigo)
let cityCopy1 = outDir.appendingPathComponent("City_Skyline_Backup.jpg")
try? FileManager.default.copyItem(at: cityOriginal, to: cityCopy1)

// Similar Group (3 burst photos with minor frame shifts)
_ = createPhoto(name: "Mountain_Burst_1.jpg", title: "Mountain Peak Shot 1", colorA: .systemTeal, colorB: .systemGreen, shift: 0)
_ = createPhoto(name: "Mountain_Burst_2.jpg", title: "Mountain Peak Shot 2", colorA: .systemTeal, colorB: .systemGreen, shift: 30)
_ = createPhoto(name: "Mountain_Burst_3.jpg", title: "Mountain Peak Shot 3", colorA: .systemTeal, colorB: .systemGreen, shift: 60)

// Unique Photos
_ = createPhoto(name: "Unique_Coffee.jpg", title: "Morning Espresso", colorA: .systemBrown, colorB: .systemOrange)
_ = createPhoto(name: "Unique_Workspace.jpg", title: "Design Studio Desk", colorA: .systemGray, colorB: .black)

print("✓ Created 9 realistic photo assets in /tmp/cullora_ios_photos/")
