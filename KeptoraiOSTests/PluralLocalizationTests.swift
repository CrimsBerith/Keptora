import KeptoraCore
import XCTest
@testable import KeptoraiOS

/// Count strings must use the language's singular and plural forms ("1 item", "2 items").
final class PluralLocalizationTests: XCTestCase {
    private let languageKey = "Keptora.AppLanguage"
    private var savedLanguage: Any?

    override func setUp() { savedLanguage = UserDefaults.standard.object(forKey: languageKey) }
    override func tearDown() { UserDefaults.standard.set(savedLanguage, forKey: languageKey) }

    private func plural(_ key: String, _ count: Int, in language: String) -> String {
        UserDefaults.standard.set(language, forKey: languageKey)
        return L10n.plural(key, count)
    }

    func testRemoveButtonUsesSingularAndPlural() {
        XCTAssertEqual(plural("Remove %lld Items", 1, in: "en"), "Remove 1 Item")
        XCTAssertEqual(plural("Remove %lld Items", 3, in: "en"), "Remove 3 Items")
        XCTAssertEqual(plural("Remove %lld Items", 1, in: "de"), "1 Element entfernen")
        XCTAssertEqual(plural("Remove %lld Items", 3, in: "de"), "3 Elemente entfernen")
        XCTAssertEqual(plural("Remove %lld Items", 1, in: "fr"), "Retirer 1 élément")
        XCTAssertEqual(plural("Remove %lld Items", 3, in: "fr"), "Retirer 3 éléments")
        XCTAssertEqual(plural("Remove %lld Items", 3, in: "tr"), "3 Öğeyi Kaldır")
    }

    func testItemCountsUseSingularAndPlural() {
        XCTAssertEqual(plural("%lld items", 1, in: "en"), "1 item")
        XCTAssertEqual(plural("In this list: %lld items", 8, in: "de"), "In dieser Liste: 8 Elemente")
        XCTAssertEqual(plural("In this list: %lld items", 1, in: "fr"), "Dans cette liste : 1 élément")
    }
}
