import Foundation

public struct PhysicalExportConfiguration: Sendable {
    public enum OrganizationStructure: String, Sendable, CaseIterable {
        case yearAndMonth = "year_and_month"             // 2026 / 08 / img.jpg
        case yearAndCategory = "year_and_category"       // 2026 / Nature / img.jpg
        case categoryOnly = "category_only"              // Documents / img.jpg
    }
    
    public enum TransferMode: String, Sendable, CaseIterable {
        case copy = "copy"
        case symlink = "symlink"
        case hardlink = "hardlink"
    }
    
    public let destinationURL: URL
    public let structure: OrganizationStructure
    public let transferMode: TransferMode
    public let skipDuplicates: Bool
    
    public init(
        destinationURL: URL,
        structure: OrganizationStructure = .yearAndMonth,
        transferMode: TransferMode = .copy,
        skipDuplicates: Bool = true
    ) {
        self.destinationURL = destinationURL
        self.structure = structure
        self.transferMode = transferMode
        self.skipDuplicates = skipDuplicates
    }
}

public struct PhysicalExportProgress: Sendable {
    public let processedCount: Int
    public let totalCount: Int
    public let bytesTransferred: Int64
    public let currentFilename: String
    public let isCancelled: Bool
}

/// Lossless physical archive exporter that organizes media assets into structured Finder directories.
public enum PhysicalArchiveExporter: Sendable {
    
    public static func export(
        assets: [UniversalMediaAsset],
        reports: [String: SmartCategorizationReport] = [:],
        config: PhysicalExportConfiguration,
        progress: @escaping @Sendable (PhysicalExportProgress) -> Void
    ) async throws {
        let fileManager = FileManager.default
        try fileManager.createDirectory(at: config.destinationURL, withIntermediateDirectories: true)
        
        var processed = 0
        var totalBytes: Int64 = 0
        let total = assets.count
        
        let yearFormatter = DateFormatter()
        yearFormatter.dateFormat = "yyyy"
        yearFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        let monthFormatter = DateFormatter()
        monthFormatter.dateFormat = "MM - MMMM"
        monthFormatter.locale = Locale(identifier: "en_US_POSIX")
        
        for asset in assets {
            try Task.checkCancellation()
            
            guard case .file(let sourceURL) = asset.reference else {
                processed += 1
                continue
            }
            
            // Build subpath
            let date = asset.creationDate ?? Date()
            let yearStr = yearFormatter.string(from: date)
            let monthStr = monthFormatter.string(from: date)
            let categoryStr = reports[asset.id]?.primaryCategory.displayName ?? "General"
            
            let targetSubdir: URL
            switch config.structure {
            case .yearAndMonth:
                targetSubdir = config.destinationURL.appendingPathComponent(yearStr).appendingPathComponent(monthStr)
            case .yearAndCategory:
                targetSubdir = config.destinationURL.appendingPathComponent(yearStr).appendingPathComponent(categoryStr)
            case .categoryOnly:
                targetSubdir = config.destinationURL.appendingPathComponent(categoryStr)
            }
            
            try fileManager.createDirectory(at: targetSubdir, withIntermediateDirectories: true)
            var targetFile = targetSubdir.appendingPathComponent(sourceURL.lastPathComponent)
            
            if fileManager.fileExists(atPath: targetFile.path) {
                var isExactDuplicate = false
                if let srcAttr = try? fileManager.attributesOfItem(atPath: sourceURL.path),
                   let dstAttr = try? fileManager.attributesOfItem(atPath: targetFile.path) {
                    let srcSize = srcAttr[.size] as? Int64 ?? (srcAttr[.size] as? NSNumber)?.int64Value ?? -1
                    let dstSize = dstAttr[.size] as? Int64 ?? (dstAttr[.size] as? NSNumber)?.int64Value ?? -2
                    if srcSize == dstSize {
                        let srcMod = srcAttr[.modificationDate] as? Date
                        let dstMod = dstAttr[.modificationDate] as? Date
                        if let srcMod, let dstMod, abs(srcMod.timeIntervalSince(dstMod)) < 1.0 {
                            isExactDuplicate = true
                        } else if let srcHash = try? await StreamingSHA256.file(at: sourceURL, progress: { _ in }),
                                  let dstHash = try? await StreamingSHA256.file(at: targetFile, progress: { _ in }),
                                  srcHash.digest == dstHash.digest {
                            isExactDuplicate = true
                        }
                    }
                }
                
                if config.skipDuplicates && isExactDuplicate {
                    processed += 1
                    if processed % 5 == 0 || processed == total {
                        progress(PhysicalExportProgress(
                            processedCount: processed,
                            totalCount: total,
                            bytesTransferred: totalBytes,
                            currentFilename: asset.displayName,
                            isCancelled: false
                        ))
                    }
                    continue
                } else {
                    // Different file with same name: generate unique destination name to avoid collision
                    let baseName = sourceURL.deletingPathExtension().lastPathComponent
                    let ext = sourceURL.pathExtension
                    var counter = 1
                    while fileManager.fileExists(atPath: targetFile.path) {
                        let newName = ext.isEmpty ? "\(baseName)_\(counter)" : "\(baseName)_\(counter).\(ext)"
                        targetFile = targetSubdir.appendingPathComponent(newName)
                        counter += 1
                    }
                }
            }
            
            // Transfer with graceful fallbacks
            switch config.transferMode {
            case .copy:
                try fileManager.copyItem(at: sourceURL, to: targetFile)
            case .symlink:
                try fileManager.createSymbolicLink(at: targetFile, withDestinationURL: sourceURL)
            case .hardlink:
                do {
                    try fileManager.linkItem(at: sourceURL, to: targetFile)
                } catch {
                    // Fallback to copy if hardlink fails (e.g. cross-volume link EXDEV or unsupported filesystem)
                    try fileManager.copyItem(at: sourceURL, to: targetFile)
                }
            }
            
            processed += 1
            totalBytes += (asset.byteCount ?? 0)
            
            // Emit progress throttled to avoid main-thread dispatch saturation
            if processed % 5 == 0 || processed == total {
                progress(PhysicalExportProgress(
                    processedCount: processed,
                    totalCount: total,
                    bytesTransferred: totalBytes,
                    currentFilename: asset.displayName,
                    isCancelled: false
                ))
            }
        }
    }
}
