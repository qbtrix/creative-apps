// SuiteImageIO.swift: the suite's one ImageIO adapter (shared-codecs rule 20).
// No other file under Sources/ imports ImageIO (ImageIOImportRatchetTests).
// Shell-media's calls read a still upright at a size, encode one image as a
// registry format and write frames as an animated GIF or APNG. Shared-codecs'
// SC-4 adds the CoreRaster paths: file info, decoding into SuiteImaging's
// working space (PNG and JPEG by core, everything else by ImageIO) and
// encoding from it (PNG and JPEG by core, HEIC and TIFF by ImageIO).
// Export-pack's XP-7 adds the metadata calls StillMetadata makes.
// Formats come from SuiteImageFormats, so this file spells out no list of its own.
import CoreColor
import CoreGraphics
import CoreRaster
import Foundation
import ImageIO
import SuiteImaging
import SuiteModel

public enum SuiteImageIO {
    // MARK: Decoding, file info and the CoreRaster paths (shared-codecs SC-4)

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

    /// What `encode(_:as:profile:)` writes: PNG and JPEG through CoreRaster,
    /// HEIC and TIFF through ImageIO.
    public enum Format: Sendable { case png, jpeg(quality: Double), heic(quality: Double), tiff(bitDepth: Int) }

    /// The registry's formats this Mac's ImageIO reads.
    public static var readable: Set<SuiteImageFormat> { registry(in: CGImageSourceCopyTypeIdentifiers()) }

    /// The registry's writable formats this Mac's ImageIO also writes, so no
    /// panel offers one nothing here encodes.
    public static var writable: Set<SuiteImageFormat> {
        registry(in: CGImageDestinationCopyTypeIdentifiers()).filter { !$0.writeBitDepths.isEmpty }
    }

    private static func registry(in identifiers: CFArray) -> Set<SuiteImageFormat> {
        let known = Set((identifiers as? [String]) ?? [])
        return Set(SuiteImageFormats.all.filter { known.contains($0.typeID.rawValue) })
    }

    /// The file's facts without decoding pixels; the size is the upright one.
    public static func info(_ url: URL) throws -> Info {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int, width > 0, height > 0
        else { throw SuiteError.readFailed("\(url.lastPathComponent) isn't an image the Mac can read.") }
        let orientation = orientation(of: properties)
        let exif = properties[kCGImagePropertyExifDictionary] as? [String: Any] ?? [:]
        let tiff = properties[kCGImagePropertyTIFFDictionary] as? [String: Any] ?? [:]
        let quarter = (5...8).contains(orientation)
        return Info(width: quarter ? height : width, height: quarter ? width : height, orientation: orientation,
                    captureDate: captureDate(exif), exif: exif.compactMapValues(sendable),
                    tiff: tiff.compactMapValues(sendable))
    }

    /// The Exif orientation, 1 when it is missing or out of range.
    static func orientation(of properties: [CFString: Any]) -> Int {
        let value = properties[kCGImagePropertyOrientation] as? Int ?? 1
        return (1...8).contains(value) ? value : 1
    }

    /// Exif's "yyyy:MM:dd HH:mm:ss" capture time, with its "+hh:mm" offset when the file has one, else in the
    /// current time zone.
    static func captureDate(_ exif: [String: Any]) -> Date? {
        guard let original = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String else { return nil }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        if let zone = exif[kCGImagePropertyExifOffsetTimeOriginal as String] as? String {
            formatter.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
            if let date = formatter.date(from: original + zone) { return date }
        }
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        return formatter.date(from: original)
    }

    /// A property value as plain Sendable values: strings, numbers and arrays or dictionaries of them.
    static func sendable(_ value: Any) -> (any Sendable)? {
        switch value {
        case let text as String: return text
        case let number as NSNumber: return number
        case let list as [Any]: return list.compactMap(sendable)
        case let table as [String: Any]: return table.compactMapValues(sendable)
        default: return nil
        }
    }

    /// Pixels, oriented, in SuiteImaging's working space as CoreRaster's
    /// premultiplied buffer; `longestSide` shrinks while decoding. PNG and
    /// JPEG are read by CoreRaster from the file's own ICC profile (none or
    /// one core can't use means sRGB); everything else by ImageIO into an
    /// extended-range linear sRGB Float32 context, so 16-bit and float
    /// sources keep their depth and nothing is cut at 1.
    public static func decode(_ data: Data, longestSide: Int?) throws -> PixelBuffer {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw SuiteError.readFailed("This isn't an image the Mac can read.")
        }
        if data.starts(with: [137, 80, 78, 71]) || data.starts(with: [0xFF, 0xD8, 0xFF]) {
            let icc = CGImageSourceCreateImageAtIndex(source, 0, nil)?.colorSpace?.copyICCData()
            let profile = icc.flatMap { try? ColorProfile(iccData: $0 as Data) } ?? .sRGB
            let stored: PixelBuffer
            if data.starts(with: [0xFF, 0xD8]) {
                stored = upright(try JPEG.read(data), try JPEG.info(data).orientation)
            } else {
                stored = try PNG.read(data)
            }
            return try ImagingColor.toWorking(try shrunk(stored, to: longestSide), from: profile)
        }
        guard CGImageSourceGetCount(source) > 0,
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let stored = storedLongestSide(source)
        else { throw SuiteError.readFailed("This isn't an image the Mac can read.") }
        let image: CGImage?
        var orientation = orientation(of: properties)
        if let side = longestSide, side > 0, side < stored {
            image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true, kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldAllowFloat: true, kCGImageSourceThumbnailMaxPixelSize: side,
            ] as CFDictionary)
            orientation = 1
        } else {
            image = CGImageSourceCreateImageAtIndex(source, 0, [kCGImageSourceShouldAllowFloat: true] as CFDictionary)
        }
        guard let image else { throw SuiteError.readFailed("The image couldn't be decoded.") }
        return try ImagingColor.toWorking(upright(try working(image), orientation), from: ImagingColor.workingProfile)
    }

    /// The quarter turn, then the mirror, that shows a stored picture with Exif `orientation` upright.
    private static let turns: [Int: QuarterTurn] = [3: .degrees180, 5: .degrees90, 6: .degrees90, 7: .degrees270,
                                                    8: .degrees270]

    static func upright(_ stored: PixelBuffer, _ orientation: Int) -> PixelBuffer {
        let turned = turns[orientation].map { stored.rotated($0) } ?? stored
        switch orientation {
        case 2, 5, 7: return turned.flipped(.horizontal)
        case 4: return turned.flipped(.vertical)
        default: return turned
        }
    }

    /// `buffer` with its longer side at most `side` (never enlarged), bilinear.
    static func shrunk(_ buffer: PixelBuffer, to side: Int?) throws -> PixelBuffer {
        let longest = max(buffer.width, buffer.height)
        guard let side, side > 0, longest > side else { return buffer }
        let scale = Double(side) / Double(longest)
        return try buffer.resized(width: max(Int((Double(buffer.width) * scale).rounded()), 1),
                                  height: max(Int((Double(buffer.height) * scale).rounded()), 1), filter: .bilinear)
    }

    /// 128-bit RGBA: 32-bit float components, little-endian (every Mac's host order), alpha last, premultiplied.
    private static let floatInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue
        | CGBitmapInfo.floatComponents.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)

    /// `image` drawn into an extended-range linear sRGB Float32 context (Core Graphics converts from the
    /// image's own profile, keeping colours outside sRGB and values above 1) as a premultiplied buffer.
    static func working(_ image: CGImage) throws -> PixelBuffer {
        let width = image.width, height = image.height
        var out = try PixelBuffer(width: width, height: height)
        var floats = [Float](repeating: 0, count: width * height * 4)
        let drawn = floats.withUnsafeMutableBytes { raw -> Bool in
            guard let space = CGColorSpace(name: CGColorSpace.extendedLinearSRGB),
                let context = CGContext(
                    data: raw.baseAddress, width: width, height: height, bitsPerComponent: 32,
                    bytesPerRow: width * 4 * MemoryLayout<Float>.size, space: space, bitmapInfo: floatInfo.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { throw SuiteError.readFailed("The image couldn't be decoded.") }
        // The bitmap's first row in memory is the top row, as PixelBuffer's.
        for y in 0..<height {
            for x in 0..<width {
                let i = (y * width + x) * 4
                guard i + 3 < floats.count else { continue }
                try out.setPixel(x: x, y: y, RGBA(r: floats[i], g: floats[i + 1], b: floats[i + 2], a: floats[i + 3]))
            }
        }
        return out
    }

    /// `buffer` (working space) as a complete `format` file in `profile`. PNG and JPEG in sRGB are core's
    /// `PNG.write` and `JPEG.write`; HEIC, TIFF, and PNG or JPEG in another profile go through
    /// `ImagingColor.toOutput` to `profile` at the format's depth (16 bits for `.tiff(bitDepth: 16)`) and
    /// `CGImageDestination`, which embeds the profile's ICC bytes.
    public static func encode(_ buffer: PixelBuffer, as format: Format, profile: ColorProfile = .sRGB) throws -> Data {
        switch format {
        case .png where profile == .sRGB: return try PNG.write(buffer)
        case .jpeg(let quality) where profile == .sRGB:
            return try JPEG.write(buffer, quality: min(max(Int((quality * 100).rounded()), 1), 100))
        case .png: return try encode(try image(of: buffer, profile: profile, depth: .eight), as: .png, quality: nil)
        case .jpeg(let quality):
            return try encode(try image(of: buffer, profile: profile, depth: .eight), as: .jpeg, quality: quality)
        case .heic(let quality):
            return try encode(try image(of: buffer, profile: profile, depth: .eight), as: .heic, quality: quality)
        case .tiff(let bits):
            return try encode(try image(of: buffer, profile: profile, depth: bits > 8 ? .sixteen : .eight),
                              as: .tiff, quality: nil)
        }
    }

    /// `buffer` taken to `profile` at `depth` as a straight-alpha CGImage tagged with that profile. 16-bit
    /// samples are big-endian, Core Graphics' default byte order.
    static func image(of buffer: PixelBuffer, profile: ColorProfile, depth: ImagingBitDepth) throws -> CGImage {
        let output = try ImagingColor.toOutput(buffer, profile: profile, bitDepth: depth)
        let bytes: [UInt8] = depth == .sixteen
            ? output.samples.flatMap { [UInt8($0 >> 8), UInt8($0 & 0xFF)] }
            : output.samples.map { UInt8(min($0, 255)) }
        let space = profile == .sRGB ? CGColorSpace(name: CGColorSpace.sRGB)
            : CGColorSpace(iccData: try profile.iccData() as CFData)
        let bits = depth.rawValue
        guard let space, let provider = CGDataProvider(data: Data(bytes) as CFData),
            let image = CGImage(
                width: output.width, height: output.height, bitsPerComponent: bits, bitsPerPixel: bits * 4,
                bytesPerRow: output.width * bits / 2, space: space,
                bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue), provider: provider,
                decode: nil, shouldInterpolate: true, intent: .defaultIntent)
        else { throw SuiteError.ioFailed("the image couldn't be prepared for writing") }
        return image
    }

    /// For the CoreGraphics rasterizers: the image as PNG through CoreRaster.
    public static func png(_ image: CGImage) throws -> Data {
        try PNG.write(try working(image))
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
