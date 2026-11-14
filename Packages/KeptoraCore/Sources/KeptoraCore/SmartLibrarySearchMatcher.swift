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
        "summer", "yaz", "gezisi", "tatili", "geziler", "turlar", "rota",
        "otel", "hotel", "resort", "plaj", "beach", "sahil", "havalimani", "airport"
    ]

    public struct DestinationArea: Sendable {
        public let name: String
        public let minLat: Double
        public let maxLat: Double
        public let minLon: Double
        public let maxLon: Double
        public let keywords: [String]
        public let isTravelDestination: Bool

        public func contains(lat: Double, lon: Double) -> Bool {
            lat >= minLat && lat <= maxLat && lon >= minLon && lon <= maxLon
        }
    }

    private static let destinationAreas: [DestinationArea] = [
        // Mediterranean & Aegean Travel
        DestinationArea(
            name: "Antalya Coast",
            minLat: 36.10, maxLat: 37.30, minLon: 29.10, maxLon: 32.60,
            keywords: ["antalya", "alanya", "kemer", "kas", "kalkan", "side", "manavgat", "cirali", "olympos", "akdeniz", "tatil", "gezi", "plaj", "beach", "sea", "deniz"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Muğla Coast",
            minLat: 36.50, maxLat: 37.45, minLon: 27.20, maxLon: 29.35,
            keywords: ["bodrum", "marmaris", "fethiye", "mugla", "oludeniz", "datca", "gocek", "akyaka", "dalyan", "tatil", "gezi", "ege", "plaj", "beach", "sea", "deniz"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "İzmir & Çeşme",
            minLat: 38.10, maxLat: 38.80, minLon: 26.20, maxLon: 27.40,
            keywords: ["izmir", "cesme", "alacati", "urla", "foca", "dikili", "tatil", "gezi", "plaj", "ege"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Kapadokya",
            minLat: 38.45, maxLat: 38.85, minLon: 34.60, maxLon: 35.15,
            keywords: ["kapadokya", "cappadocia", "nevsehir", "goreme", "urgup", "uchisar", "avanos", "balon", "tatil", "gezi"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Karadeniz",
            minLat: 40.70, maxLat: 41.40, minLon: 39.40, maxLon: 41.70,
            keywords: ["trabzon", "rize", "karadeniz", "ayder", "uzungol", "artvin", "yayla", "doga", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Bursa & Uludağ",
            minLat: 40.05, maxLat: 40.35, minLon: 28.90, maxLon: 29.35,
            keywords: ["bursa", "uludag", "kayak", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Çanakkale & Adalar",
            minLat: 39.75, maxLat: 40.40, minLon: 25.60, maxLon: 26.85,
            keywords: ["canakkale", "bozcaada", "gokceada", "assos", "tatil", "gezi"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Ayvalık & Cunda",
            minLat: 39.20, maxLat: 39.70, minLon: 26.50, maxLon: 27.10,
            keywords: ["ayvalik", "cunda", "balikesir", "tatil", "gezi", "ege", "plaj"],
            isTravelDestination: true
        ),
        // Major Turkish Metropolises
        DestinationArea(
            name: "İstanbul",
            minLat: 40.80, maxLat: 41.35, minLon: 28.50, maxLon: 29.50,
            keywords: ["istanbul", "bogaz", "kadikoy", "besiktas", "uskudar", "sultanahmet", "taksim", "adalar", "eminonu"],
            isTravelDestination: false
        ),
        DestinationArea(
            name: "Ankara",
            minLat: 39.80, maxLat: 40.10, minLon: 32.60, maxLon: 33.10,
            keywords: ["ankara", "anitkabir", "baskent", "cankaya", "kizilay"],
            isTravelDestination: false
        ),
        // International Travel Hubs
        DestinationArea(
            name: "Rome",
            minLat: 41.75, maxLat: 42.05, minLon: 12.35, maxLon: 12.65,
            keywords: ["roma", "rome", "italya", "italy", "koloseum", "colosseum", "vatikan", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Florence",
            minLat: 43.70, maxLat: 43.85, minLon: 11.20, maxLon: 11.35,
            keywords: ["florence", "floransa", "toskana", "tuscany", "italya", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Venice",
            minLat: 45.40, maxLat: 45.48, minLon: 12.30, maxLon: 12.40,
            keywords: ["venice", "venedik", "italya", "gondol", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Milan",
            minLat: 45.40, maxLat: 45.55, minLon: 9.10, maxLon: 9.30,
            keywords: ["milan", "milano", "italya", "duomo", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Paris",
            minLat: 48.80, maxLat: 48.92, minLon: 2.20, maxLon: 2.45,
            keywords: ["paris", "eyfel", "eiffel", "fransa", "france", "louvre", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "French Riviera",
            minLat: 43.50, maxLat: 43.80, minLon: 6.90, maxLon: 7.50,
            keywords: ["nice", "cannes", "monaco", "fransa", "tatil", "gezi", "sahil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "London",
            minLat: 51.40, maxLat: 51.65, minLon: -0.30, maxLon: 0.15,
            keywords: ["londra", "london", "ingiltere", "uk", "britanya", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Barcelona",
            minLat: 41.30, maxLat: 41.48, minLon: 2.05, maxLon: 2.25,
            keywords: ["barcelona", "ispanya", "spain", "barselona", "sagrada", "tatil", "gezi"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Madrid",
            minLat: 40.35, maxLat: 40.50, minLon: -3.80, maxLon: -3.60,
            keywords: ["madrid", "ispanya", "spain", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Amsterdam",
            minLat: 52.30, maxLat: 52.45, minLon: 4.80, maxLon: 5.00,
            keywords: ["amsterdam", "hollanda", "netherlands", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Berlin",
            minLat: 52.40, maxLat: 52.60, minLon: 13.20, maxLon: 13.60,
            keywords: ["berlin", "almanya", "germany", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Vienna",
            minLat: 48.12, maxLat: 48.30, minLon: 16.25, maxLon: 16.50,
            keywords: ["viyana", "vienna", "avusturya", "austria", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Prague",
            minLat: 50.00, maxLat: 50.15, minLon: 14.30, maxLon: 14.55,
            keywords: ["prag", "prague", "cekya", "czech", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Athens",
            minLat: 37.90, maxLat: 38.05, minLon: 23.65, maxLon: 23.85,
            keywords: ["atina", "athens", "yunanistan", "greece", "akropolis", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Greek Islands",
            minLat: 35.00, maxLat: 38.00, minLon: 23.50, maxLon: 28.50,
            keywords: ["yunanistan", "adalar", "santorini", "mikonos", "mykonos", "rodos", "girit", "crete", "tatil", "gezi", "plaj"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Dubai",
            minLat: 24.95, maxLat: 25.35, minLon: 55.05, maxLon: 55.45,
            keywords: ["dubai", "bae", "uae", "burj", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "New York",
            minLat: 40.55, maxLat: 40.90, minLon: -74.10, maxLon: -73.80,
            keywords: ["new york", "nyc", "manhattan", "abd", "usa", "gezi", "tatil"],
            isTravelDestination: true
        ),
        DestinationArea(
            name: "Tokyo",
            minLat: 35.50, maxLat: 35.80, minLon: 139.55, maxLon: 139.90,
            keywords: ["tokyo", "japonya", "japan", "gezi", "tatil"],
            isTravelDestination: true
        )
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

        // 7. Geographic Location & Place Names (Cities, Landmarks, Travel Destinations)
        if let location = asset.context?.location {
            for dest in destinationAreas {
                if dest.contains(lat: location.latitude, lon: location.longitude) {
                    if dest.keywords.contains(where: { token == $0 || token.hasPrefix($0) || $0.hasPrefix(token) }) {
                        return true
                    }
                }
            }
        }

        // 8. Semantic Trip & Travel ("gezi", "tatil", "seyahat", "travel", "trip")
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
            // Check if GPS coordinates fall in recognized travel destinations (Antalya, Bodrum, Rome, Paris, Cappadocia, etc.)
            if let location = asset.context?.location {
                for dest in destinationAreas where dest.isTravelDestination {
                    if dest.contains(lat: location.latitude, lon: location.longitude) {
                        return true
                    }
                }
                // Photos taken outside Turkey (international travels) are trips
                let isInTurkey = location.latitude >= 35.8 && location.latitude <= 42.1 && location.longitude >= 25.6 && location.longitude <= 44.8
                if !isInTurkey {
                    return true
                }
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
