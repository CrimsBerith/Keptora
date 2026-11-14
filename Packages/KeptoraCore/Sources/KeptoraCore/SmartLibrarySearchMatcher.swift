import Foundation

/// Fast, on-device smart search engine matching media assets by:
/// - Filename & display name
/// - Album memberships
/// - Folder / directory paths
/// - Camera & lens equipment
/// - Date expressions (Years e.g. "2024", Months in TR & EN e.g. "Kasım", "November", seasons e.g. "Yaz", "Kış")
/// - Media flags ("favorite" / "favori", "video", "screenshot" / "ekran görüntüsü", "live", "burst")
/// - Smart trip & travel recognition ("gezi", "tatil", "travel", "trip", "vacation", GPS locations)
/// - Semantic concepts (nature/manzara, animals/kedi/köpek, food/yemek, architecture/şehir, documents/belge)
/// - Classification tags from on-device Vision analysis
public struct SmartLibrarySearchMatcher: Sendable {

    private static let monthDictionary: [Int: [String]] = [
        1: ["ocak", "january", "jan"],
        2: ["subat", "february", "feb"],
        3: ["mart", "march", "mar"],
        4: ["nisan", "april", "apr"],
        5: ["mayis", "may"],
        6: ["haziran", "june", "jun"],
        7: ["temmuz", "july", "jul"],
        8: ["agustos", "august", "aug"],
        9: ["eylul", "september", "sep"],
        10: ["ekim", "october", "oct"],
        11: ["kasim", "november", "nov"],
        12: ["aralik", "december", "dec"]
    ]

    private static let seasonMonths: [String: Set<Int>] = [
        "yaz": [6, 7, 8],
        "summer": [6, 7, 8],
        "sonbahar": [9, 10, 11],
        "autumn": [9, 10, 11],
        "fall": [9, 10, 11],
        "guz": [9, 10, 11],
        "kis": [12, 1, 2],
        "winter": [12, 1, 2],
        "ilkbahar": [3, 4, 5],
        "spring": [3, 4, 5],
        "bahar": [3, 4, 5]
    ]

    private static let travelKeywords: Set<String> = [
        "gezi", "tatil", "seyahat", "yolculuk", "tur", "travel", "trip",
        "vacation", "holiday", "tour", "voyage", "journey", "kamping",
        "summer", "yaz", "gezisi", "tatili", "geziler", "turlar", "rota"
    ]

    private static let popularTravelDestinations: Set<String> = [
        "roma", "rome", "paris", "antalya", "bodrum", "izmir", "istanbul",
        "kapadokya", "cappadocia", "mugla", "fethiye", "cesme", "marmaris",
        "londra", "london", "berlin", "amsterdam", "barcelona", "madrid",
        "tokyo", "new york", "dubai", "venice", "venedik", "milano", "milan",
        "florence", "floransa", "vienna", "viyana", "prag", "prague", "atina", "athens"
    ]

    private static let travelVisionTags: Set<String> = [
        "travel", "vacation", "tourism", "outdoor", "nature", "beach", "mountain",
        "landscape", "monument", "flight", "airplane", "luggage", "hotel",
        "resort", "scenic", "sightseeing", "tourist", "ocean", "sea"
    ]

    private static let natureKeywords: Set<String> = [
        "manzara", "doga", "nature", "landscape", "deniz", "plaj", "beach",
        "dag", "mountain", "orman", "forest", "gol", "lake", "gokyuzu", "sky",
        "gun batimi", "sunset", "sunrise", "gun dogumu"
    ]

    private static let natureVisionTags: Set<String> = [
        "nature", "landscape", "beach", "mountain", "sea", "ocean", "lake", "sky", "forest", "sunset", "tree", "plant"
    ]

    private static let petKeywords: Set<String> = [
        "kedi", "kopek", "hayvan", "cat", "dog", "pet", "animal", "kus", "bird", "yavru", "puppy", "kitten"
    ]

    private static let petVisionTags: Set<String> = [
        "cat", "dog", "pet", "animal", "bird", "wildlife", "mammal"
    ]

    private static let foodKeywords: Set<String> = [
        "yemek", "tatli", "kahvalti", "restoran", "restaurant", "food", "drink",
        "cafe", "kafe", "kahve", "coffee", "tatlilar", "aksam yemegi", "ogle yemegi"
    ]

    private static let foodVisionTags: Set<String> = [
        "food", "drink", "meal", "dessert", "restaurant", "beverage", "dish"
    ]

    private static let cityKeywords: Set<String> = [
        "sehir", "bina", "mimari", "city", "building", "architecture",
        "sokak", "street", "kopru", "bridge", "kule", "tower", "cadde"
    ]

    private static let cityVisionTags: Set<String> = [
        "city", "building", "architecture", "street", "bridge", "tower", "urban"
    ]

    private static let docKeywords: Set<String> = [
        "belge", "evrak", "fis", "fatura", "makbuz", "document", "receipt", "invoice", "paper", "yazi", "dekont"
    ]

    private static let docVisionTags: Set<String> = [
        "document", "receipt", "paper", "text"
    ]

    /// Normalizes Turkish characters and uppercase letters to ASCII lowercase for reliable comparison.
    public static func normalize(_ text: String) -> String {
        text.replacingOccurrences(of: "İ", with: "i")
            .replacingOccurrences(of: "I", with: "i")
            .replacingOccurrences(of: "ı", with: "i")
            .replacingOccurrences(of: "Ğ", with: "g")
            .replacingOccurrences(of: "ğ", with: "g")
            .replacingOccurrences(of: "Ü", with: "u")
            .replacingOccurrences(of: "ü", with: "u")
            .replacingOccurrences(of: "Ş", with: "s")
            .replacingOccurrences(of: "ş", with: "s")
            .replacingOccurrences(of: "Ö", with: "o")
            .replacingOccurrences(of: "ö", with: "o")
            .replacingOccurrences(of: "Ç", with: "c")
            .replacingOccurrences(of: "ç", with: "c")
            .lowercased()
            .replacingOccurrences(of: "\u{0307}", with: "")
    }

    /// Tokenizes query into distinct search terms.
    public static func tokenize(_ query: String) -> [String] {
        let normalized = normalize(query)
        return normalized.split { $0.isWhitespace || $0 == "," || $0 == "." || $0 == "-" || $0 == "/" }
            .map(String.init)
            .filter { !$0.isEmpty }
    }

    /// Evaluates whether an asset matches the given search query.
    public static func matches(asset: UniversalMediaAsset, query: String, tags: [String] = []) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let tokens = tokenize(trimmed)
        guard !tokens.isEmpty else { return true }

        // All tokens must match (AND logic)
        for token in tokens {
            if !tokenMatches(token: token, asset: asset, tags: tags) {
                return false
            }
        }
        return true
    }

    private static func tokenMatches(token: String, asset: UniversalMediaAsset, tags: [String]) -> Bool {
        // 1. Direct Display Name Match
        if normalize(asset.displayName).contains(token) {
            return true
        }

        // 2. Album Name Match
        if let albums = asset.context?.albums {
            for album in albums {
                if normalize(album.title).contains(token) {
                    return true
                }
            }
        }

        // 3. File Path Match (for Folder / File Provider items)
        if case .file(let url) = asset.reference {
            if normalize(url.path).contains(token) {
                return true
            }
        }

        // 4. Camera & Equipment Match
        if let camera = asset.context?.camera, normalize(camera).contains(token) {
            return true
        }

        // 5. Date & Time Expressions
        if let date = asset.context?.captureDate ?? asset.creationDate {
            let cal = Calendar.current
            let year = cal.component(.year, from: date)
            let month = cal.component(.month, from: date)
            let day = cal.component(.day, from: date)

            if token == "\(year)" {
                return true
            }
            if monthDictionary[month]?.contains(where: { $0.contains(token) || token.contains($0) }) == true {
                return true
            }
            if seasonMonths[token]?.contains(month) == true {
                return true
            }
            if token == "\(day)" {
                return true
            }
        }
        if let dateText = asset.context?.captureDateText, normalize(dateText).contains(token) {
            return true
        }

        // 6. Media Flags & Subtypes
        if token == "favori" || token == "favorite" || token == "fav" || token == "star" || token == "yildiz" {
            if asset.isFavorite { return true }
        }
        if token == "video" || token == "videolar" || token == "film" || token == "movie" {
            if asset.mediaKind == .video { return true }
        }
        if token == "fotograf" || token == "photo" || token == "image" || token == "resim" {
            if asset.mediaKind == .image { return true }
        }
        if token == "screenshot" || token == "ekran goruntusu" || token == "ekran resmi" || token == "ss" {
            if asset.context?.isScreenshot == true { return true }
        }
        if token == "canli" || token == "live" || token == "live photo" {
            if asset.context?.isLivePhoto == true { return true }
        }
        if token == "seri" || token == "burst" {
            if asset.context?.burstID != nil { return true }
        }

        // 7. Semantic Trip & Travel ("gezi", "tatil", "seyahat", "travel", "trip")
        if travelKeywords.contains(where: { token.hasPrefix($0) || $0.hasPrefix(token) }) {
            // Check album titles for travel keywords or popular vacation destinations
            if let albums = asset.context?.albums {
                for album in albums {
                    let albumNorm = normalize(album.title)
                    if travelKeywords.contains(where: { albumNorm.contains($0) }) {
                        return true
                    }
                    if popularTravelDestinations.contains(where: { albumNorm.contains($0) }) {
                        return true
                    }
                }
            }
            // Check folder path
            if case .file(let url) = asset.reference {
                let pathNorm = normalize(url.path)
                if travelKeywords.contains(where: { pathNorm.contains($0) }) {
                    return true
                }
            }
            // Outdoor & travel photos possess GPS coordinates
            if asset.context?.location != nil {
                return true
            }
            // Match vision tags
            if tags.contains(where: { travelVisionTags.contains($0) }) {
                return true
            }
        }

        // 8. Semantic Nature & Landscape
        if natureKeywords.contains(where: { token.contains($0) || $0.contains(token) }) {
            if let albums = asset.context?.albums, albums.contains(where: { album in
                let norm = normalize(album.title)
                return natureKeywords.contains(where: { norm.contains($0) })
            }) {
                return true
            }
            if tags.contains(where: { natureVisionTags.contains($0) }) {
                return true
            }
        }

        // 9. Semantic Animals & Pets
        if petKeywords.contains(where: { token.contains($0) || $0.contains(token) }) {
            if let albums = asset.context?.albums, albums.contains(where: { album in
                let norm = normalize(album.title)
                return petKeywords.contains(where: { norm.contains($0) })
            }) {
                return true
            }
            if tags.contains(where: { petVisionTags.contains($0) }) {
                return true
            }
        }

        // 10. Semantic Food & Drinks
        if foodKeywords.contains(where: { token.contains($0) || $0.contains(token) }) {
            if let albums = asset.context?.albums, albums.contains(where: { album in
                let norm = normalize(album.title)
                return foodKeywords.contains(where: { norm.contains($0) })
            }) {
                return true
            }
            if tags.contains(where: { foodVisionTags.contains($0) }) {
                return true
            }
        }

        // 11. Semantic City & Architecture
        if cityKeywords.contains(where: { token.contains($0) || $0.contains(token) }) {
            if let albums = asset.context?.albums, albums.contains(where: { album in
                let norm = normalize(album.title)
                return cityKeywords.contains(where: { norm.contains($0) })
            }) {
                return true
            }
            if tags.contains(where: { cityVisionTags.contains($0) }) {
                return true
            }
        }

        // 12. Semantic Documents & Receipts
        if docKeywords.contains(where: { token.contains($0) || $0.contains(token) }) {
            if asset.context?.isScreenshot == true {
                return true
            }
            if let albums = asset.context?.albums, albums.contains(where: { album in
                let norm = normalize(album.title)
                return docKeywords.contains(where: { norm.contains($0) })
            }) {
                return true
            }
            if tags.contains(where: { docVisionTags.contains($0) }) {
                return true
            }
        }

        // 13. Direct Vision Tags Match
        if tags.contains(where: { normalize($0).contains(token) }) {
            return true
        }

        return false
    }
}
