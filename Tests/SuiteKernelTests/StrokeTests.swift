// StrokeTests.swift: the stroke model's rules (editor-kernel EK-27, slice
// EK-stroke). `StrokeSmoother` runs one segment late, drops a repeated point,
// clamps pressure and reads NaN as full, mirrors both ends and flattens a
// segment into 1...64 pieces; `DabSpacer` spaces dabs with a floor of 1 and a
// cap; `BrushSettings` clamps every value and ignores NaN; `BrushPreset`
// round-trips through JSON; `LiveCopy` hands its copy back once. KJ10 walks
// them together on the `strokeSamples` fixture. Checks first (docs/factory/
// lead.md rule 13): every test is disabled until EK-28 fills the bodies.
import Foundation
import Testing
import SuiteKernel

@Suite struct StrokeTests {
    /// Evenly spaced samples along the x axis, 10 points apart.
    static func line(_ count: Int, pressure: Double = 1) -> [StrokeSample] {
        (0..<count).map { StrokeSample(point: Point(x: Double($0) * 10, y: 0), pressure: pressure, time: Double($0) / 120) }
    }

    /// Every segment a smoother gives for `samples`, the one `finish` returns last.
    static func segments(_ samples: [StrokeSample]) -> [StrokeSegment] {
        var smoother = StrokeSmoother()
        var out = samples.compactMap { smoother.add($0) }
        if let last = smoother.finish() { out.append(last) }
        return out
    }

    static func distance(_ a: Point, _ b: Point) -> Double {
        ((a.x - b.x) * (a.x - b.x) + (a.y - b.y) * (a.y - b.y)).squareRoot()
    }

    // MARK: StrokeSmoother

    @Test(.disabled("waits on EK-28")) func oneSegmentLate() {
        var smoother = StrokeSmoother()
        let samples = Self.line(5)
        let firstThree = samples.prefix(3).map { smoother.add($0) }
        let fourth = smoother.add(samples[3]), fifth = smoother.add(samples[4])
        #expect(firstThree.allSatisfy { $0 == nil })
        #expect(fourth != nil)
        #expect(fifth != nil)
    }

    @Test(.disabled("waits on EK-28")) func segmentsChainThroughTheSamples() throws {
        let samples = StrokeSample.strokeSamples
        let segs = Self.segments(samples)
        #expect(!segs.isEmpty)
        #expect(zip(segs, segs.dropFirst()).allSatisfy { $0.p1 == $1.p0 })
        let points = Set(samples.map(\.point))
        #expect(segs.allSatisfy { points.contains($0.p0) && points.contains($0.p1) })
        let last = try #require(segs.last)
        #expect(last.p1 == samples.last?.point)
    }

    @Test(.disabled("waits on EK-28")) func dropsRepeatedPoint() {
        let clean = Self.line(6)
        var repeated: [StrokeSample] = []
        for s in clean { repeated.append(s); repeated.append(StrokeSample(point: s.point, pressure: s.pressure, time: s.time + 0.001)) }
        var smoother = StrokeSmoother()
        // a, a, b, b, c, c: three distinct points, so still no segment.
        let early = repeated.prefix(6).map { smoother.add($0) }
        let next = smoother.add(repeated[6])
        #expect(early.allSatisfy { $0 == nil })
        #expect(next != nil)
        #expect(Self.segments(repeated) == Self.segments(clean))
    }

    @Test(.disabled("waits on EK-28")) func pressureClamps() {
        let samples = Self.line(6).enumerated().map { i, s in
            StrokeSample(point: s.point, pressure: i.isMultiple(of: 2) ? 1.7 : -0.4, time: s.time)
        }
        let segs = Self.segments(samples)
        #expect(!segs.isEmpty)
        #expect(segs.allSatisfy { $0.pressure.lowerBound >= 0 && $0.pressure.upperBound <= 1 })
        #expect(segs.allSatisfy { $0.pressure == 0...1 })
    }

    @Test(.disabled("waits on EK-28")) func nanPressureIsOne() {
        let segs = Self.segments(Self.line(6, pressure: .nan))
        #expect(!segs.isEmpty)
        #expect(segs.allSatisfy { $0.pressure == 1...1 })
    }

    @Test(.disabled("waits on EK-28")) func pressureRangeSpansTheEnds() {
        let samples = StrokeSample.strokeSamples
        let byPoint = Dictionary(samples.map { ($0.point, $0.pressure) }, uniquingKeysWith: { a, _ in a })
        for seg in Self.segments(samples) {
            guard let a = byPoint[seg.p0], let b = byPoint[seg.p1] else { Issue.record("segment off the samples"); continue }
            #expect(seg.pressure == min(a, b)...max(a, b))
        }
    }

    @Test(.disabled("waits on EK-28")) func mirroredEnds() throws {
        let samples = Self.line(6)
        let segs = Self.segments(samples)
        let first = try #require(segs.first), last = try #require(segs.last)
        // A straight run stays straight: every handle on the line.
        #expect(segs.allSatisfy { $0.c1.y == 0 && $0.c2.y == 0 })
        // The mirrored start gives the first segment a real handle, not one on its end.
        #expect(first.c1.x > first.p0.x && first.c1.x < first.p1.x)
        // `finish` mirrors the far end: the last segment ends on the last sample, handle inside.
        #expect(last.p1 == samples.last?.point)
        #expect(last.c2.x > last.p0.x && last.c2.x < last.p1.x)
    }

    @Test(.disabled("waits on EK-28")) func finishOnEmptyIsNil() {
        var smoother = StrokeSmoother()
        let finished = smoother.finish()
        let added = smoother.add(StrokeSample(point: Point(x: 0, y: 0)))
        #expect(finished == nil)
        #expect(added == nil)
    }

    @Test(.disabled("waits on EK-28")) func flattenStraightIsOnePiece() {
        let seg = StrokeSegment(p0: Point(x: 0, y: 0), c1: Point(x: 10, y: 0), c2: Point(x: 20, y: 0), p1: Point(x: 30, y: 0), pressure: 1...1)
        let points = StrokeSmoother.flattened(seg, tolerance: 0.25)
        #expect(points.count == 2)
        #expect(points.first == seg.p0 && points.last == seg.p1)
    }

    @Test(.disabled("waits on EK-28")) func flattenCap64() {
        let seg = StrokeSegment(p0: Point(x: 0, y: 0), c1: Point(x: 0, y: 1_000_000), c2: Point(x: 1_000_000, y: -1_000_000), p1: Point(x: 10, y: 0), pressure: 1...1)
        let points = StrokeSmoother.flattened(seg, tolerance: 0.01)
        #expect(points.count == 65)
        #expect(points.first == seg.p0 && points.last == seg.p1)
    }

    @Test(.disabled("waits on EK-28")) func flattenCountInRange() {
        for seg in Self.segments(StrokeSample.strokeSamples) {
            let points = StrokeSmoother.flattened(seg, tolerance: 0.25)
            #expect((2...65).contains(points.count))
            #expect(points.first == seg.p0 && points.last == seg.p1)
        }
    }

    // MARK: DabSpacer

    @Test(.disabled("waits on EK-28")) func dabSpacing() throws {
        let a = Point(x: 0, y: 0), b = Point(x: 100, y: 0)
        let dabs = DabSpacer.centers(a, b, spacing: 10)
        #expect(dabs.first == a)
        #expect((10...11).contains(dabs.count))
        #expect(zip(dabs, dabs.dropFirst()).allSatisfy { abs(Self.distance($0, $1) - 10) < 1e-9 })
        #expect(dabs.allSatisfy { $0.y == 0 && $0.x >= 0 && $0.x <= 100 })
    }

    @Test(.disabled("waits on EK-28")) func spacingFloorOne() {
        let a = Point(x: 0, y: 0), b = Point(x: 10, y: 0)
        for spacing in [0, -5, 0.25] {
            let dabs = DabSpacer.centers(a, b, spacing: spacing)
            #expect((10...11).contains(dabs.count))
            #expect(zip(dabs, dabs.dropFirst()).allSatisfy { abs(Self.distance($0, $1) - 1) < 1e-9 })
        }
    }

    @Test(.disabled("waits on EK-28")) func dabCap() {
        let dabs = DabSpacer.centers(Point(x: 0, y: 0), Point(x: 1_000, y: 0), spacing: 1, cap: 5)
        #expect(dabs.count == 5)
        #expect(DabSpacer.centers(Point(x: 0, y: 0), Point(x: 1_000_000, y: 0), spacing: 1).count == 10_000)
    }

    // MARK: BrushSettings and BrushPreset

    @Test(.disabled("waits on EK-28")) func clampsSize() {
        var s = BrushSettings()
        let big = s.apply(.size(1_000)), bigSize = s.size
        let zero = s.apply(.size(0)), zeroSize = s.size
        let mid = s.apply(.size(42)), midSize = s.size
        let again = s.apply(.size(42))
        #expect(big && bigSize == BrushSettings.ranges.size.upperBound)
        #expect(zero && zeroSize == BrushSettings.ranges.size.lowerBound)
        #expect(mid && midSize == 42)
        #expect(!again)
    }

    @Test(.disabled("waits on EK-28")) func clampsPercentages() {
        var s = BrushSettings(size: 20, hardness: 50, opacity: 50, flow: 50, spacing: 50)
        let changed = [s.apply(.hardness(150)), s.apply(.opacity(-5)), s.apply(.flow(250)), s.apply(.spacing(-1))]
        let again = s.apply(.hardness(100))
        #expect(changed == [true, true, true, true])
        #expect(s.hardness == 100 && s.opacity == 0 && s.flow == 100 && s.spacing == 0)
        #expect(!again)
    }

    @Test(.disabled("waits on EK-28")) func ignoresNaN() {
        var s = BrushSettings()
        let before = s
        let changed = [BrushEdit.size(.nan), .hardness(.nan), .opacity(.nan), .flow(.nan), .spacing(.nan)].map { s.apply($0) }
        #expect(changed.allSatisfy { !$0 })
        #expect(s == before)
    }

    @Test(.disabled("waits on EK-28")) func presetRoundTrip() throws {
        var settings = BrushSettings()
        _ = settings.apply(.size(64))
        _ = settings.apply(.hardness(30))
        _ = settings.apply(.flow(45))
        let presets = [BrushPreset(id: "soft", name: "Soft round", settings: settings),
                       BrushPreset(id: "hard", name: "Hard round", settings: BrushSettings())]
        let back = try JSONDecoder().decode([BrushPreset].self, from: JSONEncoder().encode(presets))
        #expect(back == presets)
        #expect(back.first?.settings.size == 64)
    }

    // MARK: LiveCopy

    @Test(.disabled("waits on EK-28")) func takeOnce() {
        var live = LiveCopy<Int>()
        live.begin(1)
        let edited = live.edit { $0 += 1 }
        let shown = live.shown
        let first = live.take(), second = live.take()
        #expect(edited)
        #expect(shown == 2)
        #expect(first == 2)
        #expect(second == nil)
        #expect(live.shown == nil)
    }

    @Test(.disabled("waits on EK-28")) func nothingBegunIsNil() {
        var live = LiveCopy<Int>()
        let edited = live.edit { $0 += 1 }
        let taken = live.take()
        #expect(!edited)
        #expect(taken == nil)
    }

    @Test(.disabled("waits on EK-28")) func secondBeginIgnored() {
        var live = LiveCopy<Int>()
        live.begin(1)
        live.begin(5)
        let shown = live.shown, taken = live.take()
        #expect(shown == 1)
        #expect(taken == 1)
    }

    // MARK: KJ10

    /// KJ10, the stroke walk: the fixture through the smoother, each segment
    /// flattened and dabbed at the brush's spacing into a live copy, taken once.
    @Test(.disabled("waits on EK-28")) func strokeWalk() throws {
        let samples = StrokeSample.strokeSamples
        var brush = BrushSettings()
        let sized = brush.apply(.size(12))
        #expect(sized)
        let step = brush.size * brush.spacing / 100
        var live = LiveCopy<[Point]>()
        live.begin([])
        var smoother = StrokeSmoother()
        var segs: [StrokeSegment] = []
        for s in samples { if let seg = smoother.add(s) { segs.append(seg) } }
        if let seg = smoother.finish() { segs.append(seg) }
        #expect(segs.count >= samples.count - 3)
        #expect(segs.allSatisfy { $0.pressure.lowerBound >= 0.3 && $0.pressure.upperBound <= 1 })
        for seg in segs {
            let points = StrokeSmoother.flattened(seg, tolerance: 0.25)
            for (a, b) in zip(points, points.dropFirst()) {
                let edited = live.edit { $0 += DabSpacer.centers(a, b, spacing: step) }
                #expect(edited)
            }
        }
        let taken = live.take(), again = live.take()
        let dabs = try #require(taken)
        #expect(dabs.first == samples.first?.point || dabs.first == segs.first?.p0)
        #expect(dabs.count > samples.count)
        #expect(again == nil)
    }
}
