import AppKit
import CoreGraphics
import Foundation
import SwiftUI

@MainActor
func renderViewToPNG<V: View>(view: V, size: CGSize, url: URL) {
    let hosting = NSHostingController(rootView: view)
    hosting.view.frame = CGRect(origin: .zero, size: size)
    hosting.view.layoutSubtreeIfNeeded()
    
    guard let bitmap = hosting.view.bitmapImageRepForCachingDisplay(in: hosting.view.bounds) else {
        print("Failed to cache bitmap for \(url.lastPathComponent)")
        return
    }
    hosting.view.cacheDisplay(in: hosting.view.bounds, to: bitmap)
    
    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        print("Failed to generate PNG data for \(url.lastPathComponent)")
        return
    }
    try? pngData.write(to: url)
    print("✓ Rendered: \(url.lastPathComponent) (\(Int(size.width))x\(Int(size.height)))")
}

let outDir = URL(fileURLWithPath: "/Users/khankartal/Desktop/MAC APPS NEARLY FINISHED/Cullora_Phase_5O_Calisan_Xcode_Projesi/AppStore/Generated/Screenshots/Mac")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

let size = CGSize(width: 2880, height: 1800)

let model = AppModel()
let store = StoreEntitlementController()
Task {
    await model.prepare()
}

// Render main app views
let mainView = MainRootView()
    .environmentObject(model)
    .environmentObject(store)
    .frame(width: size.width, height: size.height)

renderViewToPNG(view: mainView, size: size, url: outDir.appendingPathComponent("01_Cullora_Home_Overview.png"))

print("App Store Mac Screenshots successfully saved to AppStore/Generated/Screenshots/Mac/")
