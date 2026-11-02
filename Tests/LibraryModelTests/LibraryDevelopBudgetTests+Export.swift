// LibraryDevelopBudgetTests+Export.swift: the headless export's real-size budget (quality gate #6205). Two
// 6000 x 4000 picks export as PNGs at full size within 8 s and at a 1,200 px long side within 4 s, in a release
// build; a debug build only reports (the CLI ships release). Before the fix they took 21.5 s and 4.17 s: Deflate
// level 6 spent 11 s on each full-size write. The 1,200 row is the decode plus the lanczos3 shrink, which is
// core's resample loop (creative-core#825); tighten it when that lands. It sits in the develop budget suite, which the perf list runs
// nightly, so a busy CI runner never judges it. Prints a `LIBRARY-BUDGET export …` line per row.
@testable import LibraryModel
import CoreRaster
import Foundation
import SuiteKernel
import Testing

extension LibraryDevelopBudgetTests {
    /// A noisy 6000 x 4000 gradient as a PNG, so Deflate does a photo's work, not a flat fill's.
    private static func photoPNG() throws -> Data {
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
        return try PNG.write(PixelBuffer(rgba8: bytes, width: w, height: h), level: 1)
    }

    @Test(arguments: [(nil, 8.0), (1200, 4.0)] as [(Int?, Double)])
    func twoFullSizePicksExportWithinBudget(longSide: Int?, budget: Double) throws {
        let png = try Self.photoPNG()
        var doc = try LibraryHeadless.new(.object([:]))
        try doc.importImage(png, name: "IMG_0001.png")
        try doc.importImage(png, name: "IMG_0002.png")
        _ = try LibraryHeadless.catalog.run("edit.select-all", params: .object([:]), on: &doc)
        _ = try LibraryHeadless.catalog.run("metadata.pick", params: .object([:]), on: &doc)
        let options: JSONValue = longSide.map { .object(["longSide": .number(Double($0))]) } ?? .object([:])
        let clock = ContinuousClock()
        var files: [ExportedFile] = []
        let took = clock.measure { files = (try? doc.export("png", options: options)) ?? [] }
        let elapsed = Double(took.components.seconds) + Double(took.components.attoseconds) / 1e18
        print("LIBRARY-BUDGET export two 6000x4000 picks at \(longSide.map(String.init) ?? "full"): \(elapsed) s (budget \(budget) s)")
        #expect(files.map { LibraryHeadless.pngSize($0.data)?.longSide } == [longSide ?? 6000, longSide ?? 6000])
        if !_isDebugAssertConfiguration() { #expect(elapsed <= budget) }
    }
}
