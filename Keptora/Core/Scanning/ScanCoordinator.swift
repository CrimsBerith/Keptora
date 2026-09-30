import Foundation

actor ScanCoordinator {
    private let database: SQLiteDatabase
    private let enumerator = FolderEnumerator()
    private let hasher = ExactHasher()
    private let familyBuilder = AssetFamilyGraphBuilder()

    init(database: SQLiteDatabase) {
        self.database = database
    }

    func scan(
        folder: URL,
        keeperPolicy: KeeperSelectionPolicy = .preserve,
        progress: @escaping @Sendable (ScanProgress) async -> Void
    ) async throws -> ScanOutcome {
        try await database.initialize()
        let volume = try? VolumeIdentity.resolve(for: folder)
        let sourceID = volume.map { SourceIdentity.folderID(for: folder, volume: $0) }
            ?? SourceIdentity.folderID(for: folder)
        var session = try await database.beginOrResumeScanSession(
            sourceID: sourceID,
            sourcePath: folder.standardizedFileURL.path,
            volumeID: volume?.stableID
        )

        await progress(
            ScanProgress(
                phase: .discovering,
                processed: session.processed,
                total: session.total,
                currentItem: folder.lastPathComponent,
                message: session.cursorStableKey == nil ? "Reading folder metadata" : "Resuming from the last durable checkpoint"
            )
        )

        let urls = try enumerator.mediaFiles(in: folder)
        let descriptors = try urls.map { try descriptor(for: $0, sourceID: sourceID) }

        var startIndex = 0
        if let cursor = session.cursorStableKey,
           let cursorIndex = descriptors.firstIndex(where: { $0.stableKey == cursor }) {
            let candidateStart = descriptors.index(after: cursorIndex)
            var prefixIsDurable = candidateStart == session.processed
            if prefixIsDurable {
                for descriptor in descriptors.prefix(candidateStart) {
                    guard let state = try await database.indexState(sourceID: sourceID, stableKey: descriptor.stableKey),
                          state.lastSeenScanID == session.id,
                          state.matches(byteCount: descriptor.byteCount, modificationDate: descriptor.modificationDate) else {
                        prefixIsDurable = false
                        break
                    }
                }
            }
            if prefixIsDurable {
                startIndex = candidateStart
            } else {
                session = try await database.restartScanSession(
                    replacing: session.id,
                    sourceID: sourceID,
                    sourcePath: folder.standardizedFileURL.path,
                    volumeID: volume?.stableID
                )
            }
        } else if session.processed > 0 || session.cursorStableKey != nil {
            session = try await database.restartScanSession(
                replacing: session.id,
                sourceID: sourceID,
                sourcePath: folder.standardizedFileURL.path,
                volumeID: volume?.stableID
            )
        }

        // Configurable in Settings; clamped to the same range the stepper allows.
        let storedInterval = UserDefaults.standard.integer(forKey: "Keptora.CheckpointInterval")
        let checkpointInterval = storedInterval > 0 ? min(max(storedInterval, 25), 500) : 100

        var processed = startIndex
        var hashed = startIndex > 0 ? session.hashed : 0
        var reused = startIndex > 0 ? session.reused : 0
        var lastCursor = startIndex > 0 ? descriptors[startIndex - 1].stableKey : nil

        do {
            for descriptor in descriptors.dropFirst(startIndex) {
                try Task.checkCancellation()
                let state = try await database.indexState(sourceID: sourceID, stableKey: descriptor.stableKey)
                if let state, state.matches(byteCount: descriptor.byteCount, modificationDate: descriptor.modificationDate) {
                    try await database.touchUnchangedAsset(descriptor, scanID: session.id)
                    reused += 1
                } else {
                    let fingerprint = try await hasher.hashFile(at: descriptor.fileURL)
                    try await database.upsert(asset: descriptor, fingerprint: fingerprint, scanID: session.id)
                    hashed += 1
                }

                processed += 1
                lastCursor = descriptor.stableKey
                await progress(
                    ScanProgress(
                        phase: .hashing,
                        processed: processed,
                        total: descriptors.count,
                        currentItem: descriptor.displayName,
                        message: "\(hashed) hashed · \(reused) reused"
                    )
                )
                if processed % checkpointInterval == 0 {
                    try await database.updateScanCheckpoint(
                        id: session.id,
                        processed: processed,
                        total: descriptors.count,
                        hashed: hashed,
                        reused: reused,
                        phase: "hashing",
                        cursorStableKey: lastCursor
                    )
                }
            }

            let families = familyBuilder.build(from: descriptors)
            try await database.replaceAssetFamilies(sourceID: sourceID, families: families)
            let missing = try await database.markMissingAssets(sourceID: sourceID, notSeenIn: session.id)
            await progress(
                ScanProgress(
                    phase: .grouping,
                    processed: processed,
                    total: descriptors.count,
                    currentItem: nil,
                    message: "Refreshing exact groups and \(families.count) protected asset families"
                )
            )
            try await database.rebuildExactGroups(keeperPolicy: keeperPolicy)
            try await database.finishScanSession(
                id: session.id,
                processed: processed,
                total: descriptors.count,
                hashed: hashed,
                reused: reused,
                missing: missing
            )
            let groups = try await database.fetchDuplicateGroups(sourceID: sourceID)
            return ScanOutcome(groups: groups, discovered: descriptors.count, hashed: hashed, reused: reused, missing: missing)
        } catch {
            try? await database.pauseScanSession(
                id: session.id,
                processed: processed,
                total: descriptors.count,
                hashed: hashed,
                reused: reused,
                cursorStableKey: lastCursor
            )
            throw error
        }
    }

    private func descriptor(for url: URL, sourceID: SourceID) throws -> AssetDescriptor {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey, .contentModificationDateKey])
        let stableKey = url.standardizedFileURL.path
        let byteCount = Int64(values.fileSize ?? 0)
        let id = AssetID(rawValue: Self.assetIdentifier(sourceID: sourceID, stableKey: stableKey))
        return AssetDescriptor(
            id: id,
            sourceID: sourceID,
            stableKey: stableKey,
            displayName: url.lastPathComponent,
            fileURL: url,
            mediaKind: enumerator.mediaKind(for: url),
            byteCount: byteCount,
            pixelWidth: nil,
            pixelHeight: nil,
            creationDate: values.creationDate,
            modificationDate: values.contentModificationDate
        )
    }

    private static func assetIdentifier(sourceID: SourceID, stableKey: String) -> String {
        "asset:" + stableDigest(sourceID.rawValue + "|" + stableKey)
    }

    private static func stableDigest(_ value: String) -> String {
        var hash: UInt64 = 14695981039346656037
        for byte in value.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1099511628211
        }
        return String(hash, radix: 16)
    }
}
