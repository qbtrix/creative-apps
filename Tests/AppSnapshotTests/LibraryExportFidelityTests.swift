// LibraryExportFidelityTests.swift: QB-V4 on an uncropped photo (packet
// docs/blueprints/library/features/export.md, EX-4; slice EX-b). An exported
// file looks like the loupe: (a) `LiveExporter.render` of a 4000 × 3000 file
// with exposure +0.5 at 1024 equals decode → `LiveDevelop.render` → lanczos3
// by hand, bit for bit; (b) it sits within a mean absolute difference of
// 1/255 of the loupe's `.full` render at 1024; (c) written at quality 95 and
// decoded, it is at least 40 dB PSNR from (a), the file starts `FF D8` and is
// tagged sRGB, and a second write to the same name throws `writeFailed` and
// leaves the first file's bytes alone. The real `ImageIODecoder` and
// `JPEGWriter` read and write the files; the bytes and pixels are the oracle.
//
// Written before its code (lead.md, contract rule 13): every test is disabled
// "waits on EX-5", which enables them; EX-14 adds the cropped photo. macOS only.
#if os(macOS)
import CoreGraphics
import CoreRaster
import Foundation
import ImageIO
import LibraryModel
import Testing
import UniformTypeIdentifiers

@testable import LibraryApp

@Suite struct LibraryExportFidelityTests {
    private let decoder = ImageIODecoder()
    private let develop = LiveDevelop()
    /// The planned file: 4000 × 3000 at a long edge of 1024.
    private let item = ExportPlan.Item(
        photoID: "IMG_0001", fileName: "IMG_0001.jpg", size: PixelSize(width: 1024, height: 768))

    struct FixtureError: Error, CustomStringConvertible { let description: String }

    /// A fresh temp folder.
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "LibraryExportFidelity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// `IMG_0001.jpg` in `root`: a 4000 × 3000 sRGB JPEG at full quality whose
    /// color runs across both axes, so resampling has detail to get wrong.
    private func writePhoto(in root: URL) throws -> PhotoItem {
        let (width, height) = (4000, 3000)
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let at = (y * width + x) * 4
                bytes[at] = UInt8(x * 255 / (width - 1))
                bytes[at + 1] = UInt8(y * 255 / (height - 1))
                bytes[at + 2] = UInt8(((x / 40 + y / 40) % 2) * 160 + 40)
            }
        }
        let url = root.appending(path: "IMG_0001.jpg")
        let image = bytes.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                let context = CGContext(
                    data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: space, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)
            else { return nil }
            return context.makeImage()
        }
        guard let picture = image,
            let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { throw FixtureError(description: "can't write \(url.lastPathComponent)") }
        let options: [CFString: Any] = [kCGImageDestinationLossyCompressionQuality: 1.0]
        CGImageDestinationAddImage(destination, picture, options as CFDictionary)
        guard CGImageDestinationFinalize(destination) else { throw FixtureError(description: "couldn't finish the fixture") }
        return PhotoItem(
            id: url.path, name: "IMG_0001", captureDate: Date(timeIntervalSince1970: 0), color: .init(0.5, 0.5, 0.5),
            path: url.path, pixelSize: PixelSize(width: width, height: height),
            develop: DevelopSettings.neutral.setting(.exposure, to: 0.5))
    }

    /// Decode at full size → develop → lanczos3 to the item's size, by hand.
    private func byHand(_ photo: PhotoItem) async throws -> DisplayImage {
        let path = try #require(photo.path)
        let decoded = try await decoder.decode(path: path, maxLongSide: nil)
        let buffer = try PixelBuffer(rgba8: decoded.rgba8, width: decoded.size.width, height: decoded.size.height)
        var developed = try develop.render(buffer, settings: photo.develop)
        let target = PixelSize(width: developed.width, height: developed.height).fitting(longSide: item.size.longSide)
        if target.width != developed.width || target.height != developed.height {
            developed = try developed.resized(width: target.width, height: target.height, filter: .lanczos3)
        }
        return try #require(DisplayImage(size: target, rgba8: try developed.rgba8(colorSpace: .sRGB)))
    }

    /// The mean absolute difference of the color channels, in 0...255.
    private func meanDifference(_ a: DisplayImage, _ b: DisplayImage) -> Double {
        var total = 0, count = 0
        for at in stride(from: 0, to: min(a.rgba8.count, b.rgba8.count), by: 4) {
            for c in 0..<3 { total += abs(Int(a.rgba8[at + c]) - Int(b.rgba8[at + c])); count += 1 }
        }
        return count == 0 ? .infinity : Double(total) / Double(count)
    }

    /// Peak signal-to-noise ratio of the color channels, in dB.
    private func psnr(_ a: DisplayImage, _ b: DisplayImage) -> Double {
        var squared = 0.0, count = 0
        for at in stride(from: 0, to: min(a.rgba8.count, b.rgba8.count), by: 4) {
            for c in 0..<3 {
                let d = Double(Int(a.rgba8[at + c]) - Int(b.rgba8[at + c]))
                squared += d * d; count += 1
            }
        }
        guard count > 0 else { return 0 }
        let mse = squared / Double(count)
        return mse == 0 ? .infinity : 10 * log10(255 * 255 / mse)
    }

    /// (a) The exporter's render is the hand-made pipeline, bit for bit.
    @Test(.disabled("waits on EX-5")) func renderEqualsTheHandMadePipeline() async throws {
        let photo = try writePhoto(in: try folder())
        let exporter = LiveExporter(decoder: decoder, develop: develop)
        let rendered = try await exporter.render(item, photo: photo)
        let expected = try await byHand(photo)
        #expect(rendered.size == PixelSize(width: 1024, height: 768))
        #expect(rendered.size == expected.size)
        #expect(rendered.rgba8 == expected.rgba8, "the export's pixels differ from decode → develop → lanczos3")
    }

    /// (b) The export at 1024 looks like the loupe's `.full` render at 1024.
    @Test(.disabled("waits on EX-5")) func renderMatchesTheLoupe() async throws {
        let photo = try writePhoto(in: try folder())
        let rendered = try await LiveExporter(decoder: decoder, develop: develop).render(item, photo: photo)
        let loupe = try await LiveLoupeImaging(decoder: decoder, develop: develop)
            .render(photo, settings: photo.develop, longSide: 1024, quality: .full).image
        #expect(loupe.size == rendered.size)
        let difference = meanDifference(rendered, loupe)
        #expect(difference <= 1, "the export is \(difference)/255 from the loupe on average")
    }

    /// (c) Written at quality 95: an sRGB JPEG within 40 dB of (a), never overwritten.
    @Test(.disabled("waits on EX-5")) func writtenFileIsAnSRGBJPEGThatNeverOverwrites() async throws {
        let root = try folder()
        let photo = try writePhoto(in: root)
        let out = root.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let rendered = try await LiveExporter(decoder: decoder, develop: develop).render(item, photo: photo)
        let writer = JPEGWriter()
        try await writer.write(rendered, quality: 95, folder: out.path, fileName: item.fileName)
        let file = out.appending(path: item.fileName)
        let bytes = try Data(contentsOf: file)
        #expect([UInt8](bytes.prefix(2)) == [0xFF, 0xD8], "the file doesn't start FF D8")
        let source = try #require(CGImageSourceCreateWithURL(file as CFURL, nil))
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil))
        #expect(image.colorSpace?.name.map { $0 as String } == (CGColorSpace.sRGB as String), "the file isn't tagged sRGB")
        #expect(try await writer.existingNames(in: out.path) == [item.fileName])

        let decoded = try await decoder.decode(path: file.path, maxLongSide: nil)
        #expect(decoded.size == rendered.size)
        let ratio = psnr(decoded, rendered)
        #expect(ratio >= 40, "the written file is \(ratio) dB from the render")

        do {
            try await writer.write(rendered, quality: 50, folder: out.path, fileName: item.fileName)
            Issue.record("a second write to \(item.fileName) didn't throw")
        } catch let error as LibraryError {
            guard case .writeFailed = error else {
                Issue.record("a second write threw \(error), not writeFailed")
                return
            }
        }
        #expect(try Data(contentsOf: file) == bytes, "the second write changed the first file")
    }
}
#endif
