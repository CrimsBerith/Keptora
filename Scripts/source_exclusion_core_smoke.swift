#if os(Linux)
import Foundation

@main
struct SourceExclusionCoreSmoke {
    static func main() throws {
        let root = URL(fileURLWithPath: "/Library")
        let decomposed = "Re\u{301}sume\u{301}"
        let policy = SourceExclusionPolicy(folderNames: ["Résumé", ".Cullora Quarantine"], extensions: [".JPG", " XMP "])
        guard policy.excludes(root.appendingPathComponent(decomposed).appendingPathComponent("IMG.PNG"), root: root) else {
            fatalError("Unicode normalization failed")
        }
        guard policy.excludes(root.appendingPathComponent(".CULLORA QUARANTINE/plan/copy.png"), root: root) else {
            fatalError("Case-insensitive quarantine exclusion failed")
        }
        guard policy.excludes(root.appendingPathComponent("Photo.jPg"), root: root) else {
            fatalError("Extension normalization failed")
        }
        guard !policy.excludes(root.appendingPathComponent("Photo.png"), root: root) else {
            fatalError("Unrelated extension incorrectly excluded")
        }
        print("Phase 5O source exclusion smoke passed: Unicode, case, extension boundaries.")
    }
}
#endif
