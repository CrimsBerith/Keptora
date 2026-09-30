import Foundation

/// Itemized audit entry for every quarantined or deleted asset in a cleanup session.
public struct CleanupReceiptItem: Codable, Sendable, Hashable {
    public let assetID: String
    public let displayName: String
    public let mediaKind: String
    public let byteCount: Int64
    public let digest: String?
    public let destination: String
    public let timestamp: Date
    
    public init(
        assetID: String,
        displayName: String,
        mediaKind: String,
        byteCount: Int64,
        digest: String?,
        destination: String,
        timestamp: Date = Date()
    ) {
        self.assetID = assetID
        self.displayName = displayName
        self.mediaKind = mediaKind
        self.byteCount = byteCount
        self.digest = digest
        self.destination = destination
        self.timestamp = timestamp
    }
}

/// Official verifiable cleanup certificate and recovery receipt.
public struct CleanupSessionReceipt: Codable, Sendable {
    public let sessionID: String
    public let sourceKind: String
    public let completedAt: Date
    public let totalItemsCleaned: Int
    public let totalBytesReclaimed: Int64
    public let items: [CleanupReceiptItem]
    
    public init(
        sessionID: String = UUID().uuidString,
        sourceKind: String,
        completedAt: Date = Date(),
        items: [CleanupReceiptItem]
    ) {
        self.sessionID = sessionID
        self.sourceKind = sourceKind
        self.completedAt = completedAt
        self.items = items
        self.totalItemsCleaned = items.count
        self.totalBytesReclaimed = items.reduce(0) { $0 + $1.byteCount }
    }
    
    public var formattedReclaimedSpace: String {
        ByteCountFormatter.string(fromByteCount: totalBytesReclaimed, countStyle: .file)
    }
    
    /// Generates structured JSON data for audit export.
    public func exportJSONData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

/// Utility for recording, exporting, and managing audit receipts.
public enum CleanupReceiptExporter: Sendable {
    
    public static func makeReceipt(
        sourceKind: String,
        cleanedAssets: [UniversalMediaAsset],
        destinationDescription: String
    ) -> CleanupSessionReceipt {
        let items = cleanedAssets.map { asset in
            CleanupReceiptItem(
                assetID: asset.id,
                displayName: asset.displayName,
                mediaKind: asset.mediaKind.rawValue,
                byteCount: asset.byteCount ?? 0,
                digest: nil,
                destination: destinationDescription
            )
        }
        return CleanupSessionReceipt(sourceKind: sourceKind, items: items)
    }
}
