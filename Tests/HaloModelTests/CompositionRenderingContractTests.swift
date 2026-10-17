// CompositionRenderingContractTests.swift: what every CompositionRendering
// promises (#429), run over each conforming type in `compositionRenderings`:
// the fake and the live type, which share HaloRenderRules. Runs on Linux and
// macOS.
import HaloModel
import Testing

let compositionRenderings: [any CompositionRendering] = [FakeCompositionRendering(), LiveCompositionRendering()]

/// A sink that keeps what it was sent, in order.
struct RecordingSink: RenderSink {
    var names: [String] = []
    var sizes: Set<[Int]> = []
    var finished: [Bool] = []
    mutating func begin(_ plan: HaloRenderPlan) throws {}
    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
        names.append(fileName)
        sizes.insert([frame.pixels.width, frame.pixels.height])
    }
    mutating func finish(cancelled: Bool) throws { finished.append(cancelled) }
}

/// `run` over a fresh sink, opened as `some RenderSink`.
func runRender(
    _ rendering: any CompositionRendering, _ plan: HaloRenderPlan, isCancelled: () -> Bool
) -> (HaloRenderOutcome, RecordingSink) {
    var sink = RecordingSink()
    let outcome = rendering.run(plan, of: keyedPair(), text: nil, into: &sink, isCancelled: isCancelled)
    return (outcome, sink)
}

@Test(arguments: compositionRenderings)
func renderRunsEveryFrameAtThePlanSize(rendering: any CompositionRendering) throws {
    let plan = try rendering.plan(keyedPair(), settings: HaloRenderSettings(format: .pngSequence, halfSize: true))
    #expect((plan.width, plan.height, plan.framesPerSecond) == (200, 100, 24))
    let (outcome, sink) = runRender(rendering, plan) { false }
    #expect(outcome == .finished(frames: 60))
    #expect(sink.names.count == 60)
    #expect(sink.names.first == "Intro_0001.png" && sink.names.last == "Intro_0060.png")
    #expect(sink.sizes == [[200, 100]])
    #expect(sink.finished == [false])
}

@Test(arguments: compositionRenderings)
func renderAMovieIsOneNameAtFullSize(rendering: any CompositionRendering) throws {
    let plan = try rendering.plan(keyedPair(), settings: HaloRenderSettings(format: .movie))
    #expect(plan.fileNames == ["Intro.mp4"])
    #expect(plan.frames == Array(0..<60))
    #expect((plan.width, plan.height) == (400, 200))
}

@Test(arguments: compositionRenderings)
func renderStopsAtCancelAndWritesNothingAfter(rendering: any CompositionRendering) throws {
    let plan = try rendering.plan(keyedPair(), settings: HaloRenderSettings(format: .pngSequence))
    var asked = 0
    let (outcome, sink) = runRender(rendering, plan) {
        asked += 1
        return asked > 3
    }
    #expect(outcome == .cancelled(frames: 3))
    #expect(sink.names == ["Intro_0001.png", "Intro_0002.png", "Intro_0003.png"])
    #expect(sink.finished == [true])
}

@Test(arguments: compositionRenderings)
func renderPlanRefusesACompositionWithNoFrames(rendering: any CompositionRendering) {
    var comp = keyedPair()
    comp.durationFrames = 0
    #expect(throws: HaloEditError.noComposition) {
        try rendering.plan(comp, settings: HaloRenderSettings(format: .movie))
    }
}
