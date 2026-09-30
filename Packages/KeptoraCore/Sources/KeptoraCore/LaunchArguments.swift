import Foundation

public enum LaunchArguments {
    public static let portfolioUITesting = "-portfolioUITesting"
    public static let screenshotReconciliation = "-keptoraScreenshotReconciliation"
    public static let selectionUITesting = "-keptoraSelectionUITesting"
    public static let photosDeniedUITesting = "-keptoraPhotosDeniedUITesting"
    public static let thousandsStressUITesting = "-keptoraThousandsStressUITesting"
    public static let comprehensiveUITesting = "-keptoraComprehensiveUITesting"
    public static let videoReviewUITesting = "-keptoraVideoReviewUITesting"

    public static func contains(_ argument: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }
}
