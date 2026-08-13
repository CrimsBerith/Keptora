import AppKit
import Foundation

enum DemoLibraryFactory {
    private static let demoVersion = "5M-v1"

    static func prepare(in applicationSupportDirectory: URL) throws -> URL {
        let root = applicationSupportDirectory.appendingPathComponent("Demo Photo Library 5M", isDirectory: true)
        let marker = root.appendingPathComponent(".cullora-demo-version")
        if FileManager.default.fileExists(atPath: marker.path),
           (try? String(contentsOf: marker, encoding: .utf8)) == demoVersion {
            return root
        }

        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)

        let family = try imageData(
            title: "Family Morning",
            subtitle: "Exact duplicate set",
            primary: NSColor(calibratedRed: 0.13, green: 0.34, blue: 0.57, alpha: 1),
            secondary: NSColor(calibratedRed: 0.45, green: 0.72, blue: 0.86, alpha: 1),
            format: .jpeg
        )
        try write(family, names: ["Family_Original.jpg", "Family_Copy_1.jpg", "Family_Copy_2.jpg"], into: root)

        let poster = try imageData(
            title: "Summer Poster",
            subtitle: "Exact duplicate pair",
            primary: NSColor(calibratedRed: 0.76, green: 0.22, blue: 0.31, alpha: 1),
            secondary: NSColor(calibratedRed: 0.98, green: 0.65, blue: 0.31, alpha: 1),
            format: .png
        )
        try write(poster, names: ["Poster.png", "Poster copy.png"], into: root)

        let rawPreview = try imageData(
            title: "DSC 0001",
            subtitle: "JPEG + XMP family",
            primary: NSColor(calibratedRed: 0.20, green: 0.47, blue: 0.30, alpha: 1),
            secondary: NSColor(calibratedRed: 0.67, green: 0.82, blue: 0.48, alpha: 1),
            format: .jpeg
        )
        try rawPreview.write(to: root.appendingPathComponent("DSC_0001.jpg"), options: .atomic)
        try rawPreview.write(to: root.appendingPathComponent("DSC_0001_Edit.jpg"), options: .atomic)
        try #"<x:xmpmeta><rdf:Description cullora:demo="true"/></x:xmpmeta>"#.write(
            to: root.appendingPathComponent("DSC_0001.xmp"), atomically: true, encoding: .utf8
        )

        let colors: [(String, NSColor, NSColor)] = [
            ("Sunset_1.jpg", .systemOrange, .systemPurple),
            ("Sunset_2.jpg", .systemYellow, .systemPink),
            ("Sunset_3.jpg", .systemOrange, .systemIndigo),
        ]
        for (name, first, second) in colors {
            let data = try imageData(title: "Sunset", subtitle: "Review-only similar photo", primary: first, secondary: second, format: .jpeg)
            try data.write(to: root.appendingPathComponent(name), options: .atomic)
        }

        try demoVersion.write(to: marker, atomically: true, encoding: .utf8)
        return root
    }

    private enum ImageFormat { case jpeg, png }

    private static func imageData(
        title: String,
        subtitle: String,
        primary: NSColor,
        secondary: NSColor,
        format: ImageFormat
    ) throws -> Data {
        let size = NSSize(width: 1280, height: 800)
        let image = NSImage(size: size)
        image.lockFocus()
        defer { image.unlockFocus() }

        let bounds = NSRect(origin: .zero, size: size)
        NSGradient(starting: primary, ending: secondary)?.draw(in: bounds, angle: -28)
        NSColor.white.withAlphaComponent(0.18).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 90, dy: 85), xRadius: 44, yRadius: 44).fill()

        let titleStyle = NSMutableParagraphStyle(); titleStyle.alignment = .center
        let subtitleStyle = NSMutableParagraphStyle(); subtitleStyle.alignment = .center
        title.draw(
            in: NSRect(x: 120, y: 395, width: 1040, height: 100),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 58, weight: .bold),
                .foregroundColor: NSColor.white,
                .paragraphStyle: titleStyle,
            ]
        )
        subtitle.draw(
            in: NSRect(x: 140, y: 325, width: 1000, height: 60),
            withAttributes: [
                .font: NSFont.systemFont(ofSize: 27, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.86),
                .paragraphStyle: subtitleStyle,
            ]
        )

        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff) else {
            throw CocoaError(.fileWriteUnknown)
        }
        switch format {
        case .jpeg:
            guard let data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.91]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        case .png:
            guard let data = bitmap.representation(using: .png, properties: [:]) else {
                throw CocoaError(.fileWriteUnknown)
            }
            return data
        }
    }

    private static func write(_ data: Data, names: [String], into directory: URL) throws {
        for name in names {
            try data.write(to: directory.appendingPathComponent(name), options: .atomic)
        }
    }
}
