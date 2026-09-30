import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

func findPID() -> pid_t? {
    let apps = NSRunningApplication.runningApplications(withBundleIdentifier: "com.alfagolab.keptora")
    if let pid = apps.first?.processIdentifier { return pid }
    let all = NSWorkspace.shared.runningApplications
    for a in all {
        if a.localizedName == "Keptora" { return a.processIdentifier }
    }
    return nil
}

guard let pid = findPID() else {
    print("Error: Keptora is not running")
    exit(1)
}

let appElem = AXUIElementCreateApplication(pid)
var windowsVal: AnyObject?
AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &windowsVal)
guard let windows = windowsVal as? [AXUIElement], let win = windows.first else {
    print("Error: No window found")
    exit(1)
}

var winId: CGWindowID = 0
let winList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []
for w in winList {
    if let owner = w[kCGWindowOwnerName as String] as? String, owner.contains("Keptora") {
        winId = CGWindowID(w[kCGWindowNumber as String] as? Int ?? 0)
        break
    }
}

func findElement(named targetTitle: String, in elem: AXUIElement) -> AXUIElement? {
    var titleVal: AnyObject?
    var descVal: AnyObject?
    AXUIElementCopyAttributeValue(elem, kAXTitleAttribute as CFString, &titleVal)
    AXUIElementCopyAttributeValue(elem, kAXDescriptionAttribute as CFString, &descVal)
    let title = (titleVal as? String) ?? (descVal as? String) ?? ""
    if title == targetTitle {
        return elem
    }
    var childrenVal: AnyObject?
    AXUIElementCopyAttributeValue(elem, kAXChildrenAttribute as CFString, &childrenVal)
    if let children = childrenVal as? [AXUIElement] {
        for c in children {
            if let found = findElement(named: targetTitle, in: c) { return found }
        }
    }
    return nil
}

func pressButton(named name: String) -> Bool {
    var windowsVal: AnyObject?
    AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &windowsVal)
    guard let windows = windowsVal as? [AXUIElement] else { return false }
    for w in windows {
        if let elem = findElement(named: name, in: w) {
            let res = AXUIElementPerformAction(elem, kAXPressAction as CFString)
            if res == .success {
                print("✓ Clicked \"\(name)\"")
                return true
            }
        }
    }
    print("✗ Button \"\(name)\" not found or click failed")
    return false
}

func captureAndExport(named filename: String, outDir: URL) {
    let tmpURL = outDir.appendingPathComponent("raw_\(filename)")
    let finalURL = outDir.appendingPathComponent(filename)
    
    // screencapture window
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
    task.arguments = ["-l", "\(winId)", "-o", tmpURL.path]
    try? task.run()
    task.waitUntilExit()
    
    guard let rawImage = NSImage(contentsOf: tmpURL) else {
        print("Failed to capture \(filename)")
        return
    }
    
    let targetSize = CGSize(width: 2880, height: 1800)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(
        data: nil,
        width: Int(targetSize.width),
        height: Int(targetSize.height),
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue // No alpha channel!
    ) else {
        print("Failed to create CGContext for \(filename)")
        return
    }
    
    // Draw background gradient (dark elegant backdrop matching Keptora theme)
    let startColor = CGColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
    let endColor = CGColor(red: 0.04, green: 0.04, blue: 0.07, alpha: 1.0)
    let gradient = CGGradient(colorsSpace: colorSpace, colors: [startColor, endColor] as CFArray, locations: [0.0, 1.0])!
    context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 1800), end: CGPoint(x: 0, y: 0), options: [])
    
    // Draw window scaled and centered cleanly with aspect fit
    if let cgRaw = rawImage.cgImage(forProposedRect: nil, context: nil, hints: nil) {
        let rawW = CGFloat(cgRaw.width)
        let rawH = CGFloat(cgRaw.height)
        
        let scale = min(targetSize.width / rawW, targetSize.height / rawH)
        let destW = rawW * scale
        let destH = rawH * scale
        let destX = (targetSize.width - destW) / 2.0
        let destY = (targetSize.height - destH) / 2.0
        
        context.draw(cgRaw, in: CGRect(x: destX, y: destY, width: destW, height: destH))
    }
    
    guard let finalCG = context.makeImage() else { return }
    let rep = NSBitmapImageRep(cgImage: finalCG)
    guard let pngData = rep.representation(using: .png, properties: [:]) else { return }
    
    try? pngData.write(to: finalURL)
    try? FileManager.default.removeItem(at: tmpURL)
    print("✓ Saved App Store Screenshot: \(filename) (2880x1800 RGB, no alpha)")
}

let outDir = URL(fileURLWithPath: "/Users/khankartal/Desktop/MAC APPS NEARLY FINISHED/Keptora_Phase_5O_Calisan_Xcode_Projesi/AppStore/Generated/Screenshots/Mac")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

print("Starting 6-Screen App Store Screenshot Generation...")

// 1. Home
_ = pressButton(named: "Arşiv")
usleep(800_000)
captureAndExport(named: "01_Keptora_Home_Overview.png", outDir: outDir)

// 2. Exact Review
_ = pressButton(named: "İnceleme")
usleep(600_000)
_ = pressButton(named: "Exact")
usleep(600_000)
captureAndExport(named: "02_Keptora_Exact_Duplicates.png", outDir: outDir)

// 3. Similar Comparison
_ = pressButton(named: "Similar")
usleep(600_000)
captureAndExport(named: "03_Keptora_Similar_Comparison.png", outDir: outDir)

// 4. Safety Plan
_ = pressButton(named: "Exact")
usleep(500_000)
_ = pressButton(named: "Tüm Güvenli Kopyaları Seç")
usleep(500_000)
_ = pressButton(named: "Güvenlik Planı'na Ekle")
usleep(600_000)
_ = pressButton(named: "Güvenlik Planı")
usleep(900_000)
captureAndExport(named: "04_Keptora_Safety_Plan.png", outDir: outDir)

// Dismiss Safety Plan sheet
_ = pressButton(named: "Kapat") || pressButton(named: "İptal") || pressButton(named: "Vazgeç")
usleep(500_000)

// 5. History and Restore
_ = pressButton(named: "Geçmiş")
usleep(800_000)
captureAndExport(named: "05_Keptora_History_Restore.png", outDir: outDir)

// 6. Pro / Paywall
_ = pressButton(named: "Keptora Pro'yu Aç")
usleep(800_000)
captureAndExport(named: "06_Keptora_Privacy_Pro.png", outDir: outDir)

// Dismiss Paywall
_ = pressButton(named: "Belki Daha Sonra") || pressButton(named: "Maybe Later")
usleep(300_000)

print("All screenshots generated successfully in \(outDir.path)")
