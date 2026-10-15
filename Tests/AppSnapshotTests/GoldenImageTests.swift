// GoldenImageTests.swift: the golden compare against fixed images (QB-S31)
// and within its time budget (QB-S15). macOS only.
import AppKit
import SuiteUI
import Testing

@Suite struct GoldenImageTests {
    /// A w × h opaque image, every channel `value`.
    static func solid(_ width: Int, _ height: Int, _ value: UInt8 = 120) -> RGBAImage {
        var bytes = [UInt8](repeating: value, count: width * height * 4)
        for i in stride(from: 3, to: bytes.count, by: 4) { bytes[i] = 255 }
        return RGBAImage(width: width, height: height, bytes: bytes)
    }

    /// `base` with the red channel of pixel (5, 4) raised by 3: one pixel of 100, over tolerance 2.
    static func onePixelOff(_ base: RGBAImage) -> RGBAImage {
        var off = base
        off.bytes[(4 * base.width + 5) * 4] &+= 3
        return off
    }

    @Test func reference() throws {
        let compare = GoldenImage()
        let base = Self.solid(10, 10)
        let same = compare.compare(base, to: base, tolerance: .standard)
        #expect(same.passes && same.differing == 0 && same.share == 0 && same.diff == nil)

        let off = Self.onePixelOff(base)
        let strict = compare.compare(off, to: base, tolerance: .standard)
        #expect(!strict.passes && strict.differing == 1 && strict.share == 0.01)
        let diff = try #require(strict.diff)
        let at = (4 * 10 + 5) * 4
        #expect(Array(diff.bytes[at..<at + 4]) == [255, 0, 255, 255])
        #expect(Array(diff.bytes[0..<4]) != [255, 0, 255, 255])
        #expect(compare.compare(off, to: base, tolerance: GoldenTolerance(maxShare: 0.01)).passes)
        #expect(compare.compare(off, to: base, tolerance: GoldenTolerance(channel: 3)).differing == 0)

        let sized = compare.compare(Self.solid(10, 9), to: base, tolerance: .standard)
        #expect(!sized.passes && sized.share == 1 && sized.diff == nil)
        let malformed = RGBAImage(width: 10, height: 10, bytes: [UInt8](repeating: 0, count: 12))
        #expect(compare.compare(malformed, to: malformed, tolerance: .standard).share == 1)

        // Through the files: a scratch test folder and a scratch output folder.
        let dir = FileManager.default.temporaryDirectory.appending(path: "golden-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: dir) }
        let file = dir.appending(path: "FakeSnapshots.swift").path
        let output = dir.appending(path: "snapshots")

        let missing = try checkGolden(base, name: "dot", area: "test", appearance: "light",
                                      filePath: file, output: output)
        guard case .recorded(let recorded, let newURL) = missing else {
            Issue.record("a missing baseline gave \(missing)")
            return
        }
        #expect(!recorded.passes && recorded.share == 1)
        #expect(newURL.path.hasSuffix("golden-new/test/dot-light.png"))
        let newPNG = try Data(contentsOf: newURL)
        #expect(RGBAImage(png: newPNG) == base)
        assertGolden(base, name: "dot", area: "test", appearance: "light", filePath: file, output: output)

        let baselineURL = goldenBaselineURL(name: "dot", area: "test", appearance: "light", filePath: file)
        try FileManager.default.createDirectory(at: baselineURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try #require(base.pngData()).write(to: baselineURL)

        let matched = try checkGolden(base, name: "dot", area: "test", appearance: "light",
                                      filePath: file, output: output)
        #expect(matched == .matched(same))
        let loose = try checkGolden(off, name: "dot", area: "test", appearance: "light",
                                    tolerance: GoldenTolerance(maxShare: 0.01), filePath: file, output: output)
        #expect(loose.result.passes)
        let failed = try checkGolden(off, name: "dot", area: "test", appearance: "light",
                                     filePath: file, output: output)
        guard case .mismatched(let result, let actualURL, let diffURL) = failed else {
            Issue.record("one pixel off at .standard gave \(failed)")
            return
        }
        #expect(!result.passes && result.share == 0.01)
        #expect(actualURL.path.hasSuffix("golden-diff/test/dot-light.png"))
        let actualPNG = try Data(contentsOf: actualURL)
        #expect(RGBAImage(png: actualPNG) == off)
        let diffFile = try #require(diffURL)
        #expect(diffFile.path.hasSuffix("golden-diff/test/dot-light-diff.png"))
        let diffPNG = try Data(contentsOf: diffFile)
        #expect(RGBAImage(png: diffPNG) == result.diff)
    }

    /// A passing compare builds no diff image; a failing one does, and counts every differing row.
    @Test func diffOnlyOnFailure() throws {
        let compare = GoldenImage()
        let base = Self.solid(10, 10)
        let off = Self.onePixelOff(base)
        let passing = compare.compare(off, to: base, tolerance: GoldenTolerance(maxShare: 0.01))
        #expect(passing.passes && passing.differing == 1 && passing.diff == nil)

        var spread = base
        for (x, y) in [(0, 0), (9, 0), (3, 5), (9, 9)] { spread.bytes[(y * 10 + x) * 4 + 3] = 0 }
        let failing = compare.compare(spread, to: base, tolerance: .standard)
        #expect(!failing.passes && failing.differing == 4 && failing.share == 0.04)
        let diff = try #require(failing.diff)
        let last = (9 * 10 + 9) * 4
        #expect(Array(diff.bytes[last..<last + 4]) == [255, 0, 255, 255])
    }

    @Test func compareWithinBudget() {
        let width = 2_880, height = 1_800
        let bytes = (0..<(width * height * 4)).map { UInt8(truncatingIfNeeded: $0 &* 7) }
        let base = RGBAImage(width: width, height: height, bytes: bytes)
        let off = Self.onePixelOff(base)
        let compare = GoldenImage()
        let clock = ContinuousClock()
        var seconds: [Double] = []
        var differing = 0
        for _ in 0..<100 {
            let elapsed = clock.measure {
                differing += compare.compare(off, to: base, tolerance: .standard).differing
            }
            seconds.append(Double(elapsed.components.seconds) + Double(elapsed.components.attoseconds) / 1e18)
        }
        #expect(differing == 100)
        seconds.sort()
        let median = seconds[49], p95 = seconds[94]   // nearest rank of 100 samples
        #if DEBUG
        let budget = 1.5
        #else
        let budget = 0.15
        #endif
        #expect(median <= budget && p95 <= budget, "median \(median) s, p95 \(p95) s, budget \(budget) s")
    }
}
