// HaloPNGWriterTests.swift: HF-7, a written PNG equals the render
// (render-out RO-6, #429). `keyed` at half size runs through
// LiveCompositionRendering into HaloPNGWriter; Bounce_0007.png, decoded with
// CGImageSource and read row by row from the image's data provider (never
// drawn into a context, which would premultiply), equals LiveFrameRendering's
// frame 6 at 960 × 540 as rgba8(colorSpace:) byte for byte. A 40 × 20
// composition with one 50% opaque solid over nothing keeps its straight
// alpha, 128, exactly. `begin` on a path that is a file throws and leaves
// the file alone; `finish(cancelled: true)` keeps the frames written.
// Writes no snapshot PNGs. macOS only.
import CoreGraphics
import CoreRaster
import Foundation
import HaloModel
import ImageIO
import Testing

@testable import HaloApp

@Suite(.timeLimit(.minutes(10))) struct HaloPNGWriterTests {
    /// A fresh, empty temp folder.
    private func scratch() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: "HaloPNGWriterTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func keyedFrameSevenEqualsTheRender() throws {
        let comp = try #require(HaloFixtures.project("keyed")?.compositions.first)
        let rendering = LiveCompositionRendering()
        let plan = try rendering.plan(comp, settings: HaloRenderSettings(format: .pngSequence, halfSize: true))
        #expect(plan.width == 960 && plan.height == 540)
        let folder = try scratch().appending(path: "Bounce")
        var sink = HaloPNGWriter(folder: folder)
        let outcome = rendering.run(plan, of: comp, text: nil, into: &sink, isCancelled: { false })
        #expect(outcome == .finished(frames: 48))
        #expect(sink.written == plan.fileNames)
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path)
        #expect(Set(files) == Set(plan.fileNames))

        let decoded = try Self.decode(folder.appending(path: "Bounce_0007.png"))
        let frame = try LiveFrameRendering().render(
            LiveFrameDrawing().drawList(comp, at: 6), width: 960, height: 540, text: nil)
        let expected = try frame.pixels.rgba8(colorSpace: .sRGB)
        #expect(decoded.width == 960 && decoded.height == 540)
        #expect(decoded.bytes.count == expected.count)
        #expect(decoded.bytes == expected, "first difference at byte \(Self.firstDifference(decoded.bytes, expected))")
    }

    @Test func halfOpaqueSolidKeepsStraightAlpha() throws {
        let solid = HaloLayer(
            id: "comp-1-layer-1", name: "Half", kind: .solid, inFrame: 0, outFrame: 1,
            color: HaloLayerColor(red: 1, green: 0.5, blue: 0), opacity: 0.5)
        let comp = HaloComposition(
            id: "comp-1", name: "Alpha", width: 40, height: 20, framesPerSecond: 24, durationFrames: 1, layers: [solid])
        let rendering = LiveCompositionRendering()
        let plan = try rendering.plan(comp, settings: HaloRenderSettings(format: .pngSequence))
        let name = try #require(plan.fileNames.first)
        let folder = try scratch().appending(path: "Alpha")
        var sink = HaloPNGWriter(folder: folder)
        #expect(rendering.run(plan, of: comp, text: nil, into: &sink, isCancelled: { false }) == .finished(frames: 1))

        let decoded = try Self.decode(folder.appending(path: name))
        let frame = try LiveFrameRendering().render(LiveFrameDrawing().drawList(comp, at: 0), width: 40, height: 20, text: nil)
        let expected = try frame.pixels.rgba8(colorSpace: .sRGB)
        #expect(decoded.bytes == expected)
        #expect(decoded.bytes.count == 40 * 20 * 4)
        let alphas = stride(from: 3, to: decoded.bytes.count, by: 4).map { decoded.bytes[$0] }
        #expect(alphas.allSatisfy { $0 == 128 }, "alpha values \(Set(alphas))")
        // Straight, not premultiplied: full red stays near 255, not near half.
        #expect(decoded.bytes.first.map { $0 > 200 } == true, "red \(String(describing: decoded.bytes.first))")
    }

    @Test func beginRefusesAFile() throws {
        let file = try scratch().appending(path: "Bounce")
        let contents = Data("not a folder".utf8)
        try contents.write(to: file)
        var sink = HaloPNGWriter(folder: file)
        let plan = HaloRenderPlan(width: 2, height: 2, framesPerSecond: 24, frames: [0], fileNames: ["Bounce_0001.png"])
        var thrown: (any Error)?
        do { try sink.begin(plan) } catch { thrown = error }
        #expect(thrown as? HaloPNGWriter.Failure == .fileInTheWay("Bounce"))
        #expect(try Data(contentsOf: file) == contents)
    }

    @Test func cancelKeepsTheWrittenFrames() throws {
        let comp = try #require(HaloFixtures.project("keyed")?.compositions.first)
        let rendering = LiveCompositionRendering()
        let plan = try rendering.plan(comp, settings: HaloRenderSettings(format: .pngSequence, halfSize: true))
        let folder = try scratch().appending(path: "Bounce")
        var sink = HaloPNGWriter(folder: folder)
        var asked = 0
        let outcome = rendering.run(plan, of: comp, text: nil, into: &sink, isCancelled: {
            asked += 1
            return asked > 3
        })
        #expect(outcome == .cancelled(frames: 3))
        let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).sorted()
        #expect(files == Array(plan.fileNames.prefix(3)))
    }

    // MARK: Decoding

    /// The PNG at `url` as straight RGBA8 bytes, top row first, copied row by
    /// row from the decoded image's own bytes (no drawing).
    private static func decode(_ url: URL) throws -> (width: Int, height: Int, bytes: [UInt8]) {
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil), "can't open \(url.lastPathComponent)")
        let image = try #require(CGImageSourceCreateImageAtIndex(source, 0, nil), "can't decode \(url.lastPathComponent)")
        try #require(image.bitsPerComponent == 8 && image.bitsPerPixel == 32, "decoded \(image.bitsPerPixel) bpp")
        try #require(image.alphaInfo == .last, "decoded alpha info \(image.alphaInfo.rawValue)")
        try #require(
            image.byteOrderInfo == .orderDefault || image.byteOrderInfo == .order32Big,
            "decoded byte order \(image.byteOrderInfo.rawValue)")
        let data = try #require(image.dataProvider?.data) as Data
        let rowBytes = image.width * 4
        try #require(image.bytesPerRow >= rowBytes && data.count >= image.bytesPerRow * (image.height - 1) + rowBytes)
        var bytes: [UInt8] = []
        bytes.reserveCapacity(rowBytes * image.height)
        for y in 0..<image.height {
            let start = data.startIndex + y * image.bytesPerRow
            bytes.append(contentsOf: data[start..<start + rowBytes])
        }
        return (image.width, image.height, bytes)
    }

    /// The first index where `a` and `b` differ, or -1 when they don't.
    private static func firstDifference(_ a: [UInt8], _ b: [UInt8]) -> Int {
        zip(a, b).enumerated().first(where: { $0.element.0 != $0.element.1 })?.offset ?? (a.count == b.count ? -1 : min(a.count, b.count))
    }
}
