// LibraryExportAppBudgetTests.swift: P8's workload (quality gate #6205, QB-L9) on the app's own export
// path, without the window: ten 6000 × 4000 JPEGs rendered at 2048 by `LiveExporter` over the real
// `ImageIODecoder` and `LiveDevelop`, then written by `JPEGWriter` at quality 90. It gates the whole run
// at P8's 15 s in a release build and prints a `LIBRARY-BUDGET export app …` line in a debug one (the
// journeys build debug, so that line is the hosted run's floor). The headless half is
// LibraryDevelopBudgetTests+Export. Disabled until the supervisor lists it in Tests/perf-suites.txt: it
// reads the wall clock. macOS only.
#if os(macOS)
import CoreGraphics
import Foundation
import ImageIO
import LibraryModel
import Testing
import UniformTypeIdentifiers

@testable import LibraryApp

@Suite struct LibraryExportAppBudgetTests {
    /// A noisy 6000 × 4000 sRGB JPEG at `url`, so the decoder does a photo's work, not a flat fill's.
    private static func writePhoto(to url: URL) throws {
        let (w, h) = (6000, 4000)
        var bytes = [UInt8](repeating: 255, count: w * h * 4)
        var seed: UInt32 = 1
        for y in 0..<h {
            for x in 0..<w {
                seed = seed &* 1_664_525 &+ 1_013_904_223
                let n = Int(seed >> 28) - 8, at = (y * w + x) * 4
                bytes[at] = UInt8(clamping: x * 255 / w + n)
                bytes[at + 1] = UInt8(clamping: y * 255 / h + n)
                bytes[at + 2] = UInt8(clamping: 128 + n * 4)
            }
        }
        let image = bytes.withUnsafeMutableBytes { buffer -> CGImage? in
            guard let space = CGColorSpace(name: CGColorSpace.sRGB),
                  let context = CGContext(data: buffer.baseAddress, width: w, height: h, bitsPerComponent: 8,
                                          bytesPerRow: w * 4, space: space,
                                          bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue) else { return nil }
            return context.makeImage()
        }
        let picture = try #require(image)
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, picture, [kCGImageDestinationLossyCompressionQuality: 0.9] as CFDictionary)
        #expect(CGImageDestinationFinalize(destination))
    }

    @Test(.disabled("reads the wall clock: waits on a Tests/perf-suites.txt line (#6205)"))
    func tenFullSizeJPEGsAt2048WithinP8() async throws {
        let root = FileManager.default.temporaryDirectory.appending(path: "LibraryExportAppBudget-\(UUID().uuidString)")
        let out = root.appending(path: "out")
        try FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let first = root.appending(path: "IMG_0001.jpg")
        try Self.writePhoto(to: first)
        var photos: [PhotoItem] = []
        for n in 1...10 {
            let url = root.appending(path: String(format: "IMG_%04d.jpg", n))
            if n > 1 { try FileManager.default.copyItem(at: first, to: url) }
            photos.append(PhotoItem(id: url.path, name: url.deletingPathExtension().lastPathComponent,
                                    captureDate: Date(timeIntervalSince1970: 0), color: .init(0.5, 0.5, 0.5),
                                    path: url.path, pixelSize: PixelSize(width: 6000, height: 4000)))
        }
        let exporter = LiveExporter(decoder: ImageIODecoder(), develop: LiveDevelop())
        let writer = JPEGWriter()
        let plan = exporter.plan(photos, options: ExportOptions(longEdge: 2048, folder: out.path), existingNames: [])
        let clock = ContinuousClock(), start = clock.now
        for (item, photo) in zip(plan.items, photos) {
            let image = try await exporter.render(item, photo: photo)
            try await writer.write(image, quality: 90, folder: out.path, fileName: item.fileName)
        }
        let took = clock.now - start
        let elapsed = Double(took.components.seconds) + Double(took.components.attoseconds) / 1e18
        print("LIBRARY-BUDGET export app ten 6000x4000 JPEGs at 2048: \(elapsed) s (budget 15.0 s)")
        #expect(try await writer.existingNames(in: out.path).count == 10)
        if !_isDebugAssertConfiguration() { #expect(elapsed <= 15) }
    }
}
#endif
