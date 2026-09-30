import Foundation

struct PerceptualHash64: Hashable, Codable, Sendable {
    let rawValue: UInt64

    init(_ rawValue: UInt64) {
        self.rawValue = rawValue
    }

    init?(hex: String) {
        guard let value = UInt64(hex, radix: 16) else { return nil }
        rawValue = value
    }

    var hex: String { String(format: "%016llx", rawValue) }

    func hammingDistance(to other: PerceptualHash64) -> Int {
        Int((rawValue ^ other.rawValue).nonzeroBitCount)
    }

    func candidateBands(bitWidth: Int = 16, rotationOffsets: [Int] = [0, 8]) -> [Int] {
        precondition(bitWidth > 0 && 64 % bitWidth == 0)
        let bandsPerRotation = 64 / bitWidth
        let mask: UInt64 = bitWidth == 64 ? .max : (UInt64(1) << UInt64(bitWidth)) - 1
        return rotationOffsets.flatMap { offset -> [Int] in
            let normalized = offset % 64
            let rotated: UInt64
            if normalized == 0 {
                rotated = rawValue
            } else {
                rotated = (rawValue >> UInt64(normalized)) | (rawValue << UInt64(64 - normalized))
            }
            return (0..<bandsPerRotation).map { index in
                let shift = UInt64(index * bitWidth)
                return Int((rotated >> shift) & mask)
            }
        }
    }
}

struct CandidateIndexConfiguration: Hashable, Sendable {
    let bandBitWidth: Int
    let rotationOffsets: [Int]
    let maximumHammingDistance: Int
    let maximumCandidates: Int

    var totalBandCount: Int { (64 / bandBitWidth) * rotationOffsets.count }

    static let phase5I = CandidateIndexConfiguration(
        bandBitWidth: 16,
        rotationOffsets: [0, 8],
        maximumHammingDistance: 14,
        maximumCandidates: 400
    )
}

struct PerceptualCandidateIndex: Sendable {
    private var hashes: [AssetID: PerceptualHash64] = [:]
    private var buckets: [BandKey: Set<AssetID>] = [:]
    let configuration: CandidateIndexConfiguration

    init(configuration: CandidateIndexConfiguration = .phase5I) {
        self.configuration = configuration
    }

    mutating func insert(assetID: AssetID, hash: PerceptualHash64) {
        if let previous = hashes[assetID] { remove(assetID: assetID, hash: previous) }
        hashes[assetID] = hash
        for (index, value) in hash.candidateBands(bitWidth: configuration.bandBitWidth, rotationOffsets: configuration.rotationOffsets).enumerated() {
            buckets[BandKey(index: index, value: value), default: []].insert(assetID)
        }
    }

    mutating func remove(assetID: AssetID) {
        guard let hash = hashes.removeValue(forKey: assetID) else { return }
        remove(assetID: assetID, hash: hash)
    }

    func candidates(for hash: PerceptualHash64, excluding excludedID: AssetID? = nil) -> [AssetID] {
        var union: Set<AssetID> = []
        for (index, value) in hash.candidateBands(bitWidth: configuration.bandBitWidth, rotationOffsets: configuration.rotationOffsets).enumerated() {
            union.formUnion(buckets[BandKey(index: index, value: value)] ?? [])
        }
        if let excludedID { union.remove(excludedID) }
        return union.compactMap { id -> (AssetID, Int)? in
            guard let candidateHash = hashes[id] else { return nil }
            let distance = hash.hammingDistance(to: candidateHash)
            guard distance <= configuration.maximumHammingDistance else { return nil }
            return (id, distance)
        }
        .sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.0.rawValue < rhs.0.rawValue : lhs.1 < rhs.1 }
        .prefix(configuration.maximumCandidates)
        .map(\.0)
    }

    var count: Int { hashes.count }

    private mutating func remove(assetID: AssetID, hash: PerceptualHash64) {
        for (index, value) in hash.candidateBands(bitWidth: configuration.bandBitWidth, rotationOffsets: configuration.rotationOffsets).enumerated() {
            let key = BandKey(index: index, value: value)
            buckets[key]?.remove(assetID)
            if buckets[key]?.isEmpty == true { buckets.removeValue(forKey: key) }
        }
    }

    private struct BandKey: Hashable, Sendable {
        let index: Int
        let value: Int
    }
}
