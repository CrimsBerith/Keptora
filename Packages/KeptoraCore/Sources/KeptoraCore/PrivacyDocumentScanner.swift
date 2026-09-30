@preconcurrency import Vision
import CoreGraphics
import Foundation

/// Types of sensitive documents detected in user photos.
public enum SensitiveDocumentKind: String, Codable, Sendable, CaseIterable {
    case identityOrPassport = "identity_or_passport"
    case paymentCardOrIban = "payment_card_or_iban"
    case medicalOrConfidential = "medical_or_confidential"
    case credentialsOrPassword = "credentials_or_password"
    
    public var title: String {
        switch self {
        case .identityOrPassport: return String(localized: "ID Card / Passport")
        case .paymentCardOrIban: return String(localized: "Payment Card / IBAN")
        case .medicalOrConfidential: return String(localized: "Medical / Confidential Record")
        case .credentialsOrPassword: return String(localized: "Password / Credentials")
        }
    }
    
    public var iconName: String {
        switch self {
        case .identityOrPassport: return "person.text.rectangle.fill"
        case .paymentCardOrIban: return "creditcard.fill"
        case .medicalOrConfidential: return "cross.case.fill"
        case .credentialsOrPassword: return "key.fill"
        }
    }
}

public struct PrivacyAuditReport: Identifiable, Codable, Sendable, Hashable {
    public let id: String
    public let assetID: String
    public let kinds: [SensitiveDocumentKind]
    public let redactedSnippet: String
    public let detectedAt: Date
    
    public init(
        id: String,
        assetID: String,
        kinds: [SensitiveDocumentKind],
        redactedSnippet: String,
        detectedAt: Date = Date()
    ) {
        self.id = id
        self.assetID = assetID
        self.kinds = kinds
        self.redactedSnippet = redactedSnippet
        self.detectedAt = detectedAt
    }
}

/// On-device privacy auditor that scans photos for forgotten IDs, bank cards, and credentials.
public enum PrivacyDocumentScanner: Sendable {
    
    public static func scan(image: CGImage, assetID: String) -> PrivacyAuditReport? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        guard let _ = try? handler.perform([request]),
              let observations = request.results, !observations.isEmpty else {
            return nil
        }
        
        var recognizedLines: [String] = []
        for obs in observations {
            if let str = obs.topCandidates(1).first?.string {
                recognizedLines.append(str)
            }
        }
        
        let fullText = recognizedLines.joined(separator: " ")
        let lower = fullText.lowercased()
        
        var kinds: Set<SensitiveDocumentKind> = []
        
        // 1. Credit Cards & IBANs
        let ibanPattern = #"[A-Z]{2}[0-9]{2}[A-Z0-9]{4}[0-9]{7}([A-Z0-9]?){0,16}"#
        let cardPattern = #"\b(?:4[0-9]{12}(?:[0-9]{3})?|5[1-5][0-9]{14}|6(?:011|5[0-9][0-9])[0-9]{12}|3[47][0-9]{13})\b"#
        
        if fullText.range(of: ibanPattern, options: .regularExpression) != nil ||
           fullText.range(of: cardPattern, options: .regularExpression) != nil ||
           lower.contains("cvv") || lower.contains("valid thru") || lower.contains("iban") {
            kinds.insert(.paymentCardOrIban)
        }
        
        // 2. ID, Passport, Driver's License
        let idKeywords = [
            "passport", "pasaport", "kimlik", "identity card", "driver license",
            "sürücü belgesi", "national id", "t.c.", "personalausweis", "carte d'identité"
        ]
        if idKeywords.contains(where: { lower.contains($0) }) {
            kinds.insert(.identityOrPassport)
        }
        
        // 3. Credentials & Passwords
        let passKeywords = [
            "password", "parola", "şifre", "kennwort", "mot de passe",
            "secret key", "recovery phrase", "private key"
        ]
        if passKeywords.contains(where: { lower.contains($0) }) {
            kinds.insert(.credentialsOrPassword)
        }
        
        guard !kinds.isEmpty else { return nil }
        
        return PrivacyAuditReport(
            id: "privacy:\(assetID)",
            assetID: assetID,
            kinds: Array(kinds),
            redactedSnippet: "[REDACTED SENSITIVE DOCUMENT: \(kinds.map(\.rawValue).joined(separator: ", "))]"
        )
    }
}
