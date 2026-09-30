import Foundation

/// Low-overhead on-device folder watchdog that monitors directories (e.g. Downloads, Desktop)
/// for incoming duplicate files using DispatchSource with near-zero energy impact.
public actor FolderWatchdogService {
    public enum WatchdogStatus: Sendable {
        case stopped
        case monitoring(path: String)
        case error(String)
    }
    
    private var source: (any DispatchSourceFileSystemObject)?
    private var fileDescriptor: CInt = -1
    private(set) public var status: WatchdogStatus = .stopped
    private var knownDigests: Set<String> = []
    
    public init() {}
    
    /// Updates the known digest set for instant matching.
    public func setKnownDigests(_ digests: Set<String>) {
        self.knownDigests = digests
    }
    
    /// Starts low-power background monitoring on the specified folder.
    public func startMonitoring(
        folderURL: URL,
        onDuplicateDetected: @escaping @Sendable (_ filename: String, _ matchDigest: String) -> Void
    ) {
        stopMonitoring()
        
        let fd = open(folderURL.path, O_EVTONLY)
        guard fd >= 0 else {
            status = .error("Failed to open directory file descriptor")
            return
        }
        
        self.fileDescriptor = fd
        let dispatchSource = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib],
            queue: DispatchQueue.global(qos: .utility)
        )
        
        dispatchSource.setEventHandler { [weak self] in
            guard let self else { return }
            Task {
                await self.checkForNewFiles(in: folderURL, onDuplicateDetected: onDuplicateDetected)
            }
        }
        
        dispatchSource.setCancelHandler { [fd] in
            close(fd)
        }
        
        dispatchSource.resume()
        self.source = dispatchSource
        self.status = .monitoring(path: folderURL.path)
    }
    
    /// Halts active monitoring and closes descriptors.
    public func stopMonitoring() {
        if let source {
            source.cancel()
            self.source = nil
        }
        if fileDescriptor >= 0 {
            close(fileDescriptor)
            fileDescriptor = -1
        }
        status = .stopped
    }
    
    private func checkForNewFiles(
        in folderURL: URL,
        onDuplicateDetected: @escaping @Sendable (_ filename: String, _ matchDigest: String) -> Void
    ) {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: folderURL,
            includingPropertiesForKeys: [.contentModificationDateKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else { return }
        
        // Scan newly added files
        let recentCutoff = Date().addingTimeInterval(-15) // modified in last 15 seconds
        for file in files {
            guard let values = try? file.resourceValues(forKeys: [.contentModificationDateKey, .fileSizeKey]),
                  let modDate = values.contentModificationDate,
                  modDate >= recentCutoff,
                  let size = values.fileSize, size > 0 else {
                continue
            }
            
            // Check digest if file has completed writing
            if let data = try? Data(contentsOf: file, options: .mappedIfSafe) {
                let digest = data.prefix(1024 * 1024).map { String(format: "%02x", $0) }.joined()
                if self.knownDigests.contains(digest) {
                    onDuplicateDetected(file.lastPathComponent, digest)
                }
            }
        }
    }
}
