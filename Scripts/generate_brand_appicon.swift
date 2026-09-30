// DEPRECATED (Sep 2026): this script draws the old "camera.filters" icon. The current icon is produced from AppStore/AppIcon/logo/*.svg — do not run this against the asset catalog.
import AppKit
import CoreGraphics
import Foundation

func generateKeptoraIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()
    
    guard let ctx = NSGraphicsContext.current?.cgContext else {
        image.unlockFocus()
        return image
    }
    
    ctx.setAllowsAntialiasing(true)
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    
    let fullRect = CGRect(x: 0, y: 0, width: size, height: size)
    
    // Base Brand Gradient Layer (100% full bleed, edge-to-edge, opaque)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let colors = [
        NSColor(red: 0.12, green: 0.72, blue: 0.94, alpha: 1.0).cgColor, // Cyan
        NSColor(red: 0.38, green: 0.32, blue: 0.98, alpha: 1.0).cgColor, // Royal Accent
        NSColor(red: 0.62, green: 0.28, blue: 0.96, alpha: 1.0).cgColor  // Violet
    ] as CFArray
    let locations: [CGFloat] = [0.0, 0.48, 1.0]
    
    if let gradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size, y: 0),
            options: []
        )
    }
    
    // Subtle top-left glass specular highlight
    let highlightColors = [
        NSColor.white.withAlphaComponent(0.30).cgColor,
        NSColor.white.withAlphaComponent(0.0).cgColor
    ] as CFArray
    if let highlightGrad = CGGradient(colorsSpace: colorSpace, colors: highlightColors, locations: [0.0, 1.0]) {
        ctx.drawLinearGradient(
            highlightGrad,
            start: CGPoint(x: 0, y: size),
            end: CGPoint(x: size * 0.65, y: size * 0.35),
            options: []
        )
    }
    
    // Crisp "camera.filters" SF Symbol centered in pure white with soft depth shadow
    let symbolConfig = NSImage.SymbolConfiguration(pointSize: size * 0.44, weight: .semibold)
        .applying(.init(paletteColors: [.white]))
    if let symbolImage = NSImage(systemSymbolName: "camera.filters", accessibilityDescription: nil)?
        .withSymbolConfiguration(symbolConfig) {
        
        let symbolSize = symbolImage.size
        let targetRect = CGRect(
            x: (size - symbolSize.width) / 2.0,
            y: (size - symbolSize.height) / 2.0,
            width: symbolSize.width,
            height: symbolSize.height
        )
        
        ctx.saveGState()
        let symbolShadow = NSColor.black.withAlphaComponent(0.25).cgColor
        ctx.setShadow(offset: CGSize(width: 0, height: -size * 0.015), blur: size * 0.03, color: symbolShadow)
        
        symbolImage.draw(in: targetRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        ctx.restoreGState()
    }
    
    image.unlockFocus()
    return image
}

func savePNG(image: NSImage, to url: URL) {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData),
          let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to convert image to PNG for \(url.lastPathComponent)")
        return
    }
    try? pngData.write(to: url)
}

let appIconDir = URL(fileURLWithPath: "/Users/khankartal/Desktop/MAC APPS NEARLY FINISHED/Keptora_Phase_5O_Calisan_Xcode_Projesi/Keptora/Resources/Assets.xcassets/AppIcon.appiconset")
let appStoreDir = URL(fileURLWithPath: "/Users/khankartal/Desktop/MAC APPS NEARLY FINISHED/Keptora_Phase_5O_Calisan_Xcode_Projesi/AppStore/AppIcon")
try? FileManager.default.createDirectory(at: appStoreDir, withIntermediateDirectories: true)

// 1. Generate master 1024
let master1024 = generateKeptoraIcon(size: 1024)
savePNG(image: master1024, to: appStoreDir.appendingPathComponent("source-1024.png"))
savePNG(image: master1024, to: appIconDir.appendingPathComponent("icon_1024.png"))

let sizes: [CGFloat] = [16, 32, 40, 58, 60, 64, 80, 87, 120, 128, 180, 256, 512]
for s in sizes {
    let icon = generateKeptoraIcon(size: s)
    savePNG(image: icon, to: appIconDir.appendingPathComponent("icon_\(Int(s)).png"))
}

print("SUCCESS: All Keptora AppIcon sizes generated matching in-app brand header!")
