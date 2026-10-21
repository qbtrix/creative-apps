// LibraryExportFormatFidelityTests.swift: the other formats keep their pixels
// (packet docs/blueprints/library/features/export.md, EX-7; slice EX-c). PNG
// and TIFF written by `JPEGWriter` from `LiveExporter.render` decode back
// equal to the render, bit for bit; HEIC, when ImageIO on this Mac can write
// it, decodes within 35 dB PSNR; each file starts with its format's magic
// bytes. The real `ImageIODecoder` and `JPEGWriter` read and write the files;
// the bytes and pixels are the oracle.
//
// Written before its code (lead.md, contract rule 13, EX-7); EX-8 enables
// them, encodes by the name's extension and checks `writableFormats()` equals
// the ImageIO list ∩ the four formats. macOS only.
#if os(macOS)
import CoreGraphics
import CoreRaster
import Foundation
import ImageIO
import LibraryModel
import Testing
import UniformTypeIdentifiers

@testable import LibraryApp

@Suite struct LibraryExportFormatFidelityTests {
    private let decoder = ImageIODecoder()
    private let develop = LiveDevelop()

    struct FixtureError: Error, CustomStringConvertible { let description: String }

    /// The planned file: 1600 × 1200 at a long edge of 1024, named for `format`.
    private func item(_ format: ExportFormat) -> ExportPlan.Item {
        ExportPlan.Item(photoID: "IMG_0001", fileName: "IMG_0001.\(format.fileExtension)",
                        size: PixelSize(width: 1024, height: 768))
    }

    /// A fresh temp folder.
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "LibraryExportFormat-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// `IMG_0001.jpg` in `root`: a 1600 × 1200 sRGB JPEG whose color runs
    /// across both axes, developed at exposure +0.5. Blue is a soft wave about
    /// 38 px long at 1024, as in LibraryExportFidelityTests (#3372): a hard
    /// 160-level checker put HEIC's halved chroma at 24 dB, measuring the
    /// fixture, not the writer.
    private func writePhoto(in root: URL) throws -> PhotoItem {
        let (width, height) = (1600, 1200)
        let across = (0..<width).map { sin(Double($0) * 2 * .pi / 60) }
        let down = (0..<height).map { cos(Double($0) * 2 * .pi / 52) }
        var bytes = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let at = (y * width + x) * 4
                bytes[at] = UInt8(x * 255 / (width - 1))
                bytes[at + 1] = UInt8(y * 255 / (height - 1))
                bytes[at + 2] = UInt8((128 + 64 * across[x] * down[y]).rounded())
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

    /// Renders the photo, writes it as `format` and returns the render, the written bytes and their decode.
    private func roundTrip(_ format: ExportFormat) async throws -> (DisplayImage, Data, DisplayImage) {
        let root = try folder()
        let photo = try writePhoto(in: root)
        let out = root.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        let planned = item(format)
        let rendered = try await LiveExporter(decoder: decoder, develop: develop).render(planned, photo: photo)
        try await JPEGWriter().write(rendered, quality: 90, folder: out.path, fileName: planned.fileName)
        let file = out.appending(path: planned.fileName)
        let decoded = try await decoder.decode(path: file.path, maxLongSide: nil)
        return (rendered, try Data(contentsOf: file), decoded)
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

    /// `writableFormats()` is ImageIO's writable list ∩ the four formats, and
    /// always holds JPEG, PNG and TIFF.
    @Test func writableFormatsMatchImageIO() {
        let types = Set(CGImageDestinationCopyTypeIdentifiers() as? [String] ?? [])
        let identifiers: [ExportFormat: String] = [
            .jpeg: "public.jpeg", .png: "public.png", .tiff: "public.tiff", .heic: "public.heic",
        ]
        let expected = Set(ExportFormat.allCases.filter { identifiers[$0].map(types.contains) ?? false })
        #expect(JPEGWriter.writableFormats() == expected)
        #expect(JPEGWriter.writableFormats().isSuperset(of: [.jpeg, .png, .tiff]))
    }

    /// A name with no export format's extension is refused, and nothing is written.
    @Test func unknownExtensionIsRefused() async throws {
        let out = try folder()
        let image = try #require(DisplayImage(size: PixelSize(width: 2, height: 2), rgba8: [UInt8](repeating: 200, count: 16)))
        await #expect(throws: LibraryError.self) {
            try await JPEGWriter().write(image, quality: 90, folder: out.path, fileName: "IMG_0001.gif")
        }
        #expect(!FileManager.default.fileExists(atPath: out.appending(path: "IMG_0001.gif").path))
    }

    /// PNG starts 89 50 4E 47 and decodes back to the render, bit for bit.
    @Test func pngIsLossless() async throws {
        let (rendered, bytes, decoded) = try await roundTrip(.png)
        #expect([UInt8](bytes.prefix(4)) == [0x89, 0x50, 0x4E, 0x47], "the PNG doesn't start 89 50 4E 47")
        #expect(decoded.size == rendered.size)
        #expect(decoded.rgba8 == rendered.rgba8, "the PNG's pixels differ from the render")
    }

    /// TIFF starts II*\0 or MM\0* and decodes back to the render, bit for bit.
    @Test func tiffIsLossless() async throws {
        let (rendered, bytes, decoded) = try await roundTrip(.tiff)
        let magic = [UInt8](bytes.prefix(4))
        #expect(magic == [0x49, 0x49, 0x2A, 0x00] || magic == [0x4D, 0x4D, 0x00, 0x2A], "the TIFF starts \(magic)")
        #expect(decoded.size == rendered.size)
        #expect(decoded.rgba8 == rendered.rgba8, "the TIFF's pixels differ from the render")
    }

    /// HEIC, when this Mac can write it, holds `ftyp` at byte 4 and is within 35 dB.
    @Test func heicIsCloseWhenWritable() async throws {
        guard JPEGWriter.writableFormats().contains(.heic) else { return }
        let (rendered, bytes, decoded) = try await roundTrip(.heic)
        #expect([UInt8](bytes.dropFirst(4).prefix(4)) == Array("ftyp".utf8), "the HEIC has no ftyp at byte 4")
        #expect(decoded.size == rendered.size)
        let ratio = psnr(decoded, rendered)
        #expect(ratio >= 35, "the HEIC is \(ratio) dB from the render")
    }
}
#endif
