import Foundation

enum KeptoraMetadataTools {
    enum Risk: Int, Codable, Comparable, Sendable { case clean = 0, review = 1, sensitive = 3; static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue } }
    enum Category: String, Codable, CaseIterable, Sendable { case location, creator, device, software, keywords, timing }
    struct Asset: Identifiable, Codable, Hashable, Sendable {
        let id: UUID; let name: String; let byteCount: Int64; let fileExtension: String; let findings: Set<Category>
        init(id: UUID = UUID(), name: String, byteCount: Int64, fileExtension: String, findings: Set<Category>) { self.id = id; self.name = name; self.byteCount = byteCount; self.fileExtension = fileExtension.lowercased(); self.findings = findings }
        var risk: Risk { !findings.isDisjoint(with: [.location, .device]) ? .sensitive : (findings.isEmpty ? .clean : .review) }
    }
    struct Policy: Codable, Hashable, Sendable {
        var removeLocation = true; var removeCreator = false; var removeDevice = true; var removeSoftware = true; var shiftCaptureTime = false
        func resolves(_ category: Category) -> Bool { switch category { case .location: removeLocation; case .creator: removeCreator; case .device: removeDevice; case .software: removeSoftware; case .timing: shiftCaptureTime; case .keywords: false } }
    }
    struct Impact: Sendable { let assetID: UUID; let before: Risk; let predicted: Risk; let resolved: Set<Category>; let manualReview: Set<Category> }
    static func simulate(assets: [Asset], policy: Policy) -> [Impact] { assets.map { asset in
        let resolved = Set(asset.findings.filter(policy.resolves)), remaining = asset.findings.subtracting(resolved); let predicted: Risk = !remaining.isDisjoint(with: [.location, .device]) ? .sensitive : (remaining.isEmpty ? .clean : .review)
        return .init(assetID: asset.id, before: asset.risk, predicted: predicted, resolved: resolved, manualReview: remaining)
    }}
    static let writableExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "tif", "tiff"]
    static func estimatedExportBytes(_ assets: [Asset]) -> Int64 { let bytes = assets.filter { writableExtensions.contains($0.fileExtension) }.reduce(Int64(0)) { $0 + max(0, $1.byteCount) }; return max(16 * 1_024 * 1_024, Int64((Double(bytes) * 1.20).rounded(.up)) + 16 * 1_024 * 1_024) }
}
