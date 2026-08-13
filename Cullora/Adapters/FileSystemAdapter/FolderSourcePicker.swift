import AppKit
import Foundation

enum FolderSourcePicker {
    @MainActor
    static func chooseFolder(startingAt directoryURL: URL? = nil) -> URL? {
        let panel = NSOpenPanel()
        panel.title = "Choose a photo or cloud folder"
        panel.message = "Choose a folder from this Mac, iCloud Drive, or a cloud provider connected in Finder. Cullora scans it locally and read-only."
        panel.prompt = "Choose Folder"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.directoryURL = directoryURL
        return panel.runModal() == .OK ? panel.url : nil
    }

    static func cloudStartURL() -> URL? {
        let fileManager = FileManager.default
        let library = fileManager.urls(for: .libraryDirectory, in: .userDomainMask).first
        let cloudStorage = library?.appendingPathComponent("CloudStorage", isDirectory: true)
        if let cloudStorage, fileManager.fileExists(atPath: cloudStorage.path) { return cloudStorage }
        let iCloudDrive = library?.appendingPathComponent("Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        if let iCloudDrive, fileManager.fileExists(atPath: iCloudDrive.path) { return iCloudDrive }
        return nil
    }

    static func providerLabel(for url: URL) -> String {
        let path = url.standardizedFileURL.path
        if path.contains("/Mobile Documents/com~apple~CloudDocs") { return "iCloud Drive" }
        if path.contains("/Library/CloudStorage/") {
            let components = path.split(separator: "/")
            if let index = components.firstIndex(of: "CloudStorage"), components.count > index + 1 {
                let raw = String(components[index + 1])
                let label = raw
                    .replacingOccurrences(of: "-", with: " ")
                    .replacingOccurrences(of: "_", with: " ")
                return label.isEmpty ? "Cloud provider" : label
            }
            return "Cloud provider"
        }
        if path.hasPrefix("/Volumes/") { return "External volume" }
        return "On this Mac"
    }
}
