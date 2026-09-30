import Foundation

public enum SupportedMediaExtensions {
    public static let standardImages: Set<String> = [
        "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff", "gif", "bmp", "webp"
    ]

    public static let rawImages: Set<String> = [
        "dng", "cr2", "cr3", "nef", "arw", "raf", "orf", "rw2"
    ]

    public static let allImages: Set<String> = standardImages.union(rawImages)

    public static let videos: Set<String> = [
        "mov", "mp4", "m4v", "avi", "mkv"
    ]

    public static let sidecars: Set<String> = [
        "xmp", "aae"
    ]

    public static let allMedia: Set<String> = allImages.union(videos)
    public static let allMediaAndSidecars: Set<String> = allMedia.union(sidecars)
}
