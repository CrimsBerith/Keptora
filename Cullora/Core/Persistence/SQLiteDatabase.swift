import Foundation
import SQLite3

private let sqliteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private final class SQLiteConnection: @unchecked Sendable {
    let pointer: OpaquePointer

    init(_ pointer: OpaquePointer) {
        self.pointer = pointer
    }
}

actor SQLiteDatabase {
    enum DatabaseError: LocalizedError {
        case open(String)
        case execute(String)
        case prepare(String)
        case bind(String)
        case protectedCanonical
        case invalidDecisionTarget

        var errorDescription: String? {
            switch self {
            case .open(let message): return "Database could not be opened: \(message)"
            case .execute(let message): return "Database operation failed: \(message)"
            case .prepare(let message): return "Database statement could not be prepared: \(message)"
            case .bind(let message): return "Database value could not be written: \(message)"
            case .protectedCanonical: return "This file is the protected keeper. Choose another keeper before adding it to the Safety Plan."
            case .invalidDecisionTarget: return "The selected file no longer belongs to this duplicate group."
            }
        }
    }

    private let url: URL
    private var connection: SQLiteConnection?
    private var isInitialized = false

    init(url: URL) {
        self.url = url
    }

    deinit {
        if let connection { sqlite3_close(connection.pointer) }
    }

    func initialize() throws {
        guard !isInitialized else { return }
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var db: OpaquePointer?
        let flags = SQLITE_OPEN_CREATE | SQLITE_OPEN_READWRITE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(url.path, &db, flags, nil) == SQLITE_OK, let db else {
            throw DatabaseError.open(db.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown SQLite error")
        }
        connection = SQLiteConnection(db)
        try execute("PRAGMA journal_mode=WAL;")
        try execute("PRAGMA foreign_keys=ON;")
        try execute("PRAGMA busy_timeout=5000;")
        try migrateIfNeeded()
        isInitialized = true
    }

    // MARK: - Incremental scan lifecycle

    func beginScanSession(id: String, sourceID: SourceID, sourcePath: String) throws {
        try initialize()
        try executePrepared(
            """
            INSERT OR REPLACE INTO scan_sessions(
                id, source_id, source_path, state, phase, processed, total, hashed, reused, missing, started_at, finished_at
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,NULL)
            """,
            [
                .text(id), .text(sourceID.rawValue), .text(sourcePath), .text("running"), .text("discovering"),
                .int(0), .int(0), .int(0), .int(0), .int(0), .double(Date().timeIntervalSince1970)
            ]
        )
    }

    func updateScanCheckpoint(id: String, processed: Int, total: Int, hashed: Int, reused: Int, phase: String, cursorStableKey: String? = nil) throws {
        try executePrepared(
            "UPDATE scan_sessions SET processed=?, total=?, hashed=?, reused=?, phase=?, cursor_stable_key=? WHERE id=?",
            [
                .int(Int64(processed)), .int(Int64(total)), .int(Int64(hashed)), .int(Int64(reused)), .text(phase),
                cursorStableKey.map { .text($0) } ?? .null, .text(id)
            ]
        )
    }

    func beginOrResumeScanSession(sourceID: SourceID, sourcePath: String, volumeID: String?) throws -> ResumableScanSession {
        try initialize()
        if let row = try rows(
            """
            SELECT id, cursor_stable_key, processed, total, hashed, reused, source_volume_id
            FROM scan_sessions
            WHERE source_id=? AND source_path=? AND state IN ('running','paused')
              AND COALESCE(source_volume_id,'')=COALESCE(?, '')
            ORDER BY started_at DESC LIMIT 1
            """,
            [.text(sourceID.rawValue), .text(sourcePath), volumeID.map { .text($0) } ?? .null]
        ).first,
        let id = row["id"]?.string {
            try executePrepared("UPDATE scan_sessions SET state='running', phase='discovering' WHERE id=?", [.text(id)])
            return ResumableScanSession(
                id: id,
                cursorStableKey: row["cursor_stable_key"]?.string,
                processed: Int(row["processed"]?.int64 ?? 0),
                total: Int(row["total"]?.int64 ?? 0),
                hashed: Int(row["hashed"]?.int64 ?? 0),
                reused: Int(row["reused"]?.int64 ?? 0),
                volumeID: row["source_volume_id"]?.string
            )
        }

        let id = UUID().uuidString.lowercased()
        try executePrepared(
            """
            INSERT INTO scan_sessions(
                id, source_id, source_path, state, phase, processed, total, hashed, reused, missing,
                started_at, finished_at, cursor_stable_key, source_volume_id
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,NULL,NULL,?)
            """,
            [
                .text(id), .text(sourceID.rawValue), .text(sourcePath), .text("running"), .text("discovering"),
                .int(0), .int(0), .int(0), .int(0), .int(0), .double(Date().timeIntervalSince1970),
                volumeID.map { .text($0) } ?? .null
            ]
        )
        return ResumableScanSession(id: id, cursorStableKey: nil, processed: 0, total: 0, hashed: 0, reused: 0, volumeID: volumeID)
    }

    func restartScanSession(
        replacing previousID: String,
        sourceID: SourceID,
        sourcePath: String,
        volumeID: String?
    ) throws -> ResumableScanSession {
        try initialize()
        try executePrepared(
            "UPDATE scan_sessions SET state='superseded', phase='source-changed', finished_at=? WHERE id=?",
            [.double(Date().timeIntervalSince1970), .text(previousID)]
        )
        let id = UUID().uuidString.lowercased()
        try executePrepared(
            """
            INSERT INTO scan_sessions(
                id, source_id, source_path, state, phase, processed, total, hashed, reused, missing,
                started_at, finished_at, cursor_stable_key, source_volume_id
            ) VALUES(?,?,?,?,?,?,?,?,?,?,?,NULL,NULL,?)
            """,
            [
                .text(id), .text(sourceID.rawValue), .text(sourcePath), .text("running"), .text("discovering"),
                .int(0), .int(0), .int(0), .int(0), .int(0), .double(Date().timeIntervalSince1970),
                volumeID.map { .text($0) } ?? .null
            ]
        )
        return ResumableScanSession(
            id: id,
            cursorStableKey: nil,
            processed: 0,
            total: 0,
            hashed: 0,
            reused: 0,
            volumeID: volumeID
        )
    }

    func pauseScanSession(id: String, processed: Int, total: Int, hashed: Int, reused: Int, cursorStableKey: String?) throws {
        try initialize()
        try executePrepared(
            "UPDATE scan_sessions SET state='paused', phase='paused', processed=?, total=?, hashed=?, reused=?, cursor_stable_key=? WHERE id=?",
            [
                .int(Int64(processed)), .int(Int64(total)), .int(Int64(hashed)), .int(Int64(reused)),
                cursorStableKey.map { .text($0) } ?? .null, .text(id)
            ]
        )
    }

    func finishScanSession(id: String, processed: Int, total: Int, hashed: Int, reused: Int, missing: Int) throws {
        try executePrepared(
            """
            UPDATE scan_sessions
            SET state='completed', phase='completed', processed=?, total=?, hashed=?, reused=?, missing=?, finished_at=?
            WHERE id=?
            """,
            [
                .int(Int64(processed)), .int(Int64(total)), .int(Int64(hashed)), .int(Int64(reused)),
                .int(Int64(missing)), .double(Date().timeIntervalSince1970), .text(id)
            ]
        )
    }

    func indexState(sourceID: SourceID, stableKey: String) throws -> IndexedAssetState? {
        try initialize()
        guard let row = try rows(
            """
            SELECT a.id, a.byte_count, a.modified_at, a.is_quarantined, a.last_seen_scan_id, f.digest
            FROM assets a
            LEFT JOIN exact_fingerprints f ON f.asset_id=a.id
            WHERE a.source_id=? AND a.stable_key=? LIMIT 1
            """,
            [.text(sourceID.rawValue), .text(stableKey)]
        ).first,
        let id = row["id"]?.string,
        let byteCount = row["byte_count"]?.int64 else { return nil }

        return IndexedAssetState(
            assetID: AssetID(rawValue: id),
            byteCount: byteCount,
            modificationDate: row["modified_at"]?.double.map { Date(timeIntervalSince1970: $0) },
            digest: row["digest"]?.string,
            isQuarantined: (row["is_quarantined"]?.int64 ?? 0) != 0,
            lastSeenScanID: row["last_seen_scan_id"]?.string
        )
    }

    func touchUnchangedAsset(_ asset: AssetDescriptor, scanID: String) throws {
        try initialize()
        try executePrepared(
            """
            UPDATE assets SET display_name=?, path=?, media_kind=?, created_at=?, modified_at=?, indexed_at=?,
                last_seen_scan_id=?, is_missing=0
            WHERE id=?
            """,
            [
                .text(asset.displayName), .text(asset.fileURL.path), .text(asset.mediaKind.rawValue),
                asset.creationDate.map { .double($0.timeIntervalSince1970) } ?? .null,
                asset.modificationDate.map { .double($0.timeIntervalSince1970) } ?? .null,
                .double(Date().timeIntervalSince1970), .text(scanID), .text(asset.id.rawValue)
            ]
        )
    }

    func upsert(asset: AssetDescriptor, fingerprint: ExactFingerprint, scanID: String? = nil) throws {
        try initialize()
        try transaction {
            try executePrepared(
                """
                INSERT INTO assets(
                    id, source_id, stable_key, display_name, path, media_kind, byte_count, created_at, modified_at,
                    indexed_at, last_seen_scan_id, is_missing, is_quarantined
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?,0)
                ON CONFLICT(id) DO UPDATE SET
                    source_id=excluded.source_id,
                    stable_key=excluded.stable_key,
                    display_name=excluded.display_name,
                    path=excluded.path,
                    media_kind=excluded.media_kind,
                    byte_count=excluded.byte_count,
                    created_at=excluded.created_at,
                    modified_at=excluded.modified_at,
                    indexed_at=excluded.indexed_at,
                    last_seen_scan_id=excluded.last_seen_scan_id,
                    is_missing=0,
                    is_quarantined=0
                """,
                [
                    .text(asset.id.rawValue), .text(asset.sourceID.rawValue), .text(asset.stableKey), .text(asset.displayName),
                    .text(asset.fileURL.path), .text(asset.mediaKind.rawValue), .int(asset.byteCount),
                    asset.creationDate.map { .double($0.timeIntervalSince1970) } ?? .null,
                    asset.modificationDate.map { .double($0.timeIntervalSince1970) } ?? .null,
                    .double(Date().timeIntervalSince1970), scanID.map { SQLiteValue.text($0) } ?? .null, .int(0)
                ]
            )
            try executePrepared(
                """
                INSERT INTO exact_fingerprints(asset_id, algorithm, digest, byte_count, revision)
                VALUES(?,?,?,?,1)
                ON CONFLICT(asset_id) DO UPDATE SET
                    algorithm=excluded.algorithm, digest=excluded.digest, byte_count=excluded.byte_count, revision=excluded.revision
                """,
                [.text(asset.id.rawValue), .text(fingerprint.algorithm), .text(fingerprint.digest), .int(fingerprint.byteCount)]
            )
        }
    }

    @discardableResult
    func markMissingAssets(sourceID: SourceID, notSeenIn scanID: String) throws -> Int {
        try initialize()
        return try executePreparedReturningChanges(
            """
            UPDATE assets SET is_missing=1
            WHERE source_id=? AND is_quarantined=0 AND (last_seen_scan_id IS NULL OR last_seen_scan_id<>?) AND is_missing=0
            """,
            [.text(sourceID.rawValue), .text(scanID)]
        )
    }

    // MARK: - Asset family graph

    func replaceAssetFamilies(sourceID: SourceID, families: [AssetFamily]) throws {
        try initialize()
        try transaction {
            try executePrepared("DELETE FROM asset_families WHERE source_id=?", [.text(sourceID.rawValue)])
            for family in families {
                try executePrepared(
                    """
                    INSERT INTO asset_families(id, source_id, kind, policy, normalized_stem, directory_path, created_at)
                    VALUES(?,?,?,?,?,?,?)
                    """,
                    [
                        .text(family.id), .text(sourceID.rawValue), .text(family.kind.rawValue), .text(family.policy.rawValue),
                        .text(family.normalizedStem), .text(family.directoryPath), .double(Date().timeIntervalSince1970)
                    ]
                )
                for member in family.members {
                    try executePrepared(
                        "INSERT INTO family_members(family_id, asset_id, role) VALUES(?,?,?)",
                        [.text(family.id), .text(member.assetID.rawValue), .text(member.role.rawValue)]
                    )
                }
            }
        }
    }

    func familyMembers(familyID: String) throws -> [FamilyMembershipRecord] {
        try initialize()
        return try rows(
            """
            SELECT af.id AS family_id, af.kind, af.policy, fm.asset_id, fm.role,
                   a.display_name, a.path, a.is_missing, a.is_quarantined
            FROM asset_families af
            JOIN family_members fm ON fm.family_id=af.id
            JOIN assets a ON a.id=fm.asset_id
            WHERE af.id=? ORDER BY a.path
            """,
            [.text(familyID)]
        ).compactMap { row in
            guard let id = row["family_id"]?.string,
                  let kindRaw = row["kind"]?.string, let kind = AssetFamilyKind(rawValue: kindRaw),
                  let policyRaw = row["policy"]?.string, let policy = FamilySafetyPolicy(rawValue: policyRaw),
                  let assetID = row["asset_id"]?.string,
                  let roleRaw = row["role"]?.string, let role = AssetFamilyRole(rawValue: roleRaw),
                  let name = row["display_name"]?.string,
                  let path = row["path"]?.string else { return nil }
            return FamilyMembershipRecord(
                familyID: id, kind: kind, policy: policy, assetID: AssetID(rawValue: assetID), role: role,
                displayName: name, path: path,
                isMissing: (row["is_missing"]?.int64 ?? 0) != 0,
                isQuarantined: (row["is_quarantined"]?.int64 ?? 0) != 0
            )
        }
    }

    private func familySummary(assetID: String) throws -> AssetFamilySummary? {
        guard let row = try rows(
            """
            SELECT af.id, af.kind, af.policy, fm.role, COUNT(all_members.asset_id) AS member_count
            FROM family_members fm
            JOIN asset_families af ON af.id=fm.family_id
            JOIN family_members all_members ON all_members.family_id=af.id
            WHERE fm.asset_id=?
            GROUP BY af.id, af.kind, af.policy, fm.role
            LIMIT 1
            """,
            [.text(assetID)]
        ).first,
        let id = row["id"]?.string,
        let kindRaw = row["kind"]?.string, let kind = AssetFamilyKind(rawValue: kindRaw),
        let policyRaw = row["policy"]?.string, let policy = FamilySafetyPolicy(rawValue: policyRaw),
        let roleRaw = row["role"]?.string, let role = AssetFamilyRole(rawValue: roleRaw) else { return nil }
        return AssetFamilySummary(id: id, kind: kind, policy: policy, role: role, memberCount: Int(row["member_count"]?.int64 ?? 0))
    }

    // MARK: - Exact groups and review decisions

    func rebuildExactGroups(keeperPolicy: KeeperSelectionPolicy = .preserve) throws {
        try initialize()
        try transaction {
            var previousCanonical: [String: String] = [:]
            for row in try rows("SELECT id, canonical_asset_id FROM comparison_groups WHERE kind='exact'") {
                if let id = row["id"]?.string, let canonical = row["canonical_asset_id"]?.string {
                    previousCanonical[id] = canonical
                }
            }

            try execute("DELETE FROM comparison_members WHERE group_id IN (SELECT id FROM comparison_groups WHERE kind='exact');")
            try execute("DELETE FROM comparison_groups WHERE kind='exact';")

            let candidates = try rows(
                """
                SELECT a.source_id, f.digest, f.byte_count, COUNT(*) AS member_count
                FROM exact_fingerprints f
                JOIN assets a ON a.id=f.asset_id
                WHERE a.is_missing=0 AND a.is_quarantined=0
                GROUP BY a.source_id, f.digest, f.byte_count HAVING COUNT(*) > 1
                ORDER BY f.byte_count DESC
                """
            )

            for candidate in candidates {
                guard let sourceID = candidate["source_id"]?.string,
                      let digest = candidate["digest"]?.string,
                      let byteCount = candidate["byte_count"]?.int64 else { continue }
                let groupID = "exact:\(sourceID):\(digest):\(byteCount)"
                let members = try rows(
                    """
                    SELECT a.id
                    FROM exact_fingerprints f JOIN assets a ON a.id=f.asset_id
                    WHERE a.source_id=? AND f.digest=? AND f.byte_count=? AND a.is_missing=0 AND a.is_quarantined=0
                    ORDER BY COALESCE(a.modified_at, 9223372036854775807) ASC, LENGTH(a.path) ASC, a.path ASC
                    """,
                    [.text(sourceID), .text(digest), .int(byteCount)]
                ).compactMap { $0["id"]?.string }
                guard let firstMember = members.first else { continue }

                let userKeeper = try rows(
                    "SELECT asset_id FROM decisions WHERE group_id=? AND action='keep' AND actor='user' ORDER BY updated_at DESC LIMIT 1",
                    [.text(groupID)]
                ).first?["asset_id"]?.string
                let canonical: String
                if let userKeeper, members.contains(userKeeper) { canonical = userKeeper }
                else if let old = previousCanonical[groupID], members.contains(old) { canonical = old }
                else if keeperPolicy == .preserve { canonical = firstMember }
                else {
                    let order: String
                    switch keeperPolicy {
                    case .oldest: order = "COALESCE(a.modified_at, 9223372036854775807) ASC, LENGTH(a.path) ASC, a.path ASC"
                    case .newest: order = "COALESCE(a.modified_at, 0) DESC, LENGTH(a.path) ASC, a.path ASC"
                    case .largest: order = "a.byte_count DESC, COALESCE(a.modified_at, 9223372036854775807) ASC, a.path ASC"
                    case .shortestPath: order = "LENGTH(a.path) ASC, a.path ASC"
                    case .preserve: order = "COALESCE(a.modified_at, 9223372036854775807) ASC, LENGTH(a.path) ASC, a.path ASC"
                    }
                    let selected = try rows(
                        """
                        SELECT a.id FROM exact_fingerprints f JOIN assets a ON a.id=f.asset_id
                        WHERE a.source_id=? AND f.digest=? AND f.byte_count=? AND a.is_missing=0 AND a.is_quarantined=0
                        ORDER BY \(order) LIMIT 1
                        """,
                        [.text(sourceID), .text(digest), .int(byteCount)]
                    ).first?["id"]?.string
                    canonical = selected ?? firstMember
                }

                try executePrepared(
                    """
                    INSERT INTO comparison_groups(id, kind, algorithm_revision, confidence, canonical_asset_id, created_at)
                    VALUES(?,?,?,?,?,?)
                    """,
                    [
                        .text(groupID), .text("exact"), .text("sha256-v1"), .text("exact"),
                        .text(canonical), .double(Date().timeIntervalSince1970)
                    ]
                )
                for (rank, assetID) in members.enumerated() {
                    try executePrepared(
                        "INSERT INTO comparison_members(group_id, asset_id, rank) VALUES(?,?,?)",
                        [.text(groupID), .text(assetID), .int(Int64(rank))]
                    )
                }
                try upsertDecision(groupID: groupID, assetID: canonical, action: .keep, actor: userKeeper == canonical ? "user" : "system", reason: "protected-canonical")
                try executePrepared(
                    "DELETE FROM decisions WHERE group_id=? AND action='keep' AND asset_id<>? AND actor='system'",
                    [.text(groupID), .text(canonical)]
                )
            }
        }
    }

    func fetchDuplicateGroups(sourceID: SourceID? = nil) throws -> [ReviewGroup] {
        try initialize()
        let sourceClause = sourceID == nil ? "" : " AND a.source_id=?"
        let groupRows = try rows(
            """
            SELECT g.id, g.kind, g.confidence, g.canonical_asset_id,
                   MAX(f.digest) AS digest, MAX(f.byte_count) AS byte_count, COUNT(m.asset_id) AS member_count
            FROM comparison_groups g
            JOIN comparison_members m ON m.group_id=g.id
            JOIN exact_fingerprints f ON f.asset_id=m.asset_id
            JOIN assets a ON a.id=m.asset_id
            WHERE g.kind='exact' AND a.is_missing=0 AND a.is_quarantined=0\(sourceClause)
            GROUP BY g.id, g.kind, g.confidence, g.canonical_asset_id
            ORDER BY (MAX(f.byte_count) * (COUNT(m.asset_id)-1)) DESC
            """,
            sourceID.map { [.text($0.rawValue)] } ?? []
        )

        return try groupRows.compactMap { row in
            guard let id = row["id"]?.string,
                  let kind = row["kind"]?.string,
                  let confidence = row["confidence"]?.string,
                  let digest = row["digest"]?.string,
                  let byteCount = row["byte_count"]?.int64,
                  let memberCount = row["member_count"]?.int64,
                  let canonicalID = row["canonical_asset_id"]?.string else { return nil }

            let assetRows = try rows(
                """
                SELECT a.id, a.display_name, a.path, a.byte_count, a.modified_at, f.digest
                FROM comparison_members m
                JOIN assets a ON a.id=m.asset_id
                JOIN exact_fingerprints f ON f.asset_id=a.id
                WHERE m.group_id=? AND a.is_missing=0 AND a.is_quarantined=0 ORDER BY m.rank
                """,
                [.text(id)]
            )
            let assets = try assetRows.compactMap { asset -> ReviewAsset? in
                guard let assetID = asset["id"]?.string,
                      let name = asset["display_name"]?.string,
                      let path = asset["path"]?.string,
                      let bytes = asset["byte_count"]?.int64,
                      let digest = asset["digest"]?.string else { return nil }
                return ReviewAsset(
                    id: AssetID(rawValue: assetID),
                    displayName: name,
                    fileURL: URL(fileURLWithPath: path),
                    byteCount: bytes,
                    modificationDate: asset["modified_at"]?.double.map { Date(timeIntervalSince1970: $0) },
                    digest: digest,
                    family: try familySummary(assetID: assetID)
                )
            }
            guard assets.count > 1 else { return nil }
            return ReviewGroup(
                id: id,
                kind: kind,
                confidence: confidence,
                digest: digest,
                reclaimableBytes: byteCount * max(0, memberCount - 1),
                canonicalAssetID: AssetID(rawValue: canonicalID),
                assets: assets
            )
        }
    }

    func fetchReviewDecisions(sourceID: SourceID? = nil) throws -> [PersistedReviewDecision] {
        try initialize()
        let sourceJoin = sourceID == nil ? "" : " JOIN assets a ON a.id=d.asset_id"
        let sourceWhere = sourceID == nil ? "" : " WHERE a.source_id=?"
        return try rows(
            """
            SELECT d.group_id, d.asset_id, d.action, d.actor, d.reason_code, d.updated_at
            FROM decisions d
            JOIN comparison_members m ON m.group_id=d.group_id AND m.asset_id=d.asset_id\(sourceJoin)\(sourceWhere)
            ORDER BY d.updated_at ASC
            """,
            sourceID.map { [.text($0.rawValue)] } ?? []
        ).compactMap { row in
            guard let groupID = row["group_id"]?.string,
                  let assetID = row["asset_id"]?.string,
                  let actionRaw = row["action"]?.string,
                  let action = ReviewDecision(rawValue: actionRaw),
                  let actor = row["actor"]?.string,
                  let updated = row["updated_at"]?.double else { return nil }
            return PersistedReviewDecision(
                groupID: groupID,
                assetID: AssetID(rawValue: assetID),
                decision: action,
                actor: actor,
                reasonCode: row["reason_code"]?.string ?? "legacy-decision",
                updatedAt: Date(timeIntervalSince1970: updated)
            )
        }
    }

    func setDecision(groupID: String, assetID: AssetID, decision: ReviewDecision) throws {
        try initialize()
        try transaction {
            let membership = try scalarInt(
                "SELECT COUNT(*) FROM comparison_members WHERE group_id=? AND asset_id=?",
                [.text(groupID), .text(assetID.rawValue)]
            )
            guard membership == 1 else { throw DatabaseError.invalidDecisionTarget }
            let canonical = try rows(
                "SELECT canonical_asset_id FROM comparison_groups WHERE id=?",
                [.text(groupID)]
            ).first?["canonical_asset_id"]?.string

            if decision == .keep {
                if let canonical, canonical != assetID.rawValue {
                    try upsertDecision(groupID: groupID, assetID: canonical, action: .skip, actor: "user", reason: "keeper-replaced")
                }
                try executePrepared(
                    "UPDATE comparison_groups SET canonical_asset_id=? WHERE id=?",
                    [.text(assetID.rawValue), .text(groupID)]
                )
                try upsertDecision(groupID: groupID, assetID: assetID.rawValue, action: .keep, actor: "user", reason: "user-selected-keeper")
            } else {
                guard canonical != assetID.rawValue else { throw DatabaseError.protectedCanonical }
                try upsertDecision(groupID: groupID, assetID: assetID.rawValue, action: decision, actor: "user", reason: decision == .quarantinePlan ? "user-added-to-plan" : "user-skipped")
            }
        }
    }

    func applyExactGroupAction(
        groupID: String,
        keeperAssetID: AssetID,
        extraAssetIDs: [AssetID],
        action: ExactGroupBatchAction
    ) throws {
        try initialize()
        try transaction {
            let groupRows = try rows(
                "SELECT kind, canonical_asset_id FROM comparison_groups WHERE id=?",
                [.text(groupID)]
            )
            guard let row = groupRows.first,
                  row["kind"]?.string == "exact",
                  row["canonical_asset_id"]?.string == keeperAssetID.rawValue else {
                throw DatabaseError.invalidDecisionTarget
            }

            let memberIDs = Set(try rows(
                "SELECT asset_id FROM comparison_members WHERE group_id=?",
                [.text(groupID)]
            ).compactMap { $0["asset_id"]?.string })
            let extras = Set(extraAssetIDs.map(\.rawValue))
            guard !extras.contains(keeperAssetID.rawValue), extras.isSubset(of: memberIDs) else {
                throw DatabaseError.invalidDecisionTarget
            }

            let decision: ReviewDecision = action == .planSafeExtras ? .quarantinePlan : .skip
            let reason = action == .planSafeExtras ? "user-batch-added-exact-extras" : "user-batch-skipped-exact-extras"
            for assetID in extras.sorted() {
                try upsertDecision(
                    groupID: groupID,
                    assetID: assetID,
                    action: decision,
                    actor: "user",
                    reason: reason
                )
            }
        }
    }

    func fetchCleanupCandidates(sourceID: SourceID? = nil) throws -> [CleanupCandidate] {
        try initialize()
        let sourceClause = sourceID == nil ? "" : " AND a.source_id=?"
        return try rows(
            """
            SELECT d.group_id, d.asset_id, g.canonical_asset_id, a.display_name, a.path, a.byte_count, f.digest,
                   d.actor, d.reason_code, d.updated_at
            FROM decisions d
            JOIN comparison_groups g ON g.id=d.group_id
            JOIN comparison_members m ON m.group_id=d.group_id AND m.asset_id=d.asset_id
            JOIN assets a ON a.id=d.asset_id
            JOIN exact_fingerprints f ON f.asset_id=d.asset_id
            WHERE d.action='quarantinePlan' AND g.kind='exact' AND a.is_missing=0 AND a.is_quarantined=0\(sourceClause)
            ORDER BY d.group_id, a.path
            """,
            sourceID.map { [.text($0.rawValue)] } ?? []
        ).compactMap { row in
            guard let groupID = row["group_id"]?.string,
                  let assetID = row["asset_id"]?.string,
                  let canonical = row["canonical_asset_id"]?.string,
                  let displayName = row["display_name"]?.string,
                  let path = row["path"]?.string,
                  let bytes = row["byte_count"]?.int64,
                  let digest = row["digest"]?.string,
                  let actor = row["actor"]?.string,
                  let updated = row["updated_at"]?.double else { return nil }
            return CleanupCandidate(
                groupID: groupID,
                assetID: AssetID(rawValue: assetID),
                canonicalAssetID: AssetID(rawValue: canonical),
                displayName: displayName,
                originalURL: URL(fileURLWithPath: path),
                byteCount: bytes,
                digest: digest,
                family: try familySummary(assetID: assetID),
                decisionActor: actor,
                decisionReasonCode: row["reason_code"]?.string ?? "legacy-decision",
                decisionUpdatedAt: Date(timeIntervalSince1970: updated)
            )
        }
    }


    // MARK: - Perceptual similarity index (review-only)

    func fetchSimilarityAssets(sourceID: SourceID) throws -> [SimilarityAssetInput] {
        try initialize()
        return try rows(
            """
            SELECT a.id, a.source_id, a.path, a.display_name, a.byte_count, a.modified_at, f.digest
            FROM assets a
            JOIN exact_fingerprints f ON f.asset_id=a.id
            WHERE a.source_id=? AND a.media_kind='image' AND a.is_missing=0 AND a.is_quarantined=0
            ORDER BY a.path
            """,
            [.text(sourceID.rawValue)]
        ).compactMap { row in
            guard let assetID = row["id"]?.string,
                  let storedSourceID = row["source_id"]?.string,
                  let path = row["path"]?.string,
                  let displayName = row["display_name"]?.string,
                  let byteCount = row["byte_count"]?.int64,
                  let digest = row["digest"]?.string else { return nil }
            return SimilarityAssetInput(
                assetID: AssetID(rawValue: assetID),
                sourceID: SourceID(rawValue: storedSourceID),
                fileURL: URL(fileURLWithPath: path),
                displayName: displayName,
                byteCount: byteCount,
                modificationDate: row["modified_at"]?.double.map { Date(timeIntervalSince1970: $0) },
                exactDigest: digest,
                family: try familySummary(assetID: assetID)
            )
        }
    }

    func perceptualFeature(
        assetID: AssetID,
        contentDigest: String,
        visionRevision: Int,
        cropScale: String
    ) throws -> StoredPerceptualFeature? {
        try initialize()
        guard let row = try rows(
            """
            SELECT asset_id, source_id, content_digest, feature_archive, dhash_hex, pixel_width, pixel_height,
                   vision_revision, crop_scale, pairing_revision
            FROM perceptual_features
            WHERE asset_id=? AND content_digest=? AND vision_revision=? AND crop_scale=?
            LIMIT 1
            """,
            [.text(assetID.rawValue), .text(contentDigest), .int(Int64(visionRevision)), .text(cropScale)]
        ).first else { return nil }
        return storedPerceptualFeature(from: row)
    }

    func upsertPerceptualFeature(
        asset: SimilarityAssetInput,
        payload: PerceptualFeaturePayload,
        pairingRevision: Int,
        configuration: CandidateIndexConfiguration
    ) throws {
        try initialize()
        let hash = PerceptualHash64(payload.perceptualHash)
        try transaction {
            try executePrepared(
                """
                INSERT INTO perceptual_features(
                    asset_id, source_id, content_digest, vision_revision, crop_scale, feature_archive,
                    dhash_hex, pixel_width, pixel_height, pairing_revision, indexed_at
                ) VALUES(?,?,?,?,?,?,?,?,?,?,?)
                ON CONFLICT(asset_id) DO UPDATE SET
                    source_id=excluded.source_id,
                    content_digest=excluded.content_digest,
                    vision_revision=excluded.vision_revision,
                    crop_scale=excluded.crop_scale,
                    feature_archive=excluded.feature_archive,
                    dhash_hex=excluded.dhash_hex,
                    pixel_width=excluded.pixel_width,
                    pixel_height=excluded.pixel_height,
                    pairing_revision=excluded.pairing_revision,
                    indexed_at=excluded.indexed_at
                """,
                [
                    .text(asset.assetID.rawValue), .text(asset.sourceID.rawValue), .text(asset.exactDigest),
                    .int(Int64(payload.visionRevision)), .text(payload.cropScale), .blob(payload.featureArchive),
                    .text(hash.hex), .int(Int64(payload.pixelWidth)), .int(Int64(payload.pixelHeight)),
                    .int(Int64(pairingRevision)), .double(Date().timeIntervalSince1970)
                ]
            )
            try executePrepared("DELETE FROM perceptual_bands WHERE asset_id=?", [.text(asset.assetID.rawValue)])
            for (index, value) in hash.candidateBands(bitWidth: configuration.bandBitWidth, rotationOffsets: configuration.rotationOffsets).enumerated() {
                try executePrepared(
                    "INSERT INTO perceptual_bands(asset_id, band_index, band_value) VALUES(?,?,?)",
                    [.text(asset.assetID.rawValue), .int(Int64(index)), .int(Int64(value))]
                )
            }
        }
    }

    func fetchFeaturesNeedingPairing(sourceID: SourceID, pairingRevision: Int) throws -> [StoredPerceptualFeature] {
        try initialize()
        return try rows(
            """
            SELECT pf.asset_id, pf.source_id, pf.content_digest, pf.feature_archive, pf.dhash_hex,
                   pf.pixel_width, pf.pixel_height, pf.vision_revision, pf.crop_scale, pf.pairing_revision
            FROM perceptual_features pf
            JOIN assets a ON a.id=pf.asset_id
            WHERE pf.source_id=? AND pf.pairing_revision<? AND a.is_missing=0 AND a.is_quarantined=0
            ORDER BY pf.asset_id
            """,
            [.text(sourceID.rawValue), .int(Int64(pairingRevision))]
        ).compactMap(storedPerceptualFeature(from:))
    }

    func fetchPerceptualCandidates(
        sourceID: SourceID,
        feature: StoredPerceptualFeature,
        configuration: CandidateIndexConfiguration
    ) throws -> [StoredPerceptualFeature] {
        try initialize()
        let queryHash = PerceptualHash64(feature.perceptualHash)
        var candidates: [AssetID: StoredPerceptualFeature] = [:]
        for (bandIndex, bandValue) in queryHash.candidateBands(bitWidth: configuration.bandBitWidth, rotationOffsets: configuration.rotationOffsets).enumerated() {
            let matches = try rows(
                """
                SELECT pf.asset_id, pf.source_id, pf.content_digest, pf.feature_archive, pf.dhash_hex,
                       pf.pixel_width, pf.pixel_height, pf.vision_revision, pf.crop_scale, pf.pairing_revision
                FROM perceptual_bands b
                JOIN perceptual_features pf ON pf.asset_id=b.asset_id
                JOIN assets a ON a.id=pf.asset_id
                WHERE pf.source_id=? AND b.band_index=? AND b.band_value=? AND pf.asset_id<>?
                  AND a.is_missing=0 AND a.is_quarantined=0
                LIMIT 2000
                """,
                [.text(sourceID.rawValue), .int(Int64(bandIndex)), .int(Int64(bandValue)), .text(feature.assetID.rawValue)]
            ).compactMap(storedPerceptualFeature(from:))
            for match in matches { candidates[match.assetID] = match }
        }
        return candidates.values.compactMap { candidate -> (StoredPerceptualFeature, Int)? in
            let distance = queryHash.hammingDistance(to: PerceptualHash64(candidate.perceptualHash))
            guard distance <= configuration.maximumHammingDistance else { return nil }
            return (candidate, distance)
        }
        .sorted { lhs, rhs in lhs.1 == rhs.1 ? lhs.0.assetID.rawValue < rhs.0.assetID.rawValue : lhs.1 < rhs.1 }
        .prefix(configuration.maximumCandidates)
        .map(\.0)
    }

    func markFeaturePaired(assetID: AssetID, pairingRevision: Int) throws {
        try initialize()
        try executePrepared(
            "UPDATE perceptual_features SET pairing_revision=? WHERE asset_id=?",
            [.int(Int64(pairingRevision)), .text(assetID.rawValue)]
        )
    }

    func deleteSimilarityPairs(involving assetID: AssetID) throws {
        try initialize()
        try executePrepared(
            "DELETE FROM similarity_pairs WHERE first_asset_id=? OR second_asset_id=?",
            [.text(assetID.rawValue), .text(assetID.rawValue)]
        )
    }

    func similarityPairExists(_ first: AssetID, _ second: AssetID) throws -> Bool {
        try initialize()
        let ordered = first.rawValue <= second.rawValue ? (first.rawValue, second.rawValue) : (second.rawValue, first.rawValue)
        return try scalarInt(
            "SELECT COUNT(*) FROM similarity_pairs WHERE first_asset_id=? AND second_asset_id=?",
            [.text(ordered.0), .text(ordered.1)]
        ) > 0
    }

    func upsertSimilarityPair(_ pair: SimilarityPairRecord) throws {
        try initialize()
        try executePrepared(
            """
            INSERT INTO similarity_pairs(
                source_id, first_asset_id, second_asset_id, distance, tier, profile_id, evaluated_at
            ) VALUES(?,?,?,?,?,?,?)
            ON CONFLICT(first_asset_id, second_asset_id) DO UPDATE SET
                source_id=excluded.source_id,
                distance=excluded.distance,
                tier=excluded.tier,
                profile_id=excluded.profile_id,
                evaluated_at=excluded.evaluated_at
            """,
            [
                .text(pair.sourceID.rawValue), .text(pair.firstAssetID.rawValue), .text(pair.secondAssetID.rawValue),
                .double(Double(pair.distance)), pair.tier.map { .text($0.rawValue) } ?? .null,
                .text(pair.profileID), .double(pair.evaluatedAt.timeIntervalSince1970)
            ]
        )
    }

    func fetchSimilarityPairs(sourceID: SourceID, maximumDistance: Float) throws -> [SimilarityPairRecord] {
        try initialize()
        return try rows(
            """
            SELECT source_id, first_asset_id, second_asset_id, distance, tier, profile_id, evaluated_at
            FROM similarity_pairs
            WHERE source_id=? AND distance<=?
            ORDER BY distance ASC, first_asset_id, second_asset_id
            """,
            [.text(sourceID.rawValue), .double(Double(maximumDistance))]
        ).compactMap { row in
            guard let storedSourceID = row["source_id"]?.string,
                  let first = row["first_asset_id"]?.string,
                  let second = row["second_asset_id"]?.string,
                  let distance = row["distance"]?.double,
                  let profileID = row["profile_id"]?.string,
                  let evaluatedAt = row["evaluated_at"]?.double else { return nil }
            return SimilarityPairRecord(
                sourceID: SourceID(rawValue: storedSourceID),
                firstAssetID: AssetID(rawValue: first),
                secondAssetID: AssetID(rawValue: second),
                distance: Float(distance),
                tier: row["tier"]?.string.flatMap(SimilarityTier.init(rawValue:)),
                profileID: profileID,
                evaluatedAt: Date(timeIntervalSince1970: evaluatedAt)
            )
        }
    }

    func fetchReviewAssets(assetIDs: Set<AssetID>) throws -> [AssetID: ReviewAsset] {
        try initialize()
        var result: [AssetID: ReviewAsset] = [:]
        for assetID in assetIDs {
            guard let row = try rows(
                """
                SELECT a.id, a.display_name, a.path, a.byte_count, a.modified_at, f.digest
                FROM assets a JOIN exact_fingerprints f ON f.asset_id=a.id
                WHERE a.id=? AND a.is_missing=0 AND a.is_quarantined=0 LIMIT 1
                """,
                [.text(assetID.rawValue)]
            ).first,
            let id = row["id"]?.string,
            let name = row["display_name"]?.string,
            let path = row["path"]?.string,
            let bytes = row["byte_count"]?.int64,
            let digest = row["digest"]?.string else { continue }
            let reviewAsset = ReviewAsset(
                id: AssetID(rawValue: id),
                displayName: name,
                fileURL: URL(fileURLWithPath: path),
                byteCount: bytes,
                modificationDate: row["modified_at"]?.double.map { Date(timeIntervalSince1970: $0) },
                digest: digest,
                family: try familySummary(assetID: id)
            )
            result[reviewAsset.id] = reviewAsset
        }
        return result
    }

    func prunePerceptualState(sourceID: SourceID) throws {
        try initialize()
        try transaction {
            try executePrepared(
                """
                DELETE FROM perceptual_features
                WHERE source_id=? AND asset_id IN (
                    SELECT id FROM assets WHERE source_id=? AND (is_missing=1 OR is_quarantined=1)
                )
                """,
                [.text(sourceID.rawValue), .text(sourceID.rawValue)]
            )
            try executePrepared(
                """
                DELETE FROM similarity_pairs
                WHERE source_id=? AND (
                    first_asset_id NOT IN (SELECT id FROM assets WHERE source_id=? AND is_missing=0 AND is_quarantined=0)
                    OR second_asset_id NOT IN (SELECT id FROM assets WHERE source_id=? AND is_missing=0 AND is_quarantined=0)
                )
                """,
                [.text(sourceID.rawValue), .text(sourceID.rawValue), .text(sourceID.rawValue)]
            )
        }
    }

    func fetchSimilarityCalibrationProfile(visionRevision: Int) throws -> SimilarityCalibrationProfile? {
        try initialize()
        guard let row = try rows(
            """
            SELECT payload FROM similarity_calibration_profiles
            WHERE vision_revision=? ORDER BY generated_at DESC LIMIT 1
            """,
            [.int(Int64(visionRevision))]
        ).first,
        let payload = row["payload"]?.blob else { return nil }
        return try? JSONDecoder().decode(SimilarityCalibrationProfile.self, from: payload)
    }

    func saveSimilarityCalibrationProfile(_ profile: SimilarityCalibrationProfile) throws {
        try initialize()
        let payload = try JSONEncoder().encode(profile)
        try executePrepared(
            """
            INSERT INTO similarity_calibration_profiles(id, vision_revision, payload, generated_at)
            VALUES(?,?,?,?)
            ON CONFLICT(id) DO UPDATE SET payload=excluded.payload, generated_at=excluded.generated_at
            """,
            [.text(profile.id), .int(Int64(profile.visionRevision)), .blob(payload), .double(profile.generatedAt.timeIntervalSince1970)]
        )
    }

    private func storedPerceptualFeature(from row: [String: SQLiteValue]) -> StoredPerceptualFeature? {
        guard let assetID = row["asset_id"]?.string,
              let sourceID = row["source_id"]?.string,
              let contentDigest = row["content_digest"]?.string,
              let archive = row["feature_archive"]?.blob,
              let hashHex = row["dhash_hex"]?.string,
              let hash = UInt64(hashHex, radix: 16),
              let width = row["pixel_width"]?.int64,
              let height = row["pixel_height"]?.int64,
              let visionRevision = row["vision_revision"]?.int64,
              let cropScale = row["crop_scale"]?.string,
              let pairingRevision = row["pairing_revision"]?.int64 else { return nil }
        return StoredPerceptualFeature(
            assetID: AssetID(rawValue: assetID),
            sourceID: SourceID(rawValue: sourceID),
            contentDigest: contentDigest,
            featureArchive: archive,
            perceptualHash: hash,
            pixelWidth: Int(width),
            pixelHeight: Int(height),
            visionRevision: Int(visionRevision),
            cropScale: cropScale,
            pairingRevision: Int(pairingRevision)
        )
    }

    // MARK: - Cleanup plans, manifests, and restore history

    func insertCleanupPlan(_ plan: CleanupPlanPreview) throws {
        try initialize()
        try transaction {
            try executePrepared(
                """
                INSERT INTO cleanup_plans(id, source_path, quarantine_root, state, estimated_bytes, created_at, source_volume_id)
                VALUES(?,?,?,?,?,?,?)
                """,
                [
                    .text(plan.id), .text(plan.sourceRoot.path), .text(plan.quarantineRoot.path), .text(CleanupPlanState.draft.rawValue),
                    .int(plan.estimatedBytes), .double(plan.createdAt.timeIntervalSince1970),
                    plan.sourceVolume.map { .text($0.stableID) } ?? .null
                ]
            )
            for operation in plan.operations {
                try executePrepared(
                    """
                    INSERT INTO cleanup_operations(
                        id, plan_id, group_id, asset_id, original_path, quarantine_path, byte_count, digest, status,
                        family_id, family_kind, family_role
                    ) VALUES(?,?,?,?,?,?,?,?,?,?,?,?)
                    """,
                    [
                        .text(operation.id), .text(plan.id), .text(operation.groupID), .text(operation.assetID.rawValue),
                        .text(operation.originalURL.path), .text(operation.quarantineURL.path), .int(operation.byteCount),
                        .text(operation.digest), .text(CleanupOperationState.pending.rawValue),
                        operation.familyID.map { .text($0) } ?? .null,
                        operation.familyKind.map { .text($0.rawValue) } ?? .null,
                        operation.familyRole.map { .text($0.rawValue) } ?? .null
                    ]
                )
            }
        }
    }

    func updateCleanupPlanState(_ planID: String, state: CleanupPlanState) throws {
        try initialize()
        try executePrepared("UPDATE cleanup_plans SET state=? WHERE id=?", [.text(state.rawValue), .text(planID)])
    }

    func discardDraftCleanupPlan(_ planID: String) throws {
        try initialize()
        try executePrepared(
            "DELETE FROM cleanup_plans WHERE id=? AND state=?",
            [.text(planID), .text(CleanupPlanState.draft.rawValue)]
        )
    }

    func markOperationQuarantined(operationID: String, assetID: AssetID, quarantinePath: String) throws {
        try initialize()
        try transaction {
            try executePrepared(
                "UPDATE cleanup_operations SET status=?, error_message=NULL, executed_at=? WHERE id=?",
                [.text(CleanupOperationState.quarantined.rawValue), .double(Date().timeIntervalSince1970), .text(operationID)]
            )
            try executePrepared(
                "UPDATE assets SET path=?, is_quarantined=1, is_missing=0 WHERE id=?",
                [.text(quarantinePath), .text(assetID.rawValue)]
            )
        }
    }

    func markOperationFailed(operationID: String, message: String) throws {
        try initialize()
        try executePrepared(
            "UPDATE cleanup_operations SET status=?, error_message=? WHERE id=?",
            [.text(CleanupOperationState.failed.rawValue), .text(message), .text(operationID)]
        )
    }

    func recordOperationError(operationID: String, message: String) throws {
        try initialize()
        try executePrepared(
            "UPDATE cleanup_operations SET error_message=? WHERE id=?",
            [.text(message), .text(operationID)]
        )
    }

    func markOperationRestored(operationID: String, assetID: AssetID, originalPath: String) throws {
        try initialize()
        try transaction {
            try executePrepared(
                "UPDATE cleanup_operations SET status=?, error_message=NULL, restored_at=? WHERE id=?",
                [.text(CleanupOperationState.restored.rawValue), .double(Date().timeIntervalSince1970), .text(operationID)]
            )
            try executePrepared(
                "UPDATE assets SET path=?, is_quarantined=0, is_missing=0 WHERE id=?",
                [.text(originalPath), .text(assetID.rawValue)]
            )
        }
    }

    func storeManifest(planID: String, envelope: SignedCleanupManifest, path: String) throws {
        try initialize()
        try transaction {
            try executePrepared(
                """
                INSERT OR REPLACE INTO manifests(id, plan_id, schema_version, manifest_path, payload_base64, signature_base64, public_key_base64, created_at)
                VALUES(?,?,?,?,?,?,?,?)
                """,
                [
                    .text(UUID().uuidString.lowercased()), .text(planID), .int(3), .text(path), .text(envelope.payloadBase64),
                    .text(envelope.signatureBase64), .text(envelope.publicKeyBase64), .double(Date().timeIntervalSince1970)
                ]
            )
            try executePrepared(
                "UPDATE cleanup_plans SET manifest_path=?, signature=? WHERE id=?",
                [.text(path), .text(envelope.signatureBase64), .text(planID)]
            )
        }
    }

    func finishCleanupCommit(_ planID: String, state: CleanupPlanState) throws {
        try initialize()
        try executePrepared(
            "UPDATE cleanup_plans SET state=?, committed_at=? WHERE id=?",
            [.text(state.rawValue), .double(Date().timeIntervalSince1970), .text(planID)]
        )
    }

    func finishCleanupRestore(_ planID: String, state: CleanupPlanState) throws {
        try initialize()
        try executePrepared(
            "UPDATE cleanup_plans SET state=?, restored_at=? WHERE id=?",
            [.text(state.rawValue), .double(Date().timeIntervalSince1970), .text(planID)]
        )
    }

    func fetchManifestRecord(planID: String) throws -> StoredManifestRecord? {
        try initialize()
        guard let row = try rows(
            """
            SELECT plan_id, manifest_path, signature_base64, public_key_base64
            FROM manifests WHERE plan_id=? ORDER BY created_at DESC LIMIT 1
            """,
            [.text(planID)]
        ).first,
        let storedPlanID = row["plan_id"]?.string,
        let path = row["manifest_path"]?.string,
        let signature = row["signature_base64"]?.string,
        let publicKey = row["public_key_base64"]?.string else { return nil }
        return StoredManifestRecord(planID: storedPlanID, path: path, signature: signature, publicKey: publicKey)
    }

    func fetchCleanupOperationStates(planID: String) throws -> [String: CleanupOperationState] {
        try initialize()
        var result: [String: CleanupOperationState] = [:]
        for row in try rows("SELECT id, status FROM cleanup_operations WHERE plan_id=?", [.text(planID)]) {
            if let id = row["id"]?.string,
               let raw = row["status"]?.string,
               let state = CleanupOperationState(rawValue: raw) {
                result[id] = state
            }
        }
        return result
    }

    func countOperations(planID: String, state: CleanupOperationState) throws -> Int {
        try initialize()
        return Int(try scalarInt(
            "SELECT COUNT(*) FROM cleanup_operations WHERE plan_id=? AND status=?",
            [.text(planID), .text(state.rawValue)]
        ))
    }

    func fetchCleanupHistory() throws -> [CleanupHistoryItem] {
        try initialize()
        return try rows(
            """
            SELECT p.id, p.state, p.source_path, p.estimated_bytes, p.created_at, p.committed_at, p.restored_at,
                   p.manifest_path, COUNT(o.id) AS operation_count
            FROM cleanup_plans p LEFT JOIN cleanup_operations o ON o.plan_id=p.id
            GROUP BY p.id
            ORDER BY p.created_at DESC
            """
        ).compactMap { row in
            guard let id = row["id"]?.string,
                  let stateRaw = row["state"]?.string,
                  let state = CleanupPlanState(rawValue: stateRaw),
                  let sourcePath = row["source_path"]?.string,
                  let operationCount = row["operation_count"]?.int64,
                  let estimatedBytes = row["estimated_bytes"]?.int64,
                  let createdAt = row["created_at"]?.double else { return nil }
            return CleanupHistoryItem(
                id: id,
                state: state,
                sourcePath: sourcePath,
                operationCount: Int(operationCount),
                estimatedBytes: estimatedBytes,
                createdAt: Date(timeIntervalSince1970: createdAt),
                committedAt: row["committed_at"]?.double.map { Date(timeIntervalSince1970: $0) },
                restoredAt: row["restored_at"]?.double.map { Date(timeIntervalSince1970: $0) },
                manifestPath: row["manifest_path"]?.string
            )
        }
    }

    // MARK: - Startup reconciliation

    func fetchOperationsNeedingReconciliation(sourcePath: String) throws -> [PendingCleanupOperationRecord] {
        try initialize()
        return try rows(
            """
            SELECT p.id AS plan_id, p.state AS plan_state, o.id AS operation_id, o.asset_id,
                   o.original_path, o.quarantine_path, o.byte_count, o.digest, o.status
            FROM cleanup_operations o
            JOIN cleanup_plans p ON p.id=o.plan_id
            WHERE o.status IN ('pending','quarantined') AND p.source_path=?
            ORDER BY p.created_at, o.id
            """,
            [.text(URL(fileURLWithPath: sourcePath).standardizedFileURL.path)]
        ).compactMap { row in
            guard let planID = row["plan_id"]?.string,
                  let planRaw = row["plan_state"]?.string, let planState = CleanupPlanState(rawValue: planRaw),
                  let operationID = row["operation_id"]?.string,
                  let assetID = row["asset_id"]?.string,
                  let original = row["original_path"]?.string,
                  let quarantine = row["quarantine_path"]?.string,
                  let bytes = row["byte_count"]?.int64,
                  let digest = row["digest"]?.string,
                  let statusRaw = row["status"]?.string, let status = CleanupOperationState(rawValue: statusRaw) else { return nil }
            return PendingCleanupOperationRecord(
                planID: planID, planState: planState, operationID: operationID,
                assetID: AssetID(rawValue: assetID), originalURL: URL(fileURLWithPath: original),
                quarantineURL: URL(fileURLWithPath: quarantine), byteCount: bytes, digest: digest, operationState: status
            )
        }
    }

    func refreshCleanupPlanState(planID: String) throws {
        try initialize()
        let total = try scalarInt("SELECT COUNT(*) FROM cleanup_operations WHERE plan_id=?", [.text(planID)])
        guard total > 0 else { return }
        let pending = try scalarInt("SELECT COUNT(*) FROM cleanup_operations WHERE plan_id=? AND status='pending'", [.text(planID)])
        let quarantined = try scalarInt("SELECT COUNT(*) FROM cleanup_operations WHERE plan_id=? AND status='quarantined'", [.text(planID)])
        let restored = try scalarInt("SELECT COUNT(*) FROM cleanup_operations WHERE plan_id=? AND status='restored'", [.text(planID)])
        let failed = try scalarInt("SELECT COUNT(*) FROM cleanup_operations WHERE plan_id=? AND status='failed'", [.text(planID)])
        let state: CleanupPlanState
        if restored == total { state = .restored }
        else if quarantined == total { state = .committed }
        else if restored > 0 { state = .partiallyRestored }
        else if quarantined > 0 { state = .partiallyCommitted }
        else if pending > 0 { state = .committing }
        else if failed > 0 { state = .failed }
        else { state = .failed }
        try executePrepared("UPDATE cleanup_plans SET state=? WHERE id=?", [.text(state.rawValue), .text(planID)])
    }

    // MARK: - Summary

    func summary(sourceID: SourceID? = nil) throws -> DatabaseSummary {
        try initialize()
        let sourceClause = sourceID == nil ? "" : " AND source_id=?"
        let assetValues: [SQLiteValue] = sourceID.map { [.text($0.rawValue)] } ?? []
        let indexed = try scalarInt("SELECT COUNT(*) FROM assets WHERE 1=1\(sourceClause)", assetValues)
        let active = try scalarInt("SELECT COUNT(*) FROM assets WHERE is_missing=0 AND is_quarantined=0\(sourceClause)", assetValues)
        let quarantined = try scalarInt("SELECT COUNT(*) FROM assets WHERE is_quarantined=1\(sourceClause)", assetValues)

        let memberSourceClause = sourceID == nil ? "" : " AND a.source_id=?"
        let memberValues: [SQLiteValue] = sourceID.map { [.text($0.rawValue)] } ?? []
        let groups = try scalarInt(
            """
            SELECT COUNT(DISTINCT g.id)
            FROM comparison_groups g
            JOIN comparison_members m ON m.group_id=g.id
            JOIN assets a ON a.id=m.asset_id
            WHERE g.kind='exact'\(memberSourceClause)
            """,
            memberValues
        )
        let duplicateAssets = try scalarInt(
            """
            SELECT COUNT(*)
            FROM comparison_members m JOIN assets a ON a.id=m.asset_id
            WHERE 1=1\(memberSourceClause)
            """,
            memberValues
        )
        let reclaimable = try scalarInt(
            """
            SELECT COALESCE(SUM(reclaimable),0) FROM (
                SELECT MAX(f.byte_count) * (COUNT(*) - 1) AS reclaimable
                FROM comparison_members m
                JOIN exact_fingerprints f ON f.asset_id=m.asset_id
                JOIN assets a ON a.id=m.asset_id
                WHERE 1=1\(memberSourceClause)
                GROUP BY m.group_id
            )
            """,
            memberValues
        )
        return DatabaseSummary(
            indexedAssets: Int(indexed),
            activeAssets: Int(active),
            duplicateGroups: Int(groups),
            duplicateAssets: Int(duplicateAssets),
            reclaimableBytes: reclaimable,
            quarantinedAssets: Int(quarantined)
        )
    }

    func schemaVersion() throws -> Int {
        try initialize()
        return Int(try scalarInt("PRAGMA user_version"))
    }

    // MARK: - Migration

    private func migrateIfNeeded() throws {
        var version = try scalarInt("PRAGMA user_version")
        if version < 1 {
            try transaction {
                try execute("""
                CREATE TABLE IF NOT EXISTS assets(
                    id TEXT PRIMARY KEY,
                    source_id TEXT NOT NULL,
                    stable_key TEXT NOT NULL,
                    display_name TEXT NOT NULL,
                    path TEXT NOT NULL,
                    media_kind TEXT NOT NULL,
                    byte_count INTEGER NOT NULL,
                    created_at REAL,
                    modified_at REAL,
                    indexed_at REAL NOT NULL
                );
                CREATE UNIQUE INDEX IF NOT EXISTS idx_assets_source_stable ON assets(source_id, stable_key);

                CREATE TABLE IF NOT EXISTS exact_fingerprints(
                    asset_id TEXT PRIMARY KEY REFERENCES assets(id) ON DELETE CASCADE,
                    algorithm TEXT NOT NULL,
                    digest TEXT NOT NULL,
                    byte_count INTEGER NOT NULL,
                    revision INTEGER NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_exact_digest_size ON exact_fingerprints(digest, byte_count);

                CREATE TABLE IF NOT EXISTS comparison_groups(
                    id TEXT PRIMARY KEY,
                    kind TEXT NOT NULL,
                    algorithm_revision TEXT NOT NULL,
                    confidence TEXT NOT NULL,
                    created_at REAL NOT NULL
                );

                CREATE TABLE IF NOT EXISTS comparison_members(
                    group_id TEXT NOT NULL REFERENCES comparison_groups(id) ON DELETE CASCADE,
                    asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
                    rank INTEGER NOT NULL,
                    PRIMARY KEY(group_id, asset_id)
                );
                CREATE INDEX IF NOT EXISTS idx_comparison_members_group ON comparison_members(group_id);

                CREATE TABLE IF NOT EXISTS scan_sessions(
                    id TEXT PRIMARY KEY,
                    source_id TEXT NOT NULL,
                    source_path TEXT NOT NULL,
                    state TEXT NOT NULL,
                    phase TEXT NOT NULL,
                    processed INTEGER NOT NULL,
                    total INTEGER NOT NULL,
                    started_at REAL NOT NULL,
                    finished_at REAL
                );
                PRAGMA user_version=1;
                """)
            }
            version = 1
        }

        if version < 2 {
            try transaction {
                try execute("""
                ALTER TABLE assets ADD COLUMN last_seen_scan_id TEXT;
                ALTER TABLE assets ADD COLUMN is_missing INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE assets ADD COLUMN is_quarantined INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE comparison_groups ADD COLUMN canonical_asset_id TEXT;
                ALTER TABLE scan_sessions ADD COLUMN hashed INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE scan_sessions ADD COLUMN reused INTEGER NOT NULL DEFAULT 0;
                ALTER TABLE scan_sessions ADD COLUMN missing INTEGER NOT NULL DEFAULT 0;

                CREATE TABLE IF NOT EXISTS decisions(
                    id TEXT PRIMARY KEY,
                    group_id TEXT NOT NULL,
                    asset_id TEXT NOT NULL,
                    action TEXT NOT NULL,
                    reason_code TEXT NOT NULL,
                    actor TEXT NOT NULL,
                    created_at REAL NOT NULL,
                    updated_at REAL NOT NULL,
                    UNIQUE(group_id, asset_id)
                );
                CREATE INDEX IF NOT EXISTS idx_decisions_group ON decisions(group_id);

                UPDATE comparison_groups
                SET canonical_asset_id=(
                    SELECT asset_id FROM comparison_members
                    WHERE comparison_members.group_id=comparison_groups.id
                    ORDER BY rank ASC LIMIT 1
                )
                WHERE canonical_asset_id IS NULL;

                INSERT OR IGNORE INTO decisions(
                    id, group_id, asset_id, action, reason_code, actor, created_at, updated_at
                )
                SELECT
                    'migration:' || id,
                    id,
                    canonical_asset_id,
                    'keep',
                    'protected-canonical',
                    'system',
                    strftime('%s','now'),
                    strftime('%s','now')
                FROM comparison_groups
                WHERE canonical_asset_id IS NOT NULL;

                CREATE TABLE IF NOT EXISTS cleanup_plans(
                    id TEXT PRIMARY KEY,
                    source_path TEXT NOT NULL,
                    quarantine_root TEXT NOT NULL,
                    state TEXT NOT NULL,
                    estimated_bytes INTEGER NOT NULL,
                    manifest_path TEXT,
                    signature TEXT,
                    created_at REAL NOT NULL,
                    committed_at REAL,
                    restored_at REAL
                );

                CREATE TABLE IF NOT EXISTS cleanup_operations(
                    id TEXT PRIMARY KEY,
                    plan_id TEXT NOT NULL REFERENCES cleanup_plans(id) ON DELETE CASCADE,
                    group_id TEXT NOT NULL,
                    asset_id TEXT NOT NULL,
                    original_path TEXT NOT NULL,
                    quarantine_path TEXT NOT NULL,
                    byte_count INTEGER NOT NULL,
                    digest TEXT NOT NULL,
                    status TEXT NOT NULL,
                    error_message TEXT,
                    executed_at REAL,
                    restored_at REAL
                );
                CREATE INDEX IF NOT EXISTS idx_cleanup_operations_plan ON cleanup_operations(plan_id);

                CREATE TABLE IF NOT EXISTS manifests(
                    id TEXT PRIMARY KEY,
                    plan_id TEXT NOT NULL REFERENCES cleanup_plans(id) ON DELETE CASCADE,
                    schema_version INTEGER NOT NULL,
                    manifest_path TEXT NOT NULL,
                    payload_base64 TEXT NOT NULL,
                    signature_base64 TEXT NOT NULL,
                    public_key_base64 TEXT NOT NULL,
                    created_at REAL NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_manifests_plan ON manifests(plan_id);
                CREATE INDEX IF NOT EXISTS idx_assets_active ON assets(source_id, is_missing, is_quarantined);
                PRAGMA user_version=2;
                """)
            }
            version = 2
        }

        if version < 3 {
            try transaction {
                try execute("""
                ALTER TABLE scan_sessions ADD COLUMN cursor_stable_key TEXT;
                ALTER TABLE scan_sessions ADD COLUMN source_volume_id TEXT;
                ALTER TABLE cleanup_plans ADD COLUMN source_volume_id TEXT;
                ALTER TABLE cleanup_operations ADD COLUMN family_id TEXT;
                ALTER TABLE cleanup_operations ADD COLUMN family_kind TEXT;
                ALTER TABLE cleanup_operations ADD COLUMN family_role TEXT;

                CREATE TABLE IF NOT EXISTS asset_families(
                    id TEXT PRIMARY KEY,
                    source_id TEXT NOT NULL,
                    kind TEXT NOT NULL,
                    policy TEXT NOT NULL,
                    normalized_stem TEXT NOT NULL,
                    directory_path TEXT NOT NULL,
                    created_at REAL NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_asset_families_source ON asset_families(source_id);

                CREATE TABLE IF NOT EXISTS family_members(
                    family_id TEXT NOT NULL REFERENCES asset_families(id) ON DELETE CASCADE,
                    asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
                    role TEXT NOT NULL,
                    PRIMARY KEY(family_id, asset_id),
                    UNIQUE(asset_id)
                );
                CREATE INDEX IF NOT EXISTS idx_family_members_asset ON family_members(asset_id);
                CREATE INDEX IF NOT EXISTS idx_scan_resume ON scan_sessions(source_id, state, started_at);
                PRAGMA user_version=3;
                """)
            }
            version = 3
        }

        if version < 4 {
            try transaction {
                try execute("""
                CREATE TABLE IF NOT EXISTS perceptual_features(
                    asset_id TEXT PRIMARY KEY REFERENCES assets(id) ON DELETE CASCADE,
                    source_id TEXT NOT NULL,
                    content_digest TEXT NOT NULL,
                    vision_revision INTEGER NOT NULL,
                    crop_scale TEXT NOT NULL,
                    feature_archive BLOB NOT NULL,
                    dhash_hex TEXT NOT NULL,
                    pixel_width INTEGER NOT NULL,
                    pixel_height INTEGER NOT NULL,
                    pairing_revision INTEGER NOT NULL DEFAULT 0,
                    indexed_at REAL NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_perceptual_source ON perceptual_features(source_id);
                CREATE INDEX IF NOT EXISTS idx_perceptual_pairing ON perceptual_features(source_id, pairing_revision);

                CREATE TABLE IF NOT EXISTS perceptual_bands(
                    asset_id TEXT NOT NULL REFERENCES perceptual_features(asset_id) ON DELETE CASCADE,
                    band_index INTEGER NOT NULL,
                    band_value INTEGER NOT NULL,
                    PRIMARY KEY(asset_id, band_index)
                );
                CREATE INDEX IF NOT EXISTS idx_perceptual_band_lookup ON perceptual_bands(band_index, band_value);

                CREATE TABLE IF NOT EXISTS similarity_pairs(
                    source_id TEXT NOT NULL,
                    first_asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
                    second_asset_id TEXT NOT NULL REFERENCES assets(id) ON DELETE CASCADE,
                    distance REAL NOT NULL,
                    tier TEXT,
                    profile_id TEXT NOT NULL,
                    evaluated_at REAL NOT NULL,
                    PRIMARY KEY(first_asset_id, second_asset_id),
                    CHECK(first_asset_id < second_asset_id)
                );
                CREATE INDEX IF NOT EXISTS idx_similarity_pairs_source_distance ON similarity_pairs(source_id, distance);

                CREATE TABLE IF NOT EXISTS similarity_calibration_profiles(
                    id TEXT PRIMARY KEY,
                    vision_revision INTEGER NOT NULL,
                    payload BLOB NOT NULL,
                    generated_at REAL NOT NULL
                );
                CREATE INDEX IF NOT EXISTS idx_similarity_profile_revision ON similarity_calibration_profiles(vision_revision, generated_at);
                PRAGMA user_version=4;
                """)
            }
        }
    }

    private func upsertDecision(groupID: String, assetID: String, action: ReviewDecision, actor: String, reason: String) throws {
        let now = Date().timeIntervalSince1970
        try executePrepared(
            """
            INSERT INTO decisions(id, group_id, asset_id, action, reason_code, actor, created_at, updated_at)
            VALUES(?,?,?,?,?,?,?,?)
            ON CONFLICT(group_id, asset_id) DO UPDATE SET
                action=excluded.action, reason_code=excluded.reason_code, actor=excluded.actor, updated_at=excluded.updated_at
            """,
            [
                .text(UUID().uuidString.lowercased()), .text(groupID), .text(assetID), .text(action.rawValue),
                .text(reason), .text(actor), .double(now), .double(now)
            ]
        )
    }

    private enum SQLiteValue {
        case text(String)
        case int(Int64)
        case double(Double)
        case blob(Data)
        case null

        var string: String? { if case .text(let value) = self { return value }; return nil }
        var int64: Int64? { if case .int(let value) = self { return value }; return nil }
        var double: Double? { if case .double(let value) = self { return value }; return nil }
        var blob: Data? { if case .blob(let value) = self { return value }; return nil }
    }

    private func execute(_ sql: String) throws {
        guard let connection else { throw DatabaseError.open("database is not initialized") }
        let connectionPointer = connection.pointer
        var errorPointer: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(connectionPointer, sql, nil, nil, &errorPointer) == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? String(cString: sqlite3_errmsg(connectionPointer))
            sqlite3_free(errorPointer)
            throw DatabaseError.execute(message)
        }
    }

    private func executePrepared(_ sql: String, _ values: [SQLiteValue]) throws {
        _ = try executePreparedReturningChanges(sql, values)
    }

    private func executePreparedReturningChanges(_ sql: String, _ values: [SQLiteValue]) throws -> Int {
        guard let connection else { throw DatabaseError.open("database is not initialized") }
        let connectionPointer = connection.pointer
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connectionPointer, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DatabaseError.prepare(String(cString: sqlite3_errmsg(connectionPointer)))
        }
        defer { sqlite3_finalize(statement) }
        try bind(values, to: statement)
        guard sqlite3_step(statement) == SQLITE_DONE else {
            throw DatabaseError.execute(String(cString: sqlite3_errmsg(connectionPointer)))
        }
        return Int(sqlite3_changes(connectionPointer))
    }

    private func rows(_ sql: String, _ values: [SQLiteValue] = []) throws -> [[String: SQLiteValue]] {
        guard let connection else { throw DatabaseError.open("database is not initialized") }
        let connectionPointer = connection.pointer
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(connectionPointer, sql, -1, &statement, nil) == SQLITE_OK, let statement else {
            throw DatabaseError.prepare(String(cString: sqlite3_errmsg(connectionPointer)))
        }
        defer { sqlite3_finalize(statement) }
        try bind(values, to: statement)

        var result: [[String: SQLiteValue]] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            var row: [String: SQLiteValue] = [:]
            for index in 0..<sqlite3_column_count(statement) {
                let name = String(cString: sqlite3_column_name(statement, index))
                switch sqlite3_column_type(statement, index) {
                case SQLITE_INTEGER: row[name] = .int(sqlite3_column_int64(statement, index))
                case SQLITE_FLOAT: row[name] = .double(sqlite3_column_double(statement, index))
                case SQLITE_TEXT:
                    if let pointer = sqlite3_column_text(statement, index) { row[name] = .text(String(cString: pointer)) }
                case SQLITE_BLOB:
                    let length = Int(sqlite3_column_bytes(statement, index))
                    if let pointer = sqlite3_column_blob(statement, index), length > 0 {
                        row[name] = .blob(Data(bytes: pointer, count: length))
                    } else {
                        row[name] = .blob(Data())
                    }
                default: row[name] = .null
                }
            }
            result.append(row)
        }
        return result
    }

    private func scalarInt(_ sql: String, _ values: [SQLiteValue] = []) throws -> Int64 {
        try rows(sql, values).first?.values.first?.int64 ?? 0
    }

    private func bind(_ values: [SQLiteValue], to statement: OpaquePointer) throws {
        for (offset, value) in values.enumerated() {
            let index = Int32(offset + 1)
            let result: Int32
            switch value {
            case .text(let text): result = sqlite3_bind_text(statement, index, text, -1, sqliteTransient)
            case .int(let integer): result = sqlite3_bind_int64(statement, index, integer)
            case .double(let number): result = sqlite3_bind_double(statement, index, number)
            case .blob(let data):
                result = data.withUnsafeBytes { buffer in
                    sqlite3_bind_blob(statement, index, buffer.baseAddress, Int32(data.count), sqliteTransient)
                }
            case .null: result = sqlite3_bind_null(statement, index)
            }
            guard result == SQLITE_OK else { throw DatabaseError.bind("SQLite bind error \(result)") }
        }
    }

    private func transaction(_ body: () throws -> Void) throws {
        try execute("BEGIN IMMEDIATE TRANSACTION;")
        do {
            try body()
            try execute("COMMIT;")
        } catch {
            try? execute("ROLLBACK;")
            throw error
        }
    }
}
