import Foundation

public enum LaunchArguments {
    public static let portfolioUITesting = "-portfolioUITesting"
    public static let selectionUITesting = "-keptoraSelectionUITesting"
    public static let photosDeniedUITesting = "-keptoraPhotosDeniedUITesting"
    public static let resetSourceSetupUITesting = "-keptoraResetSourceSetupUITesting"
    public static let thousandsStressUITesting = "-keptoraThousandsStressUITesting"
    public static let syntheticScanUITesting = "-keptoraSyntheticScanUITesting"
    public static let comprehensiveUITesting = "-keptoraComprehensiveUITesting"
    public static let videoReviewUITesting = "-keptoraVideoReviewUITesting"
    public static let hideTips = "-keptoraHideTips"
    public static let resetTips = "-keptoraResetTips"
    public static let uiTestingEnvironmentKey = "KEPTORA_UI_TESTING"

    public static func contains(_ argument: String) -> Bool {
        ProcessInfo.processInfo.arguments.contains(argument)
    }

    public static func isUITestFixtureEnabled(
        _ argument: String,
        arguments: [String] = ProcessInfo.processInfo.arguments,
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) -> Bool {
        #if DEBUG
        return arguments.contains(argument) && environment[uiTestingEnvironmentKey] == "1"
        #else
        return false
        #endif
    }
}
