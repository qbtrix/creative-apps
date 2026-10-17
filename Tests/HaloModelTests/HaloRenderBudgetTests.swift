// HaloRenderBudgetTests.swift: HB-12 and HB-13 (render-out RO-4), both
// report-only. HB-12 `renderPreview`: `LiveFrameRendering.render` at
// 480 × 270 of `reference` (50 layers) at 20 playheads, the draw list built
// untimed; the device budget is 50 ms. HB-13 `renderSequence`:
// `LiveCompositionRendering` sends `keyed`'s 48 frames at 1920 × 1080 into a
// counting sink that times each frame; the device budget is under 5 s for the
// whole sequence. Each prints p50, p95, max (and HB-13 the total) and fails
// only on too few samples, never on time. Release (`swift test -c release`)
// runs exactly that. Debug builds are minimal on purpose: CoreRaster runs
// about 20 times slower there (one `reference` frame at 480 × 270 took 12 s),
// and until this suite is listed in Tests/perf-suites.txt the merge gate
// (scripts/ci) runs it in parallel with every other test, where heavy frames
// starve wall-clock tests such as Design's. So debug only proves the paths
// run and the samples are counted: 1 preview of `keyed` (2 layers) instead of
// `reference`, and 1 frame of `empty`'s sequence at 1920 × 1080 instead of
// `keyed`'s (a `keyed` frame took 2 s), which ends .cancelled(frames: 1).
// Runs on Linux and macOS.
@testable import HaloModel
import Testing

#if DEBUG
/// Render Frame calls timed by HB-12 and the fixture they draw; frames of
/// HB-13's sequence timed and the fixture rendered.
private let previews = 1, previewFixture = "keyed", sequenceFrames = 1, sequenceFixture = "empty"
#else
private let previews = 20, previewFixture = "reference", sequenceFrames = 48, sequenceFixture = "keyed"
#endif

@Suite struct HaloRenderBudgetTests {
    @Test func renderPreview() throws {
        let doc = try #require(HaloFixtures.project(previewFixture))
        let comp = try #require(HaloProject(services: .fake, document: doc).selectedComposition)
        let drawing = LiveFrameDrawing(placing: FakeLayerPlacing())
        let rendering = LiveFrameRendering()
        let clock = ContinuousClock()
        var costs: [Duration] = []
        var sizes: Set<String> = []
        for step in 0..<previews {
            let list = drawing.drawList(comp, at: step * 7 % max(1, comp.durationFrames))
            var frame: HaloRenderedFrame?
            costs.append(clock.measure { frame = try? rendering.render(list, width: 480, height: 270, text: nil) })
            if let frame { sizes.insert("\(frame.pixels.width) × \(frame.pixels.height)") }
        }
        let series = RenderSeries(name: "HB-12 renderPreview", costs: costs, budget: .milliseconds(50))
        #expect(series.samples >= previews, "\(series.name): \(series.samples) samples, \(previews) needed")
        #expect(sizes == ["480 × 270"])
    }

    @Test func renderSequence() throws {
        let doc = try #require(HaloFixtures.project(sequenceFixture))
        let comp = try #require(HaloProject(services: .fake, document: doc).selectedComposition)
        let rendering = LiveCompositionRendering()
        let plan = try rendering.plan(comp, settings: HaloRenderSettings(format: .pngSequence))
        #expect(plan.width == 1920 && plan.height == 1080)
        let log = FrameTimes()
        var sink = TimingSink(log: log)
        let outcome = rendering.run(plan, of: comp, text: nil, into: &sink, isCancelled: { log.costs.count >= sequenceFrames })
        #expect(outcome == (sequenceFrames == 48 ? .finished(frames: 48) : .cancelled(frames: sequenceFrames)))
        let series = RenderSeries(name: "HB-13 renderSequence", costs: log.costs, budget: .seconds(5) / 48)
        let total = log.costs.reduce(.zero, +) * 48 / max(1, log.costs.count)
        print("HaloBudget HB-13 renderSequence 48 frames ~\(total) budget 5 s (report only)")
        #expect(series.samples >= sequenceFrames, "\(series.name): \(series.samples) samples, \(sequenceFrames) needed")
    }
}

/// Each written frame's cost, read by the run's `isCancelled` while the
/// sink is lent to it.
private final class FrameTimes {
    var costs: [Duration] = []
}

/// Counts written frames and times the gap since the last one, which is the
/// cost of rendering that frame (the sink itself stores no pixels).
private struct TimingSink: RenderSink {
    let log: FrameTimes
    private let clock = ContinuousClock()
    private var last: ContinuousClock.Instant?

    init(log: FrameTimes) { self.log = log }

    mutating func begin(_ plan: HaloRenderPlan) throws { last = clock.now }
    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
        let now = clock.now
        if let last { log.costs.append(now - last) }
        last = now
    }
    mutating func finish(cancelled: Bool) throws {}
}

/// A timed series, sorted, printed once with its p50, p95 and max.
private struct RenderSeries {
    let name: String, samples: Int, p50: Duration, p95: Duration, max: Duration

    init(name: String, costs: [Duration], budget: Duration) {
        let sorted = costs.sorted()
        self.name = name
        samples = sorted.count
        p50 = sorted.isEmpty ? .zero : sorted[sorted.count / 2]
        p95 = sorted.isEmpty ? .zero : sorted[sorted.count * 95 / 100]
        max = sorted.last ?? .zero
        print("HaloBudget \(name) p50 \(p50) p95 \(p95) max \(max) budget \(budget) (\(samples) samples, report only)")
    }
}
