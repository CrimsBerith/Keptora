import KeptoraCore
import SwiftUI
import TipKit

/// One-time hints shown in context the first time a feature matters, instead of permanent helper text.
/// At most one tip is eligible at a time: the preview tip before the first selection, the undo tip after it.
enum MobileTips {
    /// Only first use matters. A parameter avoids capturing donation collection
    /// key paths in TipKit's generated concurrent predicates.
    @Parameter static var hasChangedSelection: Bool = false

    /// Call once at launch. UI tests pass `-keptoraHideTips` so tips never cover the controls they tap.
    static func configure() {
        #if DEBUG
        if LaunchArguments.contains(LaunchArguments.hideTips) { Tips.hideAllTipsForTesting() }
        if LaunchArguments.contains(LaunchArguments.resetTips) { try? Tips.resetDatastore() }
        #endif
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    static func recordSelectionChange() {
        hasChangedSelection = true
    }
}

struct PreviewPhotoTip: Tip {
    var title: Text { Text("See a photo larger") }
    var message: Text? { Text("Tap a photo to select it. Touch and hold to preview, select or protect it.") }
    var image: Image? { Image(systemName: "hand.tap") }
    var rules: [Rule] { [#Rule(MobileTips.$hasChangedSelection) { $0 == false }] }
}

struct UndoSelectionTip: Tip {
    var title: Text { Text("Undo any step") }
    var message: Text? { Text("Undo brings back the previous selection, one step at a time.") }
    var image: Image? { Image(systemName: "arrow.uturn.backward") }
    var rules: [Rule] { [#Rule(MobileTips.$hasChangedSelection) { $0 == true }] }
}
