import Foundation

public enum AppStorageKeys {
    public static let appLanguage = "Keptora.AppLanguage"
    public static let showFilePaths = "Keptora.ShowFilePaths"
    public static let checkpointInterval = "Keptora.CheckpointInterval"
    public static let featureSimilarity = "Keptora.Feature.Similarity.v1"
    public static let featurePhotoKitBytes = "Keptora.Feature.PhotoKitBytes.v1"
    public static let keeperSelectionPolicy = "Keptora.KeeperSelectionPolicy"
    public static let similaritySensitivity = "Keptora.SimilaritySensitivity.v1"
    public static let sourceBookmark = "Keptora.SourceBookmark.v1"
    public static let sourceVolume = "Keptora.SourceVolume.v1"
    public static let onboardingCompleted = "Keptora.Onboarding.Completed.v1"
    public static let macSourceSetupCompleted = "Keptora.SourceSetup.Mac.v1"
    public static let iOSSourceSetupCompleted = "Keptora.SourceSetup.iOS.v1"
    public static let reviewCheckpoint = "Keptora.ReviewCheckpoint.v1"
    public static let trialReviewedAssetIDs = "Keptora.Trial.ReviewedAssetIDs.v1"
    public static let excludedFolderNames = "Keptora.ExcludedFolderNames"
    public static let excludedExtensions = "Keptora.ExcludedExtensions"

    // iOS-specific keys
    public static let iOSSourceBookmark = "Keptora.iOS.SourceBookmark.v1"
    public static let iOSCleanupHistory = "Keptora.iOS.CleanupHistory.v1"
    public static let iOSScanCheckpoint = "Keptora.iOS.ScanCheckpoint.v1"
    public static let iOSReviewedAssets = "Keptora.iOS.ReviewedAssets.v1"
}
