@preconcurrency import AVFoundation
import Foundation

/// Categorization of heavy or anomalous media files taking disproportionate disk space.
public enum HeavyMediaReason: String, Codable, Sendable, CaseIterable {
    case proResOrRawCodec = "prores_or_raw"
    case ultraHighBitrate = "ultra_high_bitrate"
    case accidentalShortVideo = "accidental_short_video"
    case longScreenRecording = "long_screen_recording"
    case oversizedVideo = "oversized_video"
    
    public var title: String {
        switch self {
        case .proResOrRawCodec: return String(localized: "ProRes / RAW Video")
        case .ultraHighBitrate: return String(localized: "Ultra High Bitrate")
        case .accidentalShortVideo: return String(localized: "Accidental Short Clip (< 3s)")
        case .longScreenRecording: return String(localized: "Long Screen Recording")
        case .oversizedVideo: return String(localized: "Oversized (> 1 GB)")
        }
    }
}

public struct HeavyMediaReport: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let assetID: String
    public let durationSeconds: Double
    public let byteCount: Int64
    public let megabytesPerSecond: Double
    public let codecName: String?
    public let reasons: [HeavyMediaReason]
    public let estimatedSpaceSavingsBytes: Int64
    
    public init(
        id: String,
        assetID: String,
        durationSeconds: Double,
        byteCount: Int64,
        megabytesPerSecond: Double,
        codecName: String?,
        reasons: [HeavyMediaReason],
        estimatedSpaceSavingsBytes: Int64
    ) {
        self.id = id
        self.assetID = assetID
        self.durationSeconds = durationSeconds
        self.byteCount = byteCount
        self.megabytesPerSecond = megabytesPerSecond
        self.codecName = codecName
        self.reasons = reasons
        self.estimatedSpaceSavingsBytes = estimatedSpaceSavingsBytes
    }
}

public enum HeavyMediaAnalyzer: Sendable {
    
    /// Evaluates video properties to detect clutter, accidental recordings, and heavy codecs.
    public static func evaluate(asset: UniversalMediaAsset, duration: Double, byteCount: Int64) -> HeavyMediaReport? {
        guard duration > 0, byteCount > 0 else { return nil }
        
        let mbps = (Double(byteCount) / 1_048_576.0) / duration
        var reasons: [HeavyMediaReason] = []
        
        let ext = (asset.displayName as NSString).pathExtension.lowercased()
        let name = asset.displayName.lowercased()
        
        // 1. Accidental micro-clips (e.g. pocket taps, 1-3 seconds)
        if duration <= 3.0 && byteCount > 5_000_000 {
            reasons.append(.accidentalShortVideo)
        }
        
        // 2. Ultra high bitrate (> 15 MB/s = ~120 Mbps, often ProRes or uncompressed 4K60)
        if mbps >= 15.0 {
            reasons.append(.ultraHighBitrate)
        }
        
        // 3. Oversized files (> 1 GB)
        if byteCount >= 1_073_741_824 {
            reasons.append(.oversizedVideo)
        }
        
        // 4. Screen recordings
        if name.contains("screen recording") || name.contains("ekran kaydı") || name.contains("enregistrement de l'écran") {
            if duration > 300.0 || byteCount > 500_000_000 {
                reasons.append(.longScreenRecording)
            }
        }
        
        // 5. Codec hints from extension or name
        let isProRes = name.contains("prores") || ext == "mov" && mbps > 25.0
        if isProRes {
            reasons.append(.proResOrRawCodec)
        }
        
        guard !reasons.isEmpty else { return nil }
        
        return HeavyMediaReport(
            id: "heavy:\(asset.id)",
            assetID: asset.id,
            durationSeconds: duration,
            byteCount: byteCount,
            megabytesPerSecond: (mbps * 10).rounded() / 10.0,
            codecName: isProRes ? "Apple ProRes" : "H.264/HEVC",
            reasons: reasons,
            estimatedSpaceSavingsBytes: byteCount
        )
    }
}
