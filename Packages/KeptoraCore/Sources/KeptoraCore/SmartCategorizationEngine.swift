@preconcurrency import CoreGraphics
@preconcurrency import Vision
import Foundation

/// Primary high-level semantic categories for media assets.
public enum PhotoCategory: String, Codable, Sendable, CaseIterable {
    case natureLandscape = "nature_landscape"
    case peoplePortrait = "people_portrait"
    case animalsPets = "animals_pets"
    case foodDrink = "food_drink"
    case architectureCity = "architecture_city"
    case documentsReceipts = "documents_receipts"
    case screenshotsGraphics = "screenshots_graphics"
    case vehiclesTransport = "vehicles_transport"
    case other = "other"
    
    public var displayName: String {
        switch self {
        case .natureLandscape: return String(localized: "Nature & Landscape")
        case .peoplePortrait: return String(localized: "People & Portraits")
        case .animalsPets: return String(localized: "Animals & Pets")
        case .foodDrink: return String(localized: "Food & Drinks")
        case .architectureCity: return String(localized: "Architecture & City")
        case .documentsReceipts: return String(localized: "Documents & Receipts")
        case .screenshotsGraphics: return String(localized: "Screenshots & Graphics")
        case .vehiclesTransport: return String(localized: "Vehicles & Travel")
        case .other: return String(localized: "General / Other")
        }
    }
    
    public var systemIcon: String {
        switch self {
        case .natureLandscape: return "leaf.fill"
        case .peoplePortrait: return "person.2.fill"
        case .animalsPets: return "pawprint.fill"
        case .foodDrink: return "fork.knife"
        case .architectureCity: return "building.2.fill"
        case .documentsReceipts: return "doc.text.fill"
        case .screenshotsGraphics: return "macwindow"
        case .vehiclesTransport: return "car.fill"
        case .other: return "photo.fill"
        }
    }
}

/// Actionable smart clusters designed to help users declutter or surface the best photos.
public enum SmartBucket: String, Codable, Sendable, CaseIterable {
    case receiptsAndInvoices = "receipts_and_invoices"
    case screenshots = "screenshots"
    case blurryAndDefective = "blurry_and_defective"
    case burstSequences = "burst_sequences"
    case bestShots = "best_shots"
    
    public var title: String {
        switch self {
        case .receiptsAndInvoices: return String(localized: "Receipts & Invoices")
        case .screenshots: return String(localized: "Screenshots & Screen Grabs")
        case .blurryAndDefective: return String(localized: "Blurry & Low Quality")
        case .burstSequences: return String(localized: "Burst Sequences")
        case .bestShots: return String(localized: "Best Shots & Highlights")
        }
    }
    
    public var iconName: String {
        switch self {
        case .receiptsAndInvoices: return "receipt"
        case .screenshots: return "iphone"
        case .blurryAndDefective: return "exclamationmark.triangle.fill"
        case .burstSequences: return "square.stack.3d.forward.dottedline.fill"
        case .bestShots: return "star.fill"
        }
    }
    
    public var isDeclutterCandidate: Bool {
        switch self {
        case .receiptsAndInvoices, .screenshots, .blurryAndDefective, .burstSequences:
            return true
        case .bestShots:
            return false
        }
    }
}

/// Structured outcome of on-device semantic and aesthetic analysis.
public struct SmartCategorizationReport: Codable, Sendable, Hashable {
    public let assetID: String
    public let primaryCategory: PhotoCategory
    public let confidence: Float
    public let secondaryCategories: [PhotoCategory]
    public let tags: [String]
    public let recognizedTextSummary: String?
    public let textCharacterCount: Int
    public let suggestedBucket: SmartBucket?
    public let isDeclutterCandidate: Bool
    public let qualityReport: VisualQualityReport
    
    public init(
        assetID: String,
        primaryCategory: PhotoCategory,
        confidence: Float,
        secondaryCategories: [PhotoCategory] = [],
        tags: [String] = [],
        recognizedTextSummary: String? = nil,
        textCharacterCount: Int = 0,
        suggestedBucket: SmartBucket? = nil,
        isDeclutterCandidate: Bool = false,
        qualityReport: VisualQualityReport
    ) {
        self.assetID = assetID
        self.primaryCategory = primaryCategory
        self.confidence = confidence
        self.secondaryCategories = secondaryCategories
        self.tags = tags
        self.recognizedTextSummary = recognizedTextSummary
        self.textCharacterCount = textCharacterCount
        self.suggestedBucket = suggestedBucket
        self.isDeclutterCandidate = isDeclutterCandidate
        self.qualityReport = qualityReport
    }
}

/// Temporal event or trip cluster grouping photos taken around the same occasion.
public struct EventCluster: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let assetIDs: [String]
    public let heroCoverAssetID: String
    public let totalByteCount: Int64
    
    public init(
        id: String,
        title: String,
        startDate: Date,
        endDate: Date,
        assetIDs: [String],
        heroCoverAssetID: String,
        totalByteCount: Int64
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.assetIDs = assetIDs
        self.heroCoverAssetID = heroCoverAssetID
        self.totalByteCount = totalByteCount
    }
}

/// On-device intelligent media categorization, smart bucket placement, and event clustering engine.
public enum SmartCategorizationEngine: Sendable {
    
    /// Analyzes an image and asset metadata to categorize and evaluate declutter candidacy.
    public static func analyze(
        image: CGImage,
        asset: UniversalMediaAsset
    ) -> SmartCategorizationReport {
        // 1. Evaluate visual quality via VisualQualityEngine
        let quality = VisualQualityEngine.evaluateQuality(for: image, asset: asset)
        
        // 2. Fast OCR text recognition pass
        let textResult = detectText(in: image)
        
        // 3. Vision taxonomy classification
        let (categories, tags) = classifyImage(image: image)
        
        // 4. Heuristic filename & format check for screenshots
        let isScreenshotHeuristic = evaluateScreenshot(asset: asset, image: image, textCount: textResult.charCount)
        
        // 5. Determine primary category
        var primary: PhotoCategory = .other
        var confidence: Float = 0.5
        var secondary: [PhotoCategory] = []
        
        if isScreenshotHeuristic {
            primary = .screenshotsGraphics
            confidence = 0.95
        } else if textResult.charCount > 80 && textResult.hasFinancialOrDocKeywords {
            primary = .documentsReceipts
            confidence = 0.92
        } else if let top = categories.first {
            primary = top.category
            confidence = top.confidence
            secondary = Array(categories.dropFirst().map(\.category).prefix(2))
        }
        
        // 6. Actionable smart bucket assignment
        var suggestedBucket: SmartBucket? = nil
        var isDeclutter = false
        
        if primary == .screenshotsGraphics || isScreenshotHeuristic {
            suggestedBucket = .screenshots
            isDeclutter = true
        } else if primary == .documentsReceipts || (textResult.charCount > 60 && textResult.hasFinancialOrDocKeywords) {
            suggestedBucket = .receiptsAndInvoices
            isDeclutter = true
        } else if quality.sharpnessScore < 28.0 || (quality.sharpnessScore < 40.0 && quality.exposureScore < 30.0) {
            suggestedBucket = .blurryAndDefective
            isDeclutter = true
        } else if quality.compositeScore >= 80.0 && quality.sharpnessScore >= 60.0 {
            suggestedBucket = .bestShots
            isDeclutter = false
        }
        
        return SmartCategorizationReport(
            assetID: asset.id,
            primaryCategory: primary,
            confidence: confidence,
            secondaryCategories: secondary,
            tags: tags,
            recognizedTextSummary: textResult.summary,
            textCharacterCount: textResult.charCount,
            suggestedBucket: suggestedBucket,
            isDeclutterCandidate: isDeclutter,
            qualityReport: quality
        )
    }
    
    /// Groups photos into chronological event/trip clusters with an automatic hero cover photo.
    public static func clusterEvents(
        assets: [UniversalMediaAsset],
        reports: [String: SmartCategorizationReport] = [:],
        clusterGapInterval: TimeInterval = 3600 * 4 // 4-hour inactivity split
    ) -> [EventCluster] {
        let validAssets = assets
            .filter { $0.creationDate != nil }
            .sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        
        guard !validAssets.isEmpty else { return [] }
        
        var groups: [[UniversalMediaAsset]] = []
        var current: [UniversalMediaAsset] = [validAssets[0]]
        
        for i in 1..<validAssets.count {
            let prev = validAssets[i - 1]
            let curr = validAssets[i]
            
            let timeDiff = (curr.creationDate ?? .distantPast).timeIntervalSince(prev.creationDate ?? .distantPast)
            if timeDiff <= clusterGapInterval {
                current.append(curr)
            } else {
                groups.append(current)
                current = [curr]
            }
        }
        if !current.isEmpty {
            groups.append(current)
        }
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .none
        
        return groups.enumerated().map { index, memberAssets in
            let startDate = memberAssets.first?.creationDate ?? Date()
            let endDate = memberAssets.last?.creationDate ?? Date()
            let totalBytes = memberAssets.reduce(0) { $0 + ($1.byteCount ?? 0) }
            
            // Pick highest quality asset as hero cover
            let hero = memberAssets.max { lhs, rhs in
                let lhsScore = reports[lhs.id]?.qualityReport.compositeScore ?? 50.0
                let rhsScore = reports[rhs.id]?.qualityReport.compositeScore ?? 50.0
                return lhsScore < rhsScore
            }
            
            let title: String
            if memberAssets.count >= 20 {
                title = "\(dateFormatter.string(from: startDate)) (\(memberAssets.count) items)"
            } else {
                title = dateFormatter.string(from: startDate)
            }
            
            return EventCluster(
                id: "event:\(index):\(Int(startDate.timeIntervalSince1970))",
                title: title,
                startDate: startDate,
                endDate: endDate,
                assetIDs: memberAssets.map(\.id),
                heroCoverAssetID: hero?.id ?? memberAssets.first?.id ?? "",
                totalByteCount: totalBytes
            )
        }
    }
    
    // MARK: - Private Helpers
    
    private struct TextDetectionResult {
        let summary: String?
        let charCount: Int
        let hasFinancialOrDocKeywords: Bool
    }
    
    private static func detectText(in image: CGImage) -> TextDetectionResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .fast
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard let _ = try? handler.perform([request]),
              let observations = request.results, !observations.isEmpty else {
            return TextDetectionResult(summary: nil, charCount: 0, hasFinancialOrDocKeywords: false)
        }
        
        var fullText = ""
        for obs in observations.prefix(15) {
            if let candidate = obs.topCandidates(1).first?.string {
                fullText += candidate + " "
            }
        }
        
        let count = fullText.count
        let lower = fullText.lowercased()
        let keywords = [
            "total", "subtotal", "tax", "kdv", "fatura", "receipt", "tutar",
            "date", "tarih", "iban", "tl", "eur", "usd", "summe", "rechnung", "mwst",
            "montant", "facture", "cash", "credit", "visa", "mastercard"
        ]
        let hasKeywords = keywords.contains { lower.contains($0) }
        
        let summary = count > 0 ? String(fullText.prefix(120)).trimmingCharacters(in: .whitespacesAndNewlines) : nil
        return TextDetectionResult(summary: summary, charCount: count, hasFinancialOrDocKeywords: hasKeywords)
    }
    
    private static func classifyImage(image: CGImage) -> (categories: [(category: PhotoCategory, confidence: Float)], tags: [String]) {
        let request = VNClassifyImageRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        
        guard let _ = try? handler.perform([request]),
              let observations = request.results else {
            return ([], [])
        }
        
        var categoryScores: [PhotoCategory: Float] = [:]
        var tags: [String] = []
        
        for obs in observations where obs.confidence > 0.3 {
            let id = obs.identifier.lowercased()
            tags.append(id)
            
            if id.contains("animal") || id.contains("dog") || id.contains("cat") || id.contains("pet") || id.contains("bird") {
                categoryScores[.animalsPets, default: 0] += obs.confidence
            } else if id.contains("plant") || id.contains("tree") || id.contains("flower") || id.contains("sky") ||
                        id.contains("water") || id.contains("mountain") || id.contains("landscape") || id.contains("nature") {
                categoryScores[.natureLandscape, default: 0] += obs.confidence
            } else if id.contains("person") || id.contains("face") || id.contains("human") || id.contains("portrait") || id.contains("crowd") {
                categoryScores[.peoplePortrait, default: 0] += obs.confidence
            } else if id.contains("food") || id.contains("drink") || id.contains("meal") || id.contains("fruit") || id.contains("dessert") {
                categoryScores[.foodDrink, default: 0] += obs.confidence
            } else if id.contains("building") || id.contains("architecture") || id.contains("city") || id.contains("house") || id.contains("tower") {
                categoryScores[.architectureCity, default: 0] += obs.confidence
            } else if id.contains("document") || id.contains("receipt") || id.contains("paper") || id.contains("text") || id.contains("menu") {
                categoryScores[.documentsReceipts, default: 0] += obs.confidence
            } else if id.contains("screen") || id.contains("display") || id.contains("monitor") {
                categoryScores[.screenshotsGraphics, default: 0] += obs.confidence
            } else if id.contains("car") || id.contains("vehicle") || id.contains("airplane") || id.contains("train") || id.contains("boat") {
                categoryScores[.vehiclesTransport, default: 0] += obs.confidence
            }
        }
        
        let sorted = categoryScores.map { ($0.key, min(1.0, $0.value)) }.sorted { $0.1 > $1.1 }
        return (sorted, Array(tags.prefix(8)))
    }
    
    private static func evaluateScreenshot(asset: UniversalMediaAsset, image: CGImage, textCount: Int) -> Bool {
        let name = asset.displayName.lowercased()
        if name.contains("screenshot") || name.contains("screen shot") || name.contains("ekran resmi") || name.contains("capture d'écran") || name.contains("bildschirmfoto") {
            return true
        }
        
        // Exact Apple screen aspect ratios (iPhone, iPad, MacBook)
        let w = Float(image.width)
        let h = Float(max(image.height, 1))
        let ratio = max(w, h) / min(w, h)
        
        // Common phone & tablet ratios: 19.5:9 (~2.16), 16:9 (~1.77), 16:10 (~1.60), 4:3 (~1.33)
        let isScreenRatio = (abs(ratio - 2.16) < 0.05) || (abs(ratio - 1.77) < 0.03) || (abs(ratio - 1.60) < 0.03)
        let isPng = name.hasSuffix(".png")
        
        if isPng && isScreenRatio && textCount > 20 {
            return true
        }
        return false
    }
}
