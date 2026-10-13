@preconcurrency import ImageIO
import CoreGraphics
import Foundation

/// Comprehensive metadata extracted from an image file without loading raw pixel bytes into memory.
public struct DetailedPhotoMetadata: Codable, Sendable, Hashable {
    public let cameraMake: String?
    public let cameraModel: String?
    public let lensModel: String?
    public let focalLength: Double?        // in mm (e.g. 50.0)
    public let focalLength35mm: Double?    // 35mm equivalent
    public let fNumber: Double?            // aperture (e.g. 1.8, 2.8)
    public let exposureTime: Double?       // shutter speed in seconds (e.g. 0.001 = 1/1000s)
    public let iso: Int?                   // ISO (e.g. 100, 800)
    public let exposureBias: Double?       // EV compensation
    public let flashFired: Bool?
    public let colorSpace: String?         // sRGB, Display P3, Adobe RGB
    public let pixelWidth: Int
    public let pixelHeight: Int
    public let megapixelCount: Double
    public let captureTimeIsReliable: Bool?
    public let dateCaptured: Date?
    public let dateCapturedText: String?
    public let latitude: Double?
    public let longitude: Double?
    public let altitude: Double?
    public let orientation: Int?           // EXIF orientation (1-8)
    
    public init(
        cameraMake: String? = nil,
        cameraModel: String? = nil,
        lensModel: String? = nil,
        focalLength: Double? = nil,
        focalLength35mm: Double? = nil,
        fNumber: Double? = nil,
        exposureTime: Double? = nil,
        iso: Int? = nil,
        exposureBias: Double? = nil,
        flashFired: Bool? = nil,
        colorSpace: String? = nil,
        pixelWidth: Int = 0,
        pixelHeight: Int = 0,
        megapixelCount: Double = 0.0,
        dateCaptured: Date? = nil,
        captureTimeIsReliable: Bool = false,
        dateCapturedText: String? = nil,
        latitude: Double? = nil,
        longitude: Double? = nil,
        altitude: Double? = nil,
        orientation: Int? = nil
    ) {
        self.cameraMake = cameraMake
        self.cameraModel = cameraModel
        self.lensModel = lensModel
        self.focalLength = focalLength
        self.focalLength35mm = focalLength35mm
        self.fNumber = fNumber
        self.exposureTime = exposureTime
        self.iso = iso
        self.exposureBias = exposureBias
        self.flashFired = flashFired
        self.colorSpace = colorSpace
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
        self.megapixelCount = megapixelCount
        self.dateCaptured = dateCaptured
        self.dateCapturedText = dateCapturedText
        self.captureTimeIsReliable = captureTimeIsReliable
        self.latitude = latitude
        self.longitude = longitude
        self.altitude = altitude
        self.orientation = orientation
    }
    
    /// User-friendly formatted shutter speed string (e.g. "1/1000s" or "0.5s").
    public var formattedShutterSpeed: String? {
        guard let exp = exposureTime, exp > 0 else { return nil }
        if exp < 1.0 {
            let denominator = Int(round(1.0 / exp))
            return "1/\(denominator)s"
        } else {
            return String(format: "%.1fs", exp)
        }
    }
    
    /// User-friendly formatted aperture string (e.g. "ƒ/1.8").
    public var formattedAperture: String? {
        guard let fn = fNumber, fn > 0 else { return nil }
        return String(format: "ƒ/%.1f", fn)
    }
    
    /// User-friendly formatted focal length (e.g. "50 mm").
    public var formattedFocalLength: String? {
        guard let fl = focalLength, fl > 0 else { return nil }
        return String(format: "%.0f mm", fl)
    }
}

/// Fast, low-memory on-device photo metadata extractor using ImageIO.
public enum PhotoMetadataExtractor: Sendable {
    
    /// Extracts detailed EXIF, TIFF, and GPS metadata directly from a file URL.
    public static func extract(from fileURL: URL) -> DetailedPhotoMetadata {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else {
            return DetailedPhotoMetadata()
        }
        return extract(from: source)
    }
    
    /// Extracts detailed metadata from an existing CGImageSource.
    public static func extract(from source: CGImageSource) -> DetailedPhotoMetadata {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return DetailedPhotoMetadata()
        }
        
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any] ?? [:]
        let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:]
        let gps = properties[kCGImagePropertyGPSDictionary] as? [CFString: Any] ?? [:]
        
        let width = (properties[kCGImagePropertyPixelWidth] as? NSNumber)?.intValue ?? 0
        let height = (properties[kCGImagePropertyPixelHeight] as? NSNumber)?.intValue ?? 0
        let mp = Double(width * height) / 1_000_000.0
        
        let cameraMake = (tiff[kCGImagePropertyTIFFMake] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let cameraModel = (tiff[kCGImagePropertyTIFFModel] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        let lensModel = (exif[kCGImagePropertyExifLensModel] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let focalLength = (exif[kCGImagePropertyExifFocalLength] as? NSNumber)?.doubleValue
        let focalLength35mm = (exif[kCGImagePropertyExifFocalLenIn35mmFilm] as? NSNumber)?.doubleValue
        let fNumber = (exif[kCGImagePropertyExifFNumber] as? NSNumber)?.doubleValue
        let exposureTime = (exif[kCGImagePropertyExifExposureTime] as? NSNumber)?.doubleValue
        
        var isoValue: Int? = nil
        if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings] as? [NSNumber], let first = isoArray.first {
            isoValue = first.intValue
        } else if let singleISO = exif[kCGImagePropertyExifISOSpeedRatings] as? NSNumber {
            isoValue = singleISO.intValue
        }
        
        let exposureBias = (exif[kCGImagePropertyExifExposureBiasValue] as? NSNumber)?.doubleValue
        let flashFired = (exif[kCGImagePropertyExifFlash] as? NSNumber).map { ($0.intValue & 1) != 0 }
        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue
        
        let colorModel = properties[kCGImagePropertyColorModel] as? String
        
        // Parse date
        var dateCaptured: Date? = nil
        let dateString = (exif[kCGImagePropertyExifDateTimeOriginal] as? String) ?? (tiff[kCGImagePropertyTIFFDateTime] as? String)
        if let dateString {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            let offset = exif["OffsetTimeOriginal" as CFString] as? String
            if let offset {
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ssXXXXX"
                dateCaptured = formatter.date(from: dateString + offset)
            } else {
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                dateCaptured = formatter.date(from: dateString)
            }
        }
        
        // Parse GPS
        var lat: Double? = nil
        var lon: Double? = nil
        var alt: Double? = nil
        
        if let rawLat = (gps[kCGImagePropertyGPSLatitude] as? NSNumber)?.doubleValue,
           let latRef = gps[kCGImagePropertyGPSLatitudeRef] as? String {
            lat = latRef.uppercased() == "S" ? -abs(rawLat) : abs(rawLat)
        }
        
        if let rawLon = (gps[kCGImagePropertyGPSLongitude] as? NSNumber)?.doubleValue,
           let lonRef = gps[kCGImagePropertyGPSLongitudeRef] as? String {
            lon = lonRef.uppercased() == "W" ? -abs(rawLon) : abs(rawLon)
        }
        
        if let rawAlt = (gps[kCGImagePropertyGPSAltitude] as? NSNumber)?.doubleValue {
            let altRef = (gps[kCGImagePropertyGPSAltitudeRef] as? NSNumber)?.intValue ?? 0
            alt = altRef == 1 ? -abs(rawAlt) : abs(rawAlt)
        }
        
        return DetailedPhotoMetadata(
            cameraMake: cameraMake,
            cameraModel: cameraModel,
            lensModel: lensModel,
            focalLength: focalLength,
            focalLength35mm: focalLength35mm,
            fNumber: fNumber,
            exposureTime: exposureTime,
            iso: isoValue,
            exposureBias: exposureBias,
            flashFired: flashFired,
            colorSpace: colorModel,
            pixelWidth: width,
            pixelHeight: height,
            megapixelCount: (mp * 10).rounded() / 10.0,
            dateCaptured: dateCaptured,
            captureTimeIsReliable: dateCaptured != nil && (exif["OffsetTimeOriginal" as CFString] as? String) != nil,
            dateCapturedText: dateString,
            latitude: lat,
            longitude: lon,
            altitude: alt,
            orientation: orientation
        )
    }
}
