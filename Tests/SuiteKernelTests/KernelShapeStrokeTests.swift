// KernelShapeStrokeTests.swift: the stroke and snap modules' declared shape
// (editor-kernel EK-29, slice EK-a). Every stroke and snap type the packet's
// contract names exists, its stubs return without trapping, the guide fake
// reads its summary and the stroke fixture holds 40 samples.
import Foundation
import Testing
import SuiteKernel

@Suite struct KernelShapeStrokeTests {
    @Test func strokeAndSnapStubsDeclared() throws {
        // Stroke: samples, segments, the smoother, the dab spacer.
        let samples = StrokeSample.strokeSamples
        #expect(samples.count == 40)
        #expect(samples.allSatisfy { (0...1).contains($0.pressure) })
        #expect(zip(samples, samples.dropFirst()).allSatisfy { $0.time < $1.time })
        let first = try #require(samples.first)
        let segment = StrokeSegment(p0: first.point, c1: first.point, c2: first.point, p1: Point(x: 10, y: 10), pressure: 0.5...1)
        var smoother = StrokeSmoother()
        for sample in samples { _ = smoother.add(sample) }
        _ = smoother.finish()
        #expect(!StrokeSmoother.flattened(segment, tolerance: 0.5).isEmpty)
        _ = DabSpacer.centers(first.point, Point(x: 50, y: 0), spacing: 5)

        // Brush settings and presets (Codable), and the live copy a drag draws on.
        var settings = BrushSettings()
        _ = settings.apply(.size(40))
        _ = settings.apply(.hardness(.nan))
        #expect(BrushSettings.ranges.size.lowerBound >= 1 && BrushSettings.ranges.percent == 0...100)
        let preset = BrushPreset(id: "soft", name: "Soft round", settings: BrushSettings(hardness: 0))
        #expect(try JSONDecoder().decode(BrushPreset.self, from: JSONEncoder().encode(preset)) == preset)
        var live = LiveCopy<Int>()
        live.begin(1)
        _ = live.edit { $0 += 1 }
        _ = live.take()

        // Snap: lines, gaps, guides, candidates, the engines.
        #expect(SnapGuides.fake.summary == "x 300, gap x 100, spacing x 100")
        #expect(SnapGuides.empty.summary.isEmpty)
        #expect(SnapGap(axis: .y, from: 0, to: .infinity, across: 0, isSpacing: false).length == 0)
        let candidates = [SnapCandidate(id: nil, frame: Rect(minX: 0, minY: 0, maxX: 1440, maxY: 1024)),
                          SnapCandidate(id: "a", frame: Rect(minX: 100, minY: 100, maxX: 200, maxY: 200))]
        let box = Rect(minX: 300, minY: 100, maxX: 400, maxY: 200)
        _ = (SnapLines(candidates).offset(.x, for: [300, 350, 400], tolerance: 4), SnapLines(candidates).lines(on: box))
        _ = (SnapGaps(candidates).spacingOffset(.x, for: box, tolerance: 4), SnapGaps(candidates).gaps(around: box))
        #expect(Snapping.offset(lines: nil, gaps: nil, wholePoints: 2) == 2)
    }
}
