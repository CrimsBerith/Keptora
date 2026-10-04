// swift-tools-version: 5.9
import PackageDescription
import Foundation

// Apple adapters remain Apple-only. Linux validates the same shared catalogue,
// selection and metadata policy models without replacing Apple APIs with stubs.
#if os(Linux)
let portableSources = ["LibraryModels.swift", "LibraryWorkflow.swift", "StableDigest.swift", "AnalysisModels.swift", "QualityAssessment.swift", "MediaFingerprintDiskCache.swift", "MediaWorkGate.swift"]
let appleSources = (try? FileManager.default.contentsOfDirectory(atPath: URL(fileURLWithPath: #filePath).deletingLastPathComponent().appendingPathComponent("Sources/KeptoraCore").path))?.filter { !portableSources.contains($0) } ?? []
let targets: [Target] = [
    .target(name: "KeptoraCore", exclude: appleSources, sources: portableSources),
    .testTarget(name: "KeptoraCoreTests", dependencies: ["KeptoraCore"], exclude: ["KeptoraCoreTests.swift", "MetadataDoctorTests.swift", "NativeAnalysisBenchmarkTests.swift"], sources: ["LibraryWorkflowTests.swift", "BulkCleanupPolicyTests.swift"])
]
#else
let targets: [Target] = [
    .target(name: "KeptoraCore", linkerSettings: [
        .linkedFramework("Photos"), .linkedFramework("ImageIO"),
        .linkedFramework("AVFoundation"), .linkedFramework("Vision")
    ]),
    .testTarget(name: "KeptoraCoreTests", dependencies: ["KeptoraCore"])
]
#endif

let package = Package(
    name: "KeptoraCore",
    defaultLocalization: "en",
    platforms: [.macOS(.v13), .iOS(.v17)],
    products: [.library(name: "KeptoraCore", targets: ["KeptoraCore"])],
    targets: targets
)
