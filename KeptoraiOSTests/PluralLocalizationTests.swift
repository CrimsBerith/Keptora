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

    func testActiveFilterCountUsesSingularAndPlural() {
        XCTAssertEqual(plural("%lld active filters", 1, in: "en"), "1 active filter")
        XCTAssertEqual(plural("%lld active filters", 3, in: "en"), "3 active filters")
        XCTAssertEqual(plural("%lld active filters", 1, in: "de"), "1 aktiver Filter")
        XCTAssertEqual(plural("%lld active filters", 3, in: "de"), "3 aktive Filter")
        XCTAssertEqual(plural("%lld active filters", 1, in: "fr"), "1 filtre actif")
        XCTAssertEqual(plural("%lld active filters", 3, in: "fr"), "3 filtres actifs")
        XCTAssertEqual(plural("%lld active filters", 1, in: "tr"), "1 etkin filtre")
        XCTAssertEqual(plural("%lld active filters", 3, in: "tr"), "3 etkin filtre")
    }

    func testSkippedOriginalsCountUsesSingularAndPlural() {
        XCTAssertEqual(plural("%lld originals could not be analyzed. They remain in the library.", 1, in: "en"), "1 original could not be analyzed. It remains in the library.")
        XCTAssertEqual(plural("%lld originals could not be analyzed. They remain in the library.", 2, in: "en"), "2 originals could not be analyzed. They remain in the library.")
        XCTAssertEqual(plural("%lld originals could not be analyzed. They remain in the library.", 1, in: "de"), "1 Original konnte nicht analysiert werden. Es bleibt in der Mediathek.")
        XCTAssertEqual(plural("%lld originals could not be analyzed. They remain in the library.", 2, in: "de"), "2 Originale konnten nicht analysiert werden. Sie bleiben in der Mediathek.")
        XCTAssertEqual(plural("%lld originals could not be analyzed. They remain in the library.", 1, in: "fr"), "1 original n’a pas pu être analysé. Il reste dans la photothèque.")
        XCTAssertEqual(plural("%lld originals could not be analyzed. They remain in the library.", 2, in: "fr"), "2 originaux n’ont pas pu être analysés. Ils restent dans la photothèque.")
        XCTAssertEqual(plural("%lld originals could not be analyzed. They remain in the library.", 1, in: "tr"), "1 asıl dosya analiz edilemedi. Arşivde görünmeye devam eder.")
        XCTAssertEqual(plural("%lld originals could not be analyzed. They remain in the library.", 2, in: "tr"), "2 asıl dosya analiz edilemedi. Arşivde görünmeye devam eder.")
    }

    func testSkippedPreviewsCountUsesSingularAndPlural() {
        XCTAssertEqual(plural("%lld previews could not be analyzed. Results cover only accessible items.", 1, in: "en"), "1 preview could not be analyzed. Results cover only accessible items.")
        XCTAssertEqual(plural("%lld previews could not be analyzed. Results cover only accessible items.", 2, in: "en"), "2 previews could not be analyzed. Results cover only accessible items.")
        XCTAssertEqual(plural("%lld previews could not be analyzed. Results cover only accessible items.", 1, in: "de"), "1 Vorschaubild konnte nicht analysiert werden. Die Ergebnisse umfassen nur zugängliche Elemente.")
        XCTAssertEqual(plural("%lld previews could not be analyzed. Results cover only accessible items.", 2, in: "de"), "2 Vorschaubilder konnten nicht analysiert werden. Die Ergebnisse umfassen nur zugängliche Elemente.")
        XCTAssertEqual(plural("%lld previews could not be analyzed. Results cover only accessible items.", 1, in: "fr"), "1 aperçu n’a pas pu être analysé. Les résultats ne couvrent que les éléments accessibles.")
        XCTAssertEqual(plural("%lld previews could not be analyzed. Results cover only accessible items.", 2, in: "fr"), "2 aperçus n’ont pas pu être analysés. Les résultats ne couvrent que les éléments accessibles.")
        XCTAssertEqual(plural("%lld previews could not be analyzed. Results cover only accessible items.", 1, in: "tr"), "1 önizleme analiz edilemedi. Sonuçlar yalnızca erişilebilen öğeleri kapsar.")
        XCTAssertEqual(plural("%lld previews could not be analyzed. Results cover only accessible items.", 2, in: "tr"), "2 önizleme analiz edilemedi. Sonuçlar yalnızca erişilebilen öğeleri kapsar.")
    }
}
