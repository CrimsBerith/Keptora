@preconcurrency import ImageIO
import CoreGraphics
import Foundation

/// Engine for repairing corrupted/missing metadata and stripping sensitive location tags for privacy.
public enum MetadataDoctorEngine: Sendable {
    
    /// Parses a filename to extract an inferred capture date if EXIF date is missing.
    /// Supports patterns like:
    /// - `IMG_20240815_142310.jpg`
    /// - `2024-08-15-14-23-10.jpg`
    /// - `Screenshot 2024-08-15 at 14.23.10.png`
    /// - `WhatsApp Image 2024-08-15 at 14.23.10.jpeg`
    public static func inferDateFromFilename(_ filename: String) -> Date? {
        let regexPatterns = [
            #"(20\d{2})[-_]?([01]\d)[-_]?([0-3]\d)(?:[-_ ]|\s+at\s+)([0-2]\d)[-_.]?([0-5]\d)[-_.]?([0-5]\d)"#,
            #"(20\d{2})[-_]([01]\d)[-_]([0-3]\d)"#
        ]
        
        for pattern in regexPatterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(filename.startIndex..<filename.endIndex, in: filename)
            if let match = regex.firstMatch(in: filename, range: range) {
                var comp = DateComponents()
                if match.numberOfRanges >= 4 {
                    if let r1 = Range(match.range(at: 1), in: filename),
                       let r2 = Range(match.range(at: 2), in: filename),
                       let r3 = Range(match.range(at: 3), in: filename) {
                        comp.year = Int(filename[r1])
                        comp.month = Int(filename[r2])
                        comp.day = Int(filename[r3])
                    }
                }
                if match.numberOfRanges >= 7 {
                    if let r4 = Range(match.range(at: 4), in: filename),
                       let r5 = Range(match.range(at: 5), in: filename),
                       let r6 = Range(match.range(at: 6), in: filename) {
                        comp.hour = Int(filename[r4])
                        comp.minute = Int(filename[r5])
                        comp.second = Int(filename[r6])
                    }
                } else {
                    comp.hour = 12
                    comp.minute = 0
                    comp.second = 0
                }
                // Reject impossible dates (e.g. month 19, day 39) instead of letting Calendar roll them over.
                guard let month = comp.month, (1...12).contains(month),
                      let day = comp.day, (1...31).contains(day),
                      let date = Calendar.current.date(from: comp),
                      Calendar.current.component(.month, from: date) == month,
                      Calendar.current.component(.day, from: date) == day else { continue }
                return date
            }
        }
        return nil
    }
    
    /// Creates a privacy-safe copy of an image by removing all GPS location dictionaries and personal creator tags.
    /// Handles in-place modifications atomically without data loss or corruption.
    public static func stripLocationData(from sourceURL: URL, destinationURL: URL) throws {
        guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        guard let uti = CGImageSourceGetType(source) else {
            throw CocoaError(.fileReadUnknown)
        }
        
        let count = CGImageSourceGetCount(source)
        guard count > 0 else {
            throw CocoaError(.fileReadCorruptFile)
        }
        
        let isInPlace = (sourceURL.standardizedFileURL.path == destinationURL.standardizedFileURL.path)
        let targetWriteURL: URL
        let tempURL: URL?
        
        if isInPlace {
            let tempDir = destinationURL.deletingLastPathComponent()
            let tempFilename = ".tmp_keptora_\(UUID().uuidString)_\(destinationURL.lastPathComponent)"
            let candidateTemp = tempDir.appendingPathComponent(tempFilename)
            tempURL = candidateTemp
            targetWriteURL = candidateTemp
        } else {
            tempURL = nil
            targetWriteURL = destinationURL
        }
        
        guard let destination = CGImageDestinationCreateWithURL(targetWriteURL as CFURL, uti, count, nil) else {
            throw CocoaError(.fileWriteUnknown)
        }
        
        for i in 0..<count {
            if var properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any] {
                // CGImageDestination overlays these properties on the source metadata, so omitting a
                // key keeps the original value. kCFNull is what actually removes it.
                properties[kCGImagePropertyGPSDictionary] = kCFNull
                
                // Clean sensitive TIFF fields
                var tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
                tiff[kCGImagePropertyTIFFArtist] = kCFNull
                tiff[kCGImagePropertyTIFFCopyright] = kCFNull
                properties[kCGImagePropertyTIFFDictionary] = tiff
                
                CGImageDestinationAddImageFromSource(destination, source, i, properties as CFDictionary)
            } else {
                CGImageDestinationAddImageFromSource(destination, source, i, [kCGImagePropertyGPSDictionary: kCFNull] as CFDictionary)
            }
        }
        
        guard CGImageDestinationFinalize(destination) else {
            // Never leave a partial file behind, whether writing to a temp file or a new copy.
            try? FileManager.default.removeItem(at: targetWriteURL)
            throw CocoaError(.fileWriteUnknown)
        }
        
        if let tempURL {
            do {
                _ = try FileManager.default.replaceItemAt(destinationURL, withItemAt: tempURL, backupItemName: nil, options: .usingNewMetadataOnly)
            } catch {
                // Fallback for mount points where replaceItemAt is unsupported. The original is
                // moved aside first so a failed move can be rolled back instead of losing it.
                let backupURL = destinationURL.deletingLastPathComponent()
                    .appendingPathComponent(".bak_keptora_\(UUID().uuidString)_\(destinationURL.lastPathComponent)")
                do {
                    try FileManager.default.moveItem(at: destinationURL, to: backupURL)
                } catch {
                    try? FileManager.default.removeItem(at: tempURL)
                    throw error
                }
                do {
                    try FileManager.default.moveItem(at: tempURL, to: destinationURL)
                    try? FileManager.default.removeItem(at: backupURL)
                } catch {
                    try? FileManager.default.moveItem(at: backupURL, to: destinationURL)
                    try? FileManager.default.removeItem(at: tempURL)
                    throw error
                }
            }
        }
    }
}
