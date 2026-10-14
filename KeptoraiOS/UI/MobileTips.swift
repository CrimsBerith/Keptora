import KeptoraCore
import SwiftUI
import TipKit

/// One-time hints shown in context the first time a feature matters, instead of permanent helper text.
/// At most one tip is eligible at a time: the preview tip before the first selection, the undo tip after it.
enum MobileTips {
    /// Donated each time the person selects or deselects a photo in the gallery.
    static let selectionChanged = Tips.Event(id: "selectionChanged")

    /// Call once at launch. UI tests pass `-keptoraHideTips` so tips never cover the controls they tap.
    static func configure() {
        if LaunchArguments.contains(LaunchArguments.hideTips) { Tips.hideAllTipsForTesting() }
        if LaunchArguments.contains(LaunchArguments.resetTips) { try? Tips.resetDatastore() }
        try? Tips.configure([.displayFrequency(.immediate)])
    }

    static func recordSelectionChange() {
        Task { await selectionChanged.donate() }
    }
}

struct PreviewPhotoTip: Tip {
    var title: Text { Text("See a photo larger") }
    var message: Text? { Text("Tap a photo to select it. Touch and hold to preview, select or protect it.") }
    var image: Image? { Image(systemName: "hand.tap") }
    var rules: [Rule] { [#Rule(MobileTips.selectionChanged) { $0.donations.count == 0 }] }
}

struct UndoSelectionTip: Tip {
    var title: Text { Text("Undo any step") }
    var message: Text? { Text("Undo brings back the previous selection, one step at a time.") }
    var image: Image? { Image(systemName: "arrow.uturn.backward") }
    var rules: [Rule] { [#Rule(MobileTips.selectionChanged) { $0.donations.count >= 1 }] }
}
