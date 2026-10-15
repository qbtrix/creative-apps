// LibraryJourneyTests+Files.swift: the shared Library journey helpers
// (blueprint 4.1, "Shared Library helpers"; packet
// docs/blueprints/library/features/spine.md, SJ-2). Live (L) journeys write
// real files through ImageIO in the test process and launch on them:
// `freshCatalogDir()` is every journey's empty `-LibraryCatalogDir`,
// `writeShoot(in:)` writes the `shoot` fixture's 24 photos as JPEGs with the
// same names, pixel sizes and Exif capture dates, `write(_:kinds:in:subfolder:)`
// writes plain files of each kind, `broken(in:)` a `.jpg` that isn't an image,
// and `readOnlyFolder()` / `unreadableFolder()` the folders export and import
// fail on. Each image is one flat color, so even 6000 × 4000 stays a small
// file. LibraryFilesSmokeTests checks the helpers write what they say.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers
import XCTest

enum LibraryFiles {
    /// The image formats `write(_:kinds:in:subfolder:)` writes.
    enum Kind: CaseIterable {
        case jpeg, png, heic

        var type: UTType {
            switch self {
            case .jpeg: .jpeg
            case .png: .png
            case .heic: .heic
            }
        }

        var fileExtension: String {
            switch self {
            case .jpeg: "jpg"
            case .png: "png"
            case .heic: "heic"
            }
        }
    }

    struct WriteError: Error, CustomStringConvertible {
        let description: String
    }

    /// A new, empty temporary folder: a different one on every call.
    static func freshCatalogDir() throws -> URL {
        try folder("library-catalog")
    }

    /// The `shoot` fixture's photos: IMG_0001.jpg … IMG_0024.jpg, every third
    /// one portrait 4000 × 6000 and the rest landscape 6000 × 4000, IMG_n
    /// captured 2026-06-01 10:00 UTC plus (7 · n) mod 24 minutes.
    @discardableResult
    static func writeShoot(in folder: URL) throws -> [URL] {
        try (1...24).map { n in
            let (width, height) = n % 3 == 0 ? (4000, 6000) : (6000, 4000)
            let url = folder.appending(path: String(format: "IMG_%04d.jpg", n))
            try writeImage(
                to: url, kind: .jpeg, width: width, height: height, shade: n,
                captured: exifDate(minutesAfterTen: (7 * n) % 24, day: "2026:06:01"))
            return url
        }
    }

    /// `count` small images of each of `kinds` in `folder` (or its
    /// `subfolder`, made if missing), named `<kind>-<n>` after any already
    /// there, each a minute later than the one before from 2026-05-01 10:00.
    @discardableResult
    static func write(_ count: Int, kinds: [Kind] = [.jpeg], in folder: URL, subfolder: String? = nil) throws -> [URL] {
        let target = subfolder.map { folder.appending(path: $0, directoryHint: .isDirectory) } ?? folder
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        var urls: [URL] = []
        for kind in kinds {
            let existing = (try? FileManager.default.contentsOfDirectory(atPath: target.path))?
                .filter { $0.hasSuffix(".\(kind.fileExtension)") }.count ?? 0
            for n in existing + 1 ..< existing + 1 + max(count, 0) {
                let url = target.appending(path: "\(kind)-\(String(format: "%04d", n)).\(kind.fileExtension)")
                try writeImage(
                    to: url, kind: kind, width: 640, height: 480, shade: n,
                    captured: exifDate(minutesAfterTen: n, day: "2026:05:01"))
                urls.append(url)
            }
        }
        return urls
    }

    /// `broken.jpg` in `folder`, holding the bytes `not an image`.
    @discardableResult
    static func broken(in folder: URL) throws -> URL {
        let url = folder.appending(path: "broken.jpg")
        try Data("not an image".utf8).write(to: url)
        return url
    }

    /// A new folder that can be listed but not written (mode 555): exports into it fail.
    static func readOnlyFolder() throws -> URL {
        let url = try folder("library-read-only")
        try FileManager.default.setAttributes([.posixPermissions: 0o555], ofItemAtPath: url.path)
        return url
    }

    /// A new folder that can't be listed (mode 000), holding one photo: imports from it fail.
    static func unreadableFolder() throws -> URL {
        let url = try folder("library-unreadable")
        try write(1, in: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        return url
    }

    // MARK: - Writing

    private static func folder(_ prefix: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appending(path: "\(prefix)-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// An Exif DateTimeOriginal ("yyyy:MM:dd HH:mm:ss") `minutes` after 10:00 on `day`.
    private static func exifDate(minutesAfterTen minutes: Int, day: String) -> String {
        day + String(format: " %02d:%02d:00", 10 + minutes / 60, minutes % 60)
    }

    /// One flat-colored `width` × `height` image of `kind` at `url`, its
    /// shade set by `shade`, with `captured` as its Exif DateTimeOriginal (UTC).
    private static func writeImage(
        to url: URL, kind: Kind, width: Int, height: Int, shade: Int, captured: String
    ) throws {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
            let context = CGContext(
                data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
        else { throw WriteError(description: "no \(width) × \(height) context for \(url.lastPathComponent)") }
        let level = CGFloat(shade % 24) / 24
        context.setFillColor(red: 0.2 + level * 0.6, green: 0.5, blue: 0.8 - level * 0.6, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        guard let image = context.makeImage(),
            let destination = CGImageDestinationCreateWithURL(url as CFURL, kind.type.identifier as CFString, 1, nil)
        else { throw WriteError(description: "can't write \(kind) to \(url.lastPathComponent)") }
        let exif: [CFString: Any] = [
            kCGImagePropertyExifDateTimeOriginal: captured,
            kCGImagePropertyExifOffsetTimeOriginal: "+00:00",
        ]
        let properties: [CFString: Any] = [
            kCGImagePropertyExifDictionary: exif,
            kCGImageDestinationLossyCompressionQuality: 0.6,
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw WriteError(description: "couldn't finish \(url.lastPathComponent)")
        }
    }
}

/// The helpers' smoke test (SJ-2): they write real files and fresh folders.
final class LibraryFilesSmokeTests: XCTestCase {
    func testHelpersWriteRealFiles() throws {
        let folder = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { try? FileManager.default.removeItem(at: folder) }
        try LibraryFiles.writeShoot(in: folder)
        let names = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".jpg") }.sorted()
        XCTAssertEqual(names.count, 24, "writeShoot wrote \(names)")
        XCTAssertEqual(names.first, "IMG_0001.jpg")
        XCTAssertEqual(names.last, "IMG_0024.jpg")
        for name in names {
            let head = try Data(contentsOf: folder.appending(path: name)).prefix(2)
            XCTAssertEqual([UInt8](head), [0xFF, 0xD8], "\(name) doesn't start FF D8")
        }

        let first = try LibraryFiles.freshCatalogDir()
        let second = try LibraryFiles.freshCatalogDir()
        addTeardownBlock { for url in [first, second] { try? FileManager.default.removeItem(at: url) } }
        XCTAssertNotEqual(first, second, "two freshCatalogDir() calls gave the same folder")
        for url in [first, second] {
            XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: url.path), [], "\(url.path) isn't empty")
        }
    }
}
