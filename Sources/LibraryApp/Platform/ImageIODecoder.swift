// Platform/ImageIODecoder.swift: PhotoDecoding on ImageIO and the file
// system (import IM-4). `scan` walks a folder, subfolders included, skipping
// hidden files and package contents, and reads each image-named file's
// metadata only: its pixel size after the Exif orientation and its capture
// date (Exif DateTimeOriginal with its offset when present, else the file's
// creation date). A file ImageIO can't read is a failure, never a throw.
// `decode` makes an oriented thumbnail no bigger than asked, draws it into an
// sRGB RGBA8 context (premultiplied, the only 8-bit RGBA layout CGContext
// takes) and unpremultiplies it into DisplayImage's straight alpha.
import CoreGraphics
import Foundation
import ImageIO
import LibraryModel

struct ImageIODecoder: PhotoDecoding {
    func scan(folder: String) async throws -> FolderScan { try Self.walk(folder) }

    /// The scan itself, synchronous: a directory enumerator can't be iterated
    /// from an async context.
    private static func walk(_ folder: String) throws -> FolderScan {
        let root = URL(fileURLWithPath: folder)
        let manager = FileManager.default
        let name = root.lastPathComponent
        // The enumerator reports an unreadable root only through its error
        // handler, so list it once first: that throws when it can't be read.
        guard (try? manager.contentsOfDirectory(atPath: folder)) != nil else {
            throw LibraryError.unreadableFolder(name)
        }
        let keys: [URLResourceKey] = [.isRegularFileKey, .creationDateKey]
        guard let entries = manager.enumerator(
            at: root, includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants], errorHandler: { _, _ in true })
        else { throw LibraryError.unreadableFolder(name) }
        let dates = ExifDates()
        var candidates: [ImportCandidate] = []
        var failures: [FileFailure] = []
        for case let url as URL in entries {
            guard let kind = PhotoFileKind.kind(forFileName: url.lastPathComponent),
                let values = try? url.resourceValues(forKeys: Set(keys)), values.isRegularFile == true
            else { continue }
            guard let info = metadata(of: url) else {
                failures.append(FileFailure(path: url.path, reason: LibraryError.notAnImage(url.path).message))
                continue
            }
            let date = dates.captureDate(info.exif) ?? values.creationDate ?? Date(timeIntervalSince1970: 0)
            candidates.append(ImportCandidate(path: url.path, captureDate: date, pixelSize: info.size, kind: kind))
        }
        return FolderScan(candidates: candidates, failures: failures)
    }

    func decode(path: String, maxLongSide: Int?) async throws -> DisplayImage {
        guard FileManager.default.fileExists(atPath: path) else { throw LibraryError.missingFile(path) }
        let url = URL(fileURLWithPath: path)
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil), let info = Self.metadata(of: url) else {
            throw LibraryError.notAnImage(path)
        }
        let full = info.size.longSide
        let limit = max(min(maxLongSide ?? full, full), 1)
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: limit,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary),
            let pixels = Self.straightRGBA8(image)
        else { throw LibraryError.notAnImage(path) }
        return pixels
    }

    /// The upright pixel size and the Exif dictionary of the file's first image;
    /// nil when ImageIO can't read it as an image.
    private static func metadata(of url: URL) -> (size: PixelSize, exif: [CFString: Any])? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
            let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
            let width = properties[kCGImagePropertyPixelWidth] as? Int,
            let height = properties[kCGImagePropertyPixelHeight] as? Int,
            width >= 1, height >= 1
        else { return nil }
        // Orientations 5 through 8 turn the image a quarter, so its sides swap.
        let orientation = properties[kCGImagePropertyOrientation] as? Int ?? 1
        let size = (5...8).contains(orientation)
            ? PixelSize(width: height, height: width) : PixelSize(width: width, height: height)
        return (size, properties[kCGImagePropertyExifDictionary] as? [CFString: Any] ?? [:])
    }

    /// `image` as sRGB straight-alpha RGBA8, top row first; nil when it can't be drawn.
    private static func straightRGBA8(_ image: CGImage) -> DisplayImage? {
        let width = image.width
        let height = image.height
        guard width >= 1, height >= 1, let space = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        guard drawn else { return nil }
        for pixel in stride(from: 0, to: bytes.count, by: 4) {
            let alpha = Int(bytes[pixel + 3])
            guard alpha > 0, alpha < 255 else { continue }
            for channel in pixel..<(pixel + 3) {
                bytes[channel] = UInt8(min((Int(bytes[channel]) * 255 + alpha / 2) / alpha, 255))
            }
        }
        return DisplayImage(size: PixelSize(width: width, height: height), rgba8: bytes)
    }
}

/// Reads Exif's "yyyy:MM:dd HH:mm:ss" capture time, with its "+hh:mm" offset
/// when the file has one, else in the current time zone.
private struct ExifDates {
    private let local: DateFormatter
    private let offset: DateFormatter

    init() {
        local = DateFormatter()
        local.locale = Locale(identifier: "en_US_POSIX")
        local.timeZone = TimeZone.current
        local.dateFormat = "yyyy:MM:dd HH:mm:ss"
        offset = DateFormatter()
        offset.locale = Locale(identifier: "en_US_POSIX")
        offset.dateFormat = "yyyy:MM:dd HH:mm:ssxxx"
    }

    func captureDate(_ exif: [CFString: Any]) -> Date? {
        guard let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String else { return nil }
        if let zone = exif[kCGImagePropertyExifOffsetTimeOriginal] as? String,
            let date = offset.date(from: original + zone) {
            return date
        }
        return local.date(from: original)
    }
}
