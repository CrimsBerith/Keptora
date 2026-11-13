# Keptora — Traceability Matrix (%100 Kapsam Matrisi)
**Tarih:** 2 Kasım 2026  
**Commit SHA:** `cb30a9706bee78df016789cb9fd97e641b5c1bd7`

| Kapsam Alanı | Birincil Ajan | İkinci Kontrol | Dosya ve Kod Yolu | Kanıt / Durum | Gate Sonucu |
|---|---|---|---|---|---|
| Proje envanteri, scope, backlog, dependencies | 01 keptora-command | 02, 11 | `project.yml`, `Package.swift`, `AGENTS.md` | `rtk git status`, `python3 Scripts/validate_project_references.py` | **PASS** |
| Swift/XcodeGen/Swift concurrency/data contracts | 02 keptora-architecture | 11, 09 | `Packages/KeptoraCore/Sources/` | `rtk swift test --package-path Packages/KeptoraCore` (127 tests) | **PASS** |
| SQLite, state persistence, cache, migrations | 02 keptora-architecture | 05, 11 | `Keptora/Services/Database/`, `Packages/KeptoraCore/` | In-memory roundtrip, revision-cached verification | **PASS** |
| PhotoKit/iCloud/limited permission | 03 keptora-sources | 07, 09 | `PhotoLibrarySourceAdapter.swift`, `KeptoraiOS/` | Limited access handling, async cancel, iCloud placeholder | **PASS** (Simülatör/Native) |
| Files/folder/bookmark/external volume | 03 keptora-sources | 05, 11 | `FolderSourceAdapter.swift`, `MacSourceAccessCoordinator.swift` | Canonical path resolution, symlink rejection | **PASS** |
| Exact SHA-256, similar, Vision, metadata | 04 keptora-media-intelligence | 05, 11 | `LibraryAnalysisCoordinator.swift`, `BulkCleanupPolicyTests.swift` | Full byte-hash SHA-256 check, Vision similarity thresholds | **PASS** |
| RAW/JPEG/XMP/AAE/Live/burst/video | 04 keptora-media-intelligence | 03, 11 | `MediaItem.swift`, `KeptoraCore` | Format family integrity, no sidecar separation | **PASS** |
| Manual/bulk selections, keeper/protection | 05 keptora-safety-recovery | 06, 07 | `FrozenSelectionReview.swift`, `MacArchiveModel.swift` | Bounded 50-step Undo/Redo, favorite/protected preservation | **PASS** |
| PhotoKit removal, quarantine & restore | 05 keptora-safety-recovery | 09, 11 | `LibraryCleanupPreflight.swift`, `FolderQuarantineExecutor.swift` | Recently Deleted route, manifest ledger, no-overwrite restore | **PASS** |
| macOS desktop/gallery/menu/keyboard | 06 keptora-macos | 08, 11 | `MacArchiveView.swift`, `MacArchiveModel.swift` | Single filter button, 1:1 zero-jitter grid, menu & shortcuts | **PASS** |
| iOS gallery/gestures/tabs/preview | 07 keptora-iphone | 08, 11 | `MobileReviewView.swift`, `MobileSplitComparisonView.swift` | Side-by-side comparison, zero-jitter grid, gestures | **PASS** |
| Design System/UX/VoiceOver/locales | 08 keptora-experience | 06, 07 | `Resources/*.lproj/`, `.xcstrings` | `python3 Scripts/validate_mac_localization.py` (273 keys) | **PASS** |
| Sandbox, data privacy, network, supply chain | 09 keptora-privacy-security | 05, 11 | `Keptora.entitlements`, `PrivacyInfo.xcprivacy` | Local-first, zero analytics/telemetry, no external network upload | **PASS** |
| StoreKit, lifetime unlock, free policy | 10 keptora-storekit | 07, 11 | `Keptora.storekit`, `AccessPolicy.swift` | Lifetime non-consumable, free manual cleanup, ASC parity | **PASS** |
| CI, test gaps, benchmarks and crashes | 11 keptora-quality | 02, 05 | `.github/workflows/apple-validation.yml`, `Tests/` | 127 core tests passing, iOS unit tests passing | **PASS** |
| App Store metadata/ASO/legal/TestFlight | 12 keptora-release-growth | 08, 09, 10 | `AppStore/`, App Store Connect | macOS Live, iOS 1.0 (Build 186) + IAP Waiting for Review | **PASS** (Waiting Review) |
| Post-release incidents, privacy-friendly feedback | 12 keptora-release-growth | 01, 11 | Runbook & Support URL | Support URL & Privacy Policy live | **PASS** |

