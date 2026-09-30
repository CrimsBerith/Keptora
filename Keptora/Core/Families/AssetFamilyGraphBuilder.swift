import Foundation
import KeptoraCore

struct AssetFamilyGraphBuilder: Sendable {
    private let rawExtensions: Set<String> = SupportedMediaExtensions.rawImages
    private let renderedExtensions: Set<String> = SupportedMediaExtensions.standardImages
    private let motionExtensions: Set<String> = ["mov"]
    private let sidecarExtensions: Set<String> = SupportedMediaExtensions.sidecars

    func build(from assets: [AssetDescriptor]) -> [AssetFamily] {
        let grouped = Dictionary(grouping: assets) { asset in
            let directory = asset.fileURL.deletingLastPathComponent().standardizedFileURL.path
            return directory + "|" + normalizedStem(for: asset.fileURL)
        }

        return grouped.values.compactMap(classify).sorted { $0.id < $1.id }
    }

    private func classify(_ members: [AssetDescriptor]) -> AssetFamily? {
        guard members.count > 1, let first = members.first else { return nil }
        let extensions = Set(members.map { $0.fileURL.pathExtension.lowercased() })
        let rawStems = Set(members.map { rawStem(for: $0.fileURL) })
        let hasRaw = !extensions.isDisjoint(with: rawExtensions)
        let hasRendered = !extensions.isDisjoint(with: renderedExtensions)
        let hasMotion = !extensions.isDisjoint(with: motionExtensions)
        let hasXMP = extensions.contains("xmp")
        let hasAAE = extensions.contains("aae")
        let hasDerivativeName = members.contains { normalizedStem(for: $0.fileURL) != rawStem(for: $0.fileURL) }
        let hasExplicitBurstName = members.contains { isExplicitBurstName($0.fileURL) }

        let kind: AssetFamilyKind
        let policy: FamilySafetyPolicy
        if hasMotion && hasRendered && rawStems.count == 1 {
            kind = .livePhoto
            policy = .allOrNothing
        } else if hasRaw && (hasRendered || hasXMP) {
            kind = .rawBundle
            policy = .allOrNothing
        } else if (hasXMP || hasAAE) && (hasRendered || hasRaw) {
            kind = .sidecarBundle
            policy = .allOrNothing
        } else if hasExplicitBurstName && members.allSatisfy({ $0.mediaKind == .image }) {
            kind = .burst
            policy = .advisory
        } else if hasDerivativeName && members.filter({ $0.mediaKind == .image }).count > 1 {
            kind = .editedExport
            policy = .advisory
        } else {
            return nil
        }

        let directory = first.fileURL.deletingLastPathComponent().standardizedFileURL.path
        let stem = normalizedStem(for: first.fileURL)
        let familyID = "family:" + StableDigest.fnv1a64(first.sourceID.rawValue + "|" + directory + "|" + stem + "|" + kind.rawValue)
        let familyMembers = members.sorted { $0.fileURL.path < $1.fileURL.path }.map { asset in
            AssetFamilyMember(
                assetID: asset.id,
                role: role(for: asset.fileURL, familyKind: kind),
                displayName: asset.displayName,
                fileURL: asset.fileURL
            )
        }
        return AssetFamily(
            id: familyID,
            sourceID: first.sourceID,
            kind: kind,
            policy: policy,
            normalizedStem: stem,
            directoryPath: directory,
            members: familyMembers
        )
    }

    private func role(for url: URL, familyKind: AssetFamilyKind) -> AssetFamilyRole {
        let ext = url.pathExtension.lowercased()
        if rawExtensions.contains(ext) { return .raw }
        if ext == "mov" && familyKind == .livePhoto { return .motion }
        if sidecarExtensions.contains(ext) { return .sidecar }
        if familyKind == .burst { return .burstMember }
        let stem = rawStem(for: url)
        if stem.hasSuffix("-edited") || stem.hasSuffix("_edited") || stem.hasSuffix(" edit") { return .edited }
        if stem.hasSuffix("-export") || stem.hasSuffix("_export") || stem.hasSuffix(" export") { return .exported }
        if renderedExtensions.contains(ext) && familyKind == .rawBundle { return .rendered }
        return .primary
    }

    private func rawStem(for url: URL) -> String {
        url.deletingPathExtension().lastPathComponent.lowercased()
    }

    private func normalizedStem(for url: URL) -> String {
        var value = rawStem(for: url)
        let suffixes = ["-edited", "_edited", " edited", "-edit", "_edit", " edit", "-export", "_export", " export", "-copy", "_copy", " copy"]
        var changed = true
        while changed {
            changed = false
            for suffix in suffixes where value.hasSuffix(suffix) {
                value.removeLast(suffix.count)
                changed = true
            }
            if let range = value.range(of: #"\s*\(\d+\)$"#, options: .regularExpression) {
                value.removeSubrange(range)
                changed = true
            }
            if let range = value.range(
                of: #"(?i)(?:[_\- ]?burst[_\- ]?\d+)$"#,
                options: .regularExpression
            ) {
                value.removeSubrange(range)
                changed = true
            }
        }
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isExplicitBurstName(_ url: URL) -> Bool {
        rawStem(for: url).range(
            of: #"(?i)(?:^|[_\- ])burst[_\- ]?\d+$"#,
            options: .regularExpression
        ) != nil
    }
}
