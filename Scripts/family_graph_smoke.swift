#if os(Linux)
import Foundation

@main
struct FamilyGraphSmoke {
    static func main() throws {
        let source = SourceID(rawValue: "family-smoke")
        let root = URL(fileURLWithPath: "/tmp/cullora-family-smoke")
        let oldVolume = VolumeIdentity(
            stableID: "volume:abc", uuid: "ABC", name: "Archive", rootPath: "/Volumes/Archive",
            isRemovable: true, isLocal: true
        )
        let renamedVolume = VolumeIdentity(
            stableID: "volume:abc", uuid: "ABC", name: "Archive 2026", rootPath: "/Volumes/Archive 2026",
            isRemovable: true, isLocal: true
        )
        guard SourceIdentity.folderID(
            for: URL(fileURLWithPath: "/Volumes/Archive/Photos/Library"), volume: oldVolume
        ) == SourceIdentity.folderID(
            for: URL(fileURLWithPath: "/Volumes/Archive 2026/Photos/Library"), volume: renamedVolume
        ) else {
            fatalError("Volume-stable source identity failed")
        }
        let specs: [(String, MediaKind)] = [
            ("IMG_1000.CR3", .image), ("IMG_1000.JPG", .image), ("IMG_1000.XMP", .sidecar),
            ("IMG_2000.HEIC", .image), ("IMG_2000.MOV", .video),
            ("portrait.jpg", .image), ("portrait-edited.jpg", .image),
            ("IMG_3000_BURST001.jpg", .image), ("IMG_3000_BURST002.jpg", .image)
        ]
        let assets = specs.map { name, kind in
            let url = root.appendingPathComponent(name)
            return AssetDescriptor(
                id: AssetID(rawValue: name.lowercased()), sourceID: source, stableKey: url.path,
                displayName: name, fileURL: url, mediaKind: kind, byteCount: 10,
                pixelWidth: nil, pixelHeight: nil, creationDate: nil, modificationDate: nil
            )
        }
        let families = AssetFamilyGraphBuilder().build(from: assets)
        guard families.count == 4 else { fatalError("Expected 4 families, got \(families.count)") }
        guard families.contains(where: { $0.kind == .rawBundle && $0.members.count == 3 && $0.policy == .allOrNothing }) else {
            fatalError("RAW bundle classification failed")
        }
        guard families.contains(where: { $0.kind == .livePhoto && Set($0.members.map(\.role)) == Set([.primary, .motion]) }) else {
            fatalError("Live Photo classification failed")
        }
        guard families.contains(where: { $0.kind == .editedExport && $0.policy == .advisory }) else {
            fatalError("Edited/export classification failed")
        }
        guard families.contains(where: { $0.kind == .burst && $0.policy == .advisory && $0.members.allSatisfy { $0.role == .burstMember } }) else {
            fatalError("Burst classification failed")
        }
        print("Phase 5H family graph smoke passed: RAW/JPEG/XMP, Live Photo, burst, and edited/export families.")
    }
}
#endif
