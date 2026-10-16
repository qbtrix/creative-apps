// LibraryDecodeTests.swift: ImageIODecoder, Library's PhotoDecoding on
// ImageIO (import IM-4, QB-LIB-V6). Fixtures are written into a temp folder
// with CGImageDestination: an Exif orientation 6 JPEG scans as portrait and
// decodes upright; a Display P3 PNG decodes to sRGB within 2/255; a .jpg that
// isn't an image is a scan failure; decode fits the long side; hidden files
// and package contents are not listed. macOS only.
#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import LibraryModel
import Testing
import UniformTypeIdentifiers

@testable import LibraryApp

@Suite struct LibraryDecodeTests {
    private let decoder = ImageIODecoder()

    /// A fresh temp folder.
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "LibraryDecodeTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// An opaque RGBA8 image from `bytes` (top row first) in `space`.
    private func image(_ width: Int, _ height: Int, _ bytes: [UInt8], space: CFString = CGColorSpace.sRGB) -> CGImage? {
        var pixels = bytes
        return pixels.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let colors = CGColorSpace(name: space),
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: colors, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return nil }
            return context.makeImage()
        }
    }

    /// Writes `image` to `url` as `type`, with `properties` (orientation and the like).
    private func write(_ image: CGImage?, to url: URL, as type: UTType, properties: [CFString: Any] = [:]) throws {
        let picture = try #require(image)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, type.identifier as CFString, 1, nil))
        var options = properties
        options[kCGImageDestinationLossyCompressionQuality] = 1.0
        CGImageDestinationAddImage(destination, picture, options as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
    }

    /// The RGBA bytes of pixel (x, y), top row first.
    private func pixel(_ image: DisplayImage, _ x: Int, _ y: Int) -> [Int] {
        let start = (y * image.size.width + x) * 4
        return image.rgba8[start..<(start + 4)].map(Int.init)
    }

    private func isRed(_ rgba: [Int]) -> Bool { rgba[0] > 200 && rgba[1] < 60 && rgba[2] < 60 }

    /// Orientation 6 stores the picture turned a quarter counter-clockwise:
    /// stored row 0 is the upright right-hand column. So a marker the upright
    /// picture has top-left sits bottom-left in the stored 64 x 48 pixels.
    @Test func orientationSixScansPortraitAndDecodesUpright() async throws {
        let root = try folder()
        let (width, height) = (64, 48)
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in (height - 16)..<height {
            for x in 0..<16 {
                let at = (y * width + x) * 4
                bytes[at + 1] = 0
                bytes[at + 2] = 0
            }
        }
        let file = root.appending(path: "turned.jpg")
        try write(image(width, height, bytes), to: file, as: .jpeg, properties: [kCGImagePropertyOrientation: 6])

        let scan = try await decoder.scan(folder: root.path)
        let found = try #require(scan.candidates.first)
        #expect(scan.candidates.count == 1)
        #expect(found.pixelSize == PixelSize(width: 48, height: 64))
        #expect(found.kind == .jpeg)

        let upright = try await decoder.decode(path: file.path, maxLongSide: nil)
        #expect(upright.size == PixelSize(width: 48, height: 64))
        #expect(isRed(pixel(upright, 8, 8)))
        #expect(!isRed(pixel(upright, 39, 8)))
        #expect(!isRed(pixel(upright, 8, 55)))
        #expect(!isRed(pixel(upright, 39, 55)))
    }

    /// P3 red is outside sRGB; the conversion clips it to sRGB (255, 0, 0).
    @Test func displayP3DecodesToSRGB() async throws {
        let root = try folder()
        let file = root.appending(path: "wide.png")
        let red = Array(repeating: [UInt8]([255, 0, 0, 255]), count: 8 * 8).flatMap { $0 }
        try write(image(8, 8, red, space: CGColorSpace.displayP3), to: file, as: .png)

        let decoded = try await decoder.decode(path: file.path, maxLongSide: nil)
        let rgba = pixel(decoded, 4, 4)
        for (got, want) in zip(rgba, [255, 0, 0, 255]) { #expect(abs(got - want) <= 2, "\(rgba)") }
    }

    @Test func aBrokenFileIsAScanFailure() async throws {
        let root = try folder()
        let file = root.appending(path: "broken.jpg")
        try Data("not an image".utf8).write(to: file)
        try Data("notes".utf8).write(to: root.appending(path: "notes.txt"))

        let scan = try await decoder.scan(folder: root.path)
        #expect(scan.candidates.isEmpty)
        #expect(scan.failures.map(\.reason) == ["not an image file"])
        #expect(scan.failures.map { URL(fileURLWithPath: $0.path).lastPathComponent } == ["broken.jpg"])
        await #expect(throws: LibraryError.notAnImage(file.path)) {
            _ = try await decoder.decode(path: file.path, maxLongSide: nil)
        }
        let gone = root.appending(path: "gone.jpg").path
        await #expect(throws: LibraryError.missingFile(gone)) { _ = try await decoder.decode(path: gone, maxLongSide: 512) }
    }

    @Test func decodeFitsTheLongSide() async throws {
        let root = try folder()
        let file = root.appending(path: "big.jpg")
        try write(image(4000, 3000, [UInt8](repeating: 128, count: 4000 * 3000 * 4)), to: file, as: .jpeg)

        let fitted = try await decoder.decode(path: file.path, maxLongSide: 512)
        #expect(fitted.size == PixelSize(width: 512, height: 384))
        #expect(fitted.rgba8.count == 512 * 384 * 4)
    }

    @Test func hiddenFilesAndPackagesAreNotListed() async throws {
        let root = try folder()
        let pixels = [UInt8](repeating: 200, count: 4 * 4 * 4)
        let package = root.appending(path: "Thing.bundle")
        let nested = root.appending(path: "Day 2")
        try FileManager.default.createDirectory(at: package, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try write(image(4, 4, pixels), to: root.appending(path: "seen.png"), as: .png)
        try write(image(4, 4, pixels), to: nested.appending(path: "nested.png"), as: .png)
        try write(image(4, 4, pixels), to: root.appending(path: ".hidden.png"), as: .png)
        try write(image(4, 4, pixels), to: package.appending(path: "inside.png"), as: .png)

        let scan = try await decoder.scan(folder: root.path)
        let names = Set(scan.candidates.map { URL(fileURLWithPath: $0.path).lastPathComponent })
        #expect(names == ["seen.png", "nested.png"])
        #expect(scan.failures.isEmpty)
    }

    @Test func aMissingFolderIsUnreadable() async throws {
        let root = try folder().appending(path: "Nowhere")
        await #expect(throws: LibraryError.unreadableFolder("Nowhere")) { _ = try await decoder.scan(folder: root.path) }
    }
}
#endif
