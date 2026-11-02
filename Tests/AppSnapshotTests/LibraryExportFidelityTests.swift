// LibraryExportFidelityTests.swift: QB-V4 on an uncropped photo (packet
// docs/blueprints/library/features/export.md, EX-4; slice EX-b). An exported
// file looks like the loupe: (a) `LiveExporter.render` of a 2000 × 1500 file
// with exposure +0.5 at 1024 equals decode → lanczos3 to the smallest size
// whose crop covers the plan → `LiveDevelop.render` → lanczos3 to the plan, by
// hand, bit for bit (develop runs on the export's pixels, as the loupe's runs
// on its decode, #5992), and is at most 2/255 on any channel from developing
// at full size; (b) it sits within a mean absolute difference of
// 1/255 of the loupe's `.full` render at 1024; (c) written at quality 95 and
// decoded, it is at least 40 dB PSNR from (a), the file starts `FF D8` and is
// tagged sRGB, and a second write to the same name throws `writeFailed` and
// leaves the first file's bytes alone. The real `ImageIODecoder` and
// `JPEGWriter` read and write the files; the bytes and pixels are the oracle.
//
// Written before its code (lead.md, contract rule 13) by EX-4 and enabled by
// EX-5, which builds `JPEGWriter`. EX-14 runs (a) and (b) again on the photo
// cropped 3:2 and straightened 2°, sized by the exporter's own plan, drawn at
// 1440 × 1080: straightening a 4000 × 3000 file twice in a debug build ran past
// CI's 600 s silence watchdog, and the crop's checks don't need the size
// (EX-14 names none). On the crop, developing at full size is not the
// reference: its crop lands a fraction of a pixel off the loupe's (1.6/255
// mean, #3453), the shrink-first order 0.38/255. macOS only.
//
// The uncropped fixture is 2000 × 1500, not the 4000 × 3000 the packet first
// named: at 4000 the five tests ran five full-size lanczos3 passes in a debug
// build (`PixelBuffer.convolved`, CoreRaster), 650 s one at a time, and in
// CI's 3-core heavy pass they held every cooperative thread for so long that
// the pass printed nothing for 600 s and the hang watchdog killed it (#6089).
// Every check is a ratio or a pixel diff that doesn't depend on the source
// size, as EX-14's 1440 × 1080 crop already showed.
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
    /// The planned file: 2000 × 1500 at a long edge of 1024.
    private let item = ExportPlan.Item(
        photoID: "IMG_0001", fileName: "IMG_0001.jpg", size: PixelSize(width: 1024, height: 768))

    struct FixtureError: Error, CustomStringConvertible { let description: String }

    /// A fresh temp folder.
    private func folder() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "LibraryExportFidelity-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    /// `IMG_0001.jpg` in `root`: a `width` × `height` (2000 × 1500) sRGB JPEG at full quality whose
    /// color runs across both axes, so resampling has detail to get wrong.
    /// Blue is a soft wave about 38 px long at 1024, photo-like rather than a
    /// hard checkerboard: a 160-level checker of 10 px squares at 1024 put
    /// (b) 4.2/255 apart on the two resamplers' edges (#3276) and (c) at
    /// 22 dB on JPEG's halved chroma (#3277), measuring the fixture, not QB-V4.
    private func writePhoto(in root: URL, width: Int = 2000, height: Int = 1500,
                            develop: DevelopSettings = DevelopSettings.neutral.setting(.exposure, to: 0.5)) throws -> PhotoItem {
        // The wave keeps its length at the output size, so a smaller file gets a shorter one.
        let (waveX, waveY) = (150.0 * Double(width) / 4000, 130.0 * Double(height) / 3000)
        let across = (0..<width).map { sin(Double($0) * 2 * .pi / waveX) }
        let down = (0..<height).map { cos(Double($0) * 2 * .pi / waveY) }
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
            develop: develop)
    }

    /// The fixture at 1440 × 1080 cropped 3:2 and straightened 2°, with its planned item at 1024.
    private func writeCroppedPhoto(in root: URL) throws -> (PhotoItem, ExportPlan.Item) {
        let crop = try LiveCrop().initial(aspect: .threeTwo, angle: 2, photo: PixelSize(width: 1440, height: 1080))
        let photo = try writePhoto(in: root, width: 1440, height: 1080,
                                   develop: DevelopSettings.neutral.setting(.exposure, to: 0.5).setting(crop: crop))
        let plan = LiveExporter(decoder: decoder, develop: develop)
            .plan([photo], options: ExportOptions(longEdge: 1024, folder: root.path), existingNames: [])
        return (photo, try #require(plan.items.first))
    }

    /// Decode at full size → lanczos3 to the smallest size whose crop covers the item's (`fullSize` skips it)
    /// → develop → lanczos3 to the item's size, by hand.
    private func byHand(_ photo: PhotoItem, at item: ExportPlan.Item, fullSize: Bool = false) async throws -> DisplayImage {
        let path = try #require(photo.path)
        let decoded = try await decoder.decode(path: path, maxLongSide: nil)
        var buffer = try PixelBuffer(rgba8: decoded.rgba8, width: decoded.size.width, height: decoded.size.height)
        let side = try shrunkSide(photo, at: item)
        if !fullSize, side < decoded.size.longSide {
            let shrunk = decoded.size.fitting(longSide: side)
            buffer = try buffer.resized(width: shrunk.width, height: shrunk.height, filter: .lanczos3)
        }
        var developed = try develop.render(buffer, settings: photo.develop)
        let target = item.size
        if target.width != developed.width || target.height != developed.height {
            developed = try developed.resized(width: target.width, height: target.height, filter: .lanczos3)
        }
        return try #require(DisplayImage(size: target, rgba8: try developed.rgba8(colorSpace: .sRGB)))
    }

    /// The photo's long side to shrink to: the plan's share of the crop, grown a pixel at a time until the
    /// crop drawn at it is at least the item's size both ways (`LiveCrop.frame` rounds at every step).
    private func shrunkSide(_ photo: PhotoItem, at item: ExportPlan.Item) throws -> Int {
        let size = photo.pixelSize
        func cut(_ s: PixelSize) throws -> PixelSize {
            guard let crop = photo.develop.crop else { return s }
            let f = try LiveCrop().frame(crop, photo: s)
            return PixelSize(width: f.width, height: f.height)
        }
        var side = Int((Double(size.longSide) * Double(item.size.longSide) / Double(try cut(size).longSide)).rounded())
        while side < size.longSide {
            let c = try cut(size.fitting(longSide: side))
            if c.width >= item.size.width && c.height >= item.size.height { break }
            side += 1
        }
        return side
    }

    /// The mean absolute difference of the color channels, in 0...255.
    private func meanDifference(_ a: DisplayImage, _ b: DisplayImage) -> Double {
        var total = 0, count = 0
        for at in stride(from: 0, to: min(a.rgba8.count, b.rgba8.count), by: 4) {
            for c in 0..<3 { total += abs(Int(a.rgba8[at + c]) - Int(b.rgba8[at + c])); count += 1 }
        }
        return count == 0 ? .infinity : Double(total) / Double(count)
    }

    /// The largest difference on any color channel, in 0...255.
    private func maxDifference(_ a: DisplayImage, _ b: DisplayImage) -> Int {
        var worst = 0
        for at in stride(from: 0, to: min(a.rgba8.count, b.rgba8.count), by: 4) {
            for c in 0..<3 { worst = max(worst, abs(Int(a.rgba8[at + c]) - Int(b.rgba8[at + c]))) }
        }
        return worst
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

    /// (a) The exporter's render is the hand-made pipeline, bit for bit, and develop's order doesn't show:
    /// developing at full size instead is at most 2/255 on any channel (1 measured on 3 of 2.4 M channels).
    @Test func renderEqualsTheHandMadePipeline() async throws {
        let photo = try writePhoto(in: try folder())
        let exporter = LiveExporter(decoder: decoder, develop: develop)
        let rendered = try await exporter.render(item, photo: photo)
        let expected = try await byHand(photo, at: item)
        #expect(rendered.size == PixelSize(width: 1024, height: 768))
        #expect(rendered.size == expected.size)
        #expect(rendered.rgba8 == expected.rgba8, "the export's pixels differ from decode → shrink → develop")
        let fullSize = maxDifference(rendered, try await byHand(photo, at: item, fullSize: true))
        #expect(fullSize <= 2, "the export is \(fullSize)/255 from developing at full size on one channel")
    }

    /// (b) The export at 1024 looks like the loupe's `.full` render at 1024.
    @Test func renderMatchesTheLoupe() async throws {
        let photo = try writePhoto(in: try folder())
        let rendered = try await LiveExporter(decoder: decoder, develop: develop).render(item, photo: photo)
        let loupe = try await LiveLoupeImaging(decoder: decoder, develop: develop)
            .render(photo, settings: photo.develop, longSide: 1024, quality: .full).image
        #expect(loupe.size == rendered.size)
        let difference = meanDifference(rendered, loupe)
        #expect(difference <= 1, "the export is \(difference)/255 from the loupe on average")
    }

    /// (a) on the cropped, straightened photo: the plan's size, and bit for bit.
    @Test func croppedRenderEqualsTheHandMadePipeline() async throws {
        let (photo, item) = try writeCroppedPhoto(in: try folder())
        #expect(item.size.longSide == 1024)
        #expect(abs(Double(item.size.width) / Double(item.size.height) - 1.5) < 0.005, "planned \(item.size), not 3:2")
        let rendered = try await LiveExporter(decoder: decoder, develop: develop).render(item, photo: photo)
        let expected = try await byHand(photo, at: item)
        #expect(rendered.size == item.size, "rendered \(rendered.size), planned \(item.size)")
        #expect(rendered.rgba8 == expected.rgba8, "the cropped export differs from decode → shrink → develop")
    }

    /// (b) on the cropped, straightened photo: the loupe decodes the whole
    /// photo before it crops, so it is asked at the long side whose crop comes
    /// out at the plan's size. `LiveCrop.frame` doesn't scale exactly with the
    /// photo (on 4000 × 3000 the plan's 1024 × 683 crop comes from a 1079 decode,
    /// not the 1073 its ratio gives), so that side is found from the frame's own
    /// arithmetic and rendered once. Not every fixture size has one (1600 × 1200
    /// plans 1024 × 682, which no decode crops to); 1440 × 1080 does.
    /// The export now straightens and crops at its shrunk scale, as the loupe does at its decode's: 0.38/255
    /// apart, where developing at full size put them 1.6/255 apart (#3453).
    @Test func croppedRenderMatchesTheLoupe() async throws {
        let (photo, item) = try writeCroppedPhoto(in: try folder())
        let rendered = try await LiveExporter(decoder: decoder, develop: develop).render(item, photo: photo)
        let crop = try #require(photo.develop.crop)
        let (width, height) = (photo.pixelSize.width, photo.pixelSize.height)
        let side = try (item.size.longSide...(2 * item.size.longSide)).first { side in
            let decoded = PixelSize(width: side, height: Int((Double(side) * Double(height) / Double(width)).rounded()))
            let frame = try LiveCrop().frame(crop, photo: decoded)
            return frame.width == rendered.size.width && frame.height == rendered.size.height
        }
        let longSide = try #require(side, "no loupe long side crops to \(rendered.size)")
        let shown = try await LiveLoupeImaging(decoder: decoder, develop: develop)
            .render(photo, settings: photo.develop, longSide: longSide, quality: .full).image
        try #require(shown.size == rendered.size, "the loupe at \(longSide) shows \(shown.size), the export is \(rendered.size)")
        let difference = meanDifference(rendered, shown)
        #expect(difference <= 1, "the cropped export is \(difference)/255 from the loupe on average")
    }

    /// (c) Written at quality 95: an sRGB JPEG within 40 dB of (a), never overwritten.
    @Test func writtenFileIsAnSRGBJPEGThatNeverOverwrites() async throws {
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
