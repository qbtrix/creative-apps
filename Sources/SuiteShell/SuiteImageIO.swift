// SuiteImageIO.swift: the suite's one ImageIO adapter (shared-codecs rule 20).
// No other file under Sources/ imports ImageIO (ImageIOImportRatchetTests).
// Shell-media lands the first calls here: a still read upright at a size,
// one image encoded as a registry format, and frames written as an animated
// GIF or APNG. Shared-codecs'
// SC-2 and SC-4 add decoding, file info and the CoreRaster paths beside them.
// Export-pack's XP-7 adds the metadata calls StillMetadata makes.
// Formats come from SuiteImageFormats, so this file spells out no list of its own.
import CoreGraphics
import CoreRaster
import Foundation
import ImageIO
import SuiteModel

public enum SuiteImageIO {
    // MARK: Decoding, file info and the CoreRaster paths (shared-codecs SC-2 stubs; SC-4 gives them bodies)

    /// A file's facts read without decoding its pixels: the size already
    /// oriented, the Exif orientation (1 to 8), the capture date and the raw
    /// Exif and TIFF dictionaries.
    public struct Info: Sendable {
        public var width, height: Int
        public var orientation: Int
        public var captureDate: Date?
        public var exif, tiff: [String: any Sendable]

        public init(width: Int, height: Int, orientation: Int, captureDate: Date?,
                    exif: [String: any Sendable], tiff: [String: any Sendable]) {
            self.width = width; self.height = height; self.orientation = orientation
            self.captureDate = captureDate; self.exif = exif; self.tiff = tiff
        }
    }

    /// What `encode(_:as:)` writes: PNG and JPEG through CoreRaster, HEIC
    /// and TIFF through ImageIO.
    public enum Format: Sendable { case png, jpeg(quality: Double), heic(quality: Double), tiff(bitDepth: Int) }

    /// The registry's formats this Mac's ImageIO reads. Empty until SC-4
    /// asks `CGImageSourceCopyTypeIdentifiers`: `decode` reads nothing yet.
    public static var readable: Set<SuiteImageFormat> { [] }

    /// The registry's formats this Mac's ImageIO writes. Empty until SC-4
    /// asks `CGImageDestinationCopyTypeIdentifiers`: `encode` writes nothing
    /// yet, so no panel may offer a format through it.
    public static var writable: Set<SuiteImageFormat> { [] }

    /// The file's facts without decoding pixels. Not built yet: throws.
    public static func info(_ url: URL) throws -> Info {
        throw notBuilt("Reading \(url.lastPathComponent)'s image info")
    }

    /// Pixels, oriented, as CoreRaster's premultiplied linear buffer;
    /// `longestSide` shrinks while decoding. Not built yet: throws.
    public static func decode(_ data: Data, longestSide: Int?) throws -> PixelBuffer {
        throw notBuilt("Decoding an image into pixels")
    }

    /// `buffer` as a complete `format` file. Not built yet: throws. SC-4
    /// adds the output colour profile (default sRGB) with its body.
    public static func encode(_ buffer: PixelBuffer, as format: Format) throws -> Data {
        throw notBuilt("Encoding pixels as an image file")
    }

    /// For the CoreGraphics rasterizers: the image as PNG through CoreRaster.
    /// Not built yet: throws.
    public static func png(_ image: CGImage) throws -> Data {
        throw notBuilt("Encoding a PNG through CoreRaster")
    }

    private static func notBuilt(_ what: String) -> SuiteError {
        .notAvailable("\(what) isn't built yet (shared-codecs SC-4).")
    }

    // MARK: Shell-media's calls (SM-6, SM-7)

    /// The first image in `data`, turned upright by its EXIF orientation and
    /// shrunk so its longer side is at most `longestSide` (never enlarged);
    /// nil keeps the stored size.
    public static func uprightImage(_ data: Data, longestSide: Int?) throws(SuiteError) -> CGImage {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
            let stored = storedLongestSide(source)
        else { throw .readFailed("This isn't an image the Mac can read.") }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: min(longestSide ?? stored, stored),
        ]
        guard let upright = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            throw .readFailed("The still couldn't be decoded.")
        }
        return upright
    }

    /// The longer of the stored pixel width and height, before any orientation.
    static func storedLongestSide(_ source: CGImageSource) -> Int? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width > 0, height > 0
        else { return nil }
        return max(width, height)
    }

    /// `image` as a complete `format` file; `quality` (0 to 1, clamped) sets
    /// lossy compression, nil leaves the format lossless.
    public static func encode(_ image: CGImage, as format: SuiteImageFormat, quality: Double?) throws(SuiteError) -> Data {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData, format.typeID.rawValue as CFString, 1, nil)
        else { throw .notAvailable("This Mac can't write \(format.title) images.") }
        var properties: [CFString: Any] = [:]
        if let quality { properties[kCGImageDestinationLossyCompressionQuality] = min(max(quality, 0), 1) }
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw .ioFailed("the \(format.title) image couldn't be encoded")
        }
        return data as Data
    }

    // MARK: Export-pack's metadata calls (XP-7, for Media/StillMetadata.swift)

    /// The first image's properties: top-level values (`Orientation`, `ProfileName`, ...) and the `{Exif}`,
    /// `{TIFF}`, `{GPS}` and other dictionaries, keyed as ImageIO names them.
    public static func properties(_ data: Data) throws(SuiteError) -> [String: Any] {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil), CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [String: Any]
        else { throw .readFailed("this image's metadata") }
        return properties
    }

    /// `still` with `source`'s metadata tags for exactly the `kept` properties (`("{Exif}", "DateTimeOriginal")`)
    /// as its only metadata, its compressed pixels copied as they are (`CGImageDestinationCopyImageSource`).
    /// Nil when either can't be read or the still's format can't be copied this way.
    public static func copyingTags(_ still: Data, from source: Data, keeping kept: [(dictionary: String, key: String)]) -> Data? {
        guard let image = CGImageSourceCreateWithData(still as CFData, nil), let type = CGImageSourceGetType(image),
            let origin = CGImageSourceCreateWithData(source as CFData, nil),
            let tags = CGImageSourceCopyMetadataAtIndex(origin, 0, nil)
        else { return nil }
        let metadata = CGImageMetadataCreateMutable()
        for (dictionary, key) in kept {
            guard let tag = CGImageMetadataCopyTagMatchingImageProperty(tags, dictionary as CFString, key as CFString),
                let prefix = CGImageMetadataTagCopyPrefix(tag), let name = CGImageMetadataTagCopyName(tag)
            else { continue }
            CGImageMetadataSetTagWithPath(metadata, nil, "\(prefix as String):\(name as String)" as CFString, tag)
        }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, type, 1, nil) else { return nil }
        let options: [CFString: Any] = [kCGImageDestinationMetadata: metadata, kCGImageDestinationMergeMetadata: false]
        // CopyImageSource writes the destination itself: no Finalize after it.
        guard CGImageDestinationCopyImageSource(destination, image, options as CFDictionary, nil) else { return nil }
        return data as Data
    }

    /// `still` encoded again in its own format at full quality with `properties` (the `{Exif}`-style
    /// dictionaries and `Orientation`) added to its own: the route for a still `copyingTags` can't copy.
    public static func reencoding(_ still: Data, properties: [String: Any]) throws(SuiteError) -> Data {
        guard let image = CGImageSourceCreateWithData(still as CFData, nil), CGImageSourceGetCount(image) > 0,
            let type = CGImageSourceGetType(image)
        else { throw .readFailed("the still") }
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data as CFMutableData, type, 1, nil) else {
            throw .notAvailable("This Mac can't write this still's format.")
        }
        var all = properties
        all[kCGImageDestinationLossyCompressionQuality as String] = 1.0
        CGImageDestinationAddImageFromSource(destination, image, 0, all as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw .ioFailed("the still's metadata couldn't be written") }
        return data as Data
    }

    /// `frames` as a GIF at `url`: `loopCount` (0 loops forever) and each
    /// frame's delay in seconds, `delays[i]` for `frames[i]`.
    public static func writeGIF(_ frames: [CGImage], delays: [Double], loopCount: Int, to url: URL) throws(SuiteError) {
        try write(frames, as: SuiteImageFormat.gif, to: url,
                  file: [kCGImagePropertyGIFDictionary: [kCGImagePropertyGIFLoopCount: loopCount]]) { index in
            let delay = delays.indices.contains(index) ? delays[index] : 0
            return [kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFDelayTime: delay, kCGImagePropertyGIFUnclampedDelayTime: delay,
            ]]
        }
    }

    /// `frames` as an APNG at `url`, with the same loop count and delays.
    public static func writeAPNG(_ frames: [CGImage], delays: [Double], loopCount: Int, to url: URL) throws(SuiteError) {
        try write(frames, as: SuiteImageFormat.png, to: url,
                  file: [kCGImagePropertyPNGDictionary: [kCGImagePropertyAPNGLoopCount: loopCount]]) { index in
            let delay = delays.indices.contains(index) ? delays[index] : 0
            return [kCGImagePropertyPNGDictionary: [
                kCGImagePropertyAPNGDelayTime: delay, kCGImagePropertyAPNGUnclampedDelayTime: delay,
            ]]
        }
    }

    /// One destination for every frame: it needs the count when it is made.
    /// A failed write deletes what it wrote.
    private static func write(
        _ frames: [CGImage], as format: SuiteImageFormat, to url: URL, file: [CFString: Any],
        frame: (Int) -> [CFString: Any]
    ) throws(SuiteError) {
        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL, format.typeID.rawValue as CFString, frames.count, nil)
        else { throw .ioFailed("\(url.lastPathComponent) couldn't be created") }
        CGImageDestinationSetProperties(destination, file as CFDictionary)
        for (index, image) in frames.enumerated() {
            CGImageDestinationAddImage(destination, image, frame(index) as CFDictionary)
        }
        guard CGImageDestinationFinalize(destination) else {
            try? FileManager.default.removeItem(at: url)
            throw .ioFailed("\(url.lastPathComponent) couldn't be written")
        }
    }
}
