import Foundation

struct SourceExclusionPolicy: Sendable {
    static let folderDefaultsKey = "Cullora.ExcludedFolderNames"
    static let extensionDefaultsKey = "Cullora.ExcludedExtensions"

    let folderNames: Set<String>
    let extensions: Set<String>

    init(folderNames: Set<String>, extensions: Set<String>) {
        self.folderNames = Set(folderNames.map(Self.normalizeFolderName).filter { !$0.isEmpty })
        self.extensions = Set(extensions.map(Self.normalizeExtension).filter { !$0.isEmpty })
    }

    static func current(defaults: UserDefaults = .standard) -> SourceExclusionPolicy {
        let builtInFolders = [".Cullora Quarantine", "@eaDir", "node_modules", ".git"]
        let customFolders = defaults.string(forKey: folderDefaultsKey)?
            .split(separator: ",")
            .map(String.init) ?? []
        let customExtensions = defaults.string(forKey: extensionDefaultsKey)?
            .split(separator: ",")
            .map(String.init) ?? []
        return SourceExclusionPolicy(
            folderNames: Set(builtInFolders + customFolders),
            extensions: Set(customExtensions)
        )
    }

    func excludes(_ url: URL, root: URL) -> Bool {
        let rootComponents = root.standardizedFileURL.pathComponents
        let urlComponents = url.standardizedFileURL.pathComponents
        let relativeComponents: ArraySlice<String>
        if urlComponents.starts(with: rootComponents) {
            relativeComponents = urlComponents.dropFirst(rootComponents.count)
        } else {
            relativeComponents = urlComponents[...]
        }

        let directoryComponents = relativeComponents.dropLast().map(Self.normalizeFolderName)
        if directoryComponents.contains(where: folderNames.contains) { return true }
        return extensions.contains(Self.normalizeExtension(url.pathExtension))
    }

    static func normalizeFolderName(_ value: String) -> String {
        normalize(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func normalizeExtension(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "."))
        return normalize(trimmed)
    }

    private static func normalize(_ value: String) -> String {
        value
            .precomposedStringWithCanonicalMapping
            .folding(options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .precomposedStringWithCanonicalMapping
    }
}

struct FolderEnumerator: Sendable {
    private let supportedExtensions: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "gif", "bmp", "webp",
        "dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2",
        "mov", "mp4", "m4v", "avi", "mkv",
        "xmp", "aae"
    ]

    func mediaFiles(in root: URL) throws -> [URL] {
        let keys: [URLResourceKey] = [.isRegularFileKey, .isHiddenKey, .fileSizeKey, .contentModificationDateKey]
        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, _ in true }
        ) else { return [] }

        let exclusionPolicy = SourceExclusionPolicy.current()
        var results: [URL] = []
        for case let url as URL in enumerator {
            try Task.checkCancellation()
            let values = try? url.resourceValues(forKeys: Set(keys))
            guard values?.isRegularFile == true else { continue }
            guard !exclusionPolicy.excludes(url, root: root) else { continue }
            guard supportedExtensions.contains(SourceExclusionPolicy.normalizeExtension(url.pathExtension)) else { continue }
            results.append(url)
        }
        return results.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }

    func mediaKind(for url: URL) -> MediaKind {
        switch SourceExclusionPolicy.normalizeExtension(url.pathExtension) {
        case "mov", "mp4", "m4v", "avi", "mkv": return .video
        case "xmp", "aae": return .sidecar
        case "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "gif", "bmp", "webp", "dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2": return .image
        default: return .unknown
        }
    }
}
