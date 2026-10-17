// HaloRenderPlanTests.swift: HaloRenderRules through `.fake` and `.live`
// (#429, RO-1): the plan's sizes (half even and at least 2, a movie even at
// full size, a PNG sequence exact), its file names (four-digit frames, "/"
// and ":" made "-"), and the frame loop's cancel and error stops. Runs on
// Linux and macOS.
import HaloModel
import Testing

let planRenderings: [any CompositionRendering] = [
    HaloServices.fake.compositionRendering, HaloServices.live.compositionRendering,
]

/// What a sink saw, shared with the test's `isCancelled` closure.
final class SinkLog {
    var names: [String] = []
    var frames: [HaloRenderedFrame] = []
    var finished: [Bool] = []
}

/// A sink that logs every call and throws `failure` when asked to write
/// frame `failAt`, or from `begin` or `finish` when those flags are set.
struct LoggingSink: RenderSink {
    let log: SinkLog
    var failAt: Int?
    var failure: HaloEditError = .notBuilt("x")
    var failBegin = false
    var failFinish = false
    mutating func begin(_ plan: HaloRenderPlan) throws { if failBegin { throw failure } }
    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
        if frame.frame == failAt { throw failure }
        log.names.append(fileName)
        log.frames.append(frame)
    }
    mutating func finish(cancelled: Bool) throws {
        log.finished.append(cancelled)
        if failFinish { throw failure }
    }
}

/// A composition `name`, `width` × `height`, 24 fps, `frames` long, with keyedPair's layers.
private func comp(_ name: String = "Intro", _ width: Int = 400, _ height: Int = 200, frames: Int = 48) -> HaloComposition {
    var c = keyedPair()
    c.name = name; c.width = width; c.height = height; c.durationFrames = frames
    return c
}

private func keyed() throws -> HaloComposition {
    try #require(HaloFixtures.project("keyed")?.compositions.first)
}

private func size(_ r: any CompositionRendering, _ c: HaloComposition, _ format: HaloRenderSettings.Format, half: Bool)
    throws -> [Int]
{
    let plan = try r.plan(c, settings: HaloRenderSettings(format: format, halfSize: half))
    return [plan.width, plan.height]
}

@Test(arguments: planRenderings)
func planSendsEveryFrameInOrderWithFourDigitNames(rendering: any CompositionRendering) throws {
    let c = comp()
    let plan = try rendering.plan(c, settings: HaloRenderSettings(format: .pngSequence, halfSize: true))
    #expect(plan.frames == Array(0..<48))
    #expect(plan.framesPerSecond == 24)
    let log = SinkLog()
    var sink = LoggingSink(log: log)
    #expect(rendering.run(plan, of: c, text: nil, into: &sink, isCancelled: { false }) == .finished(frames: 48))
    #expect(log.frames.map(\.frame) == Array(0..<48))
    #expect(log.names == (1...48).map { $0 < 10 ? "Intro_000\($0).png" : "Intro_00\($0).png" })
    #expect(log.names.first == "Intro_0001.png" && log.names.last == "Intro_0048.png")
    #expect(Set(log.frames.map { [$0.pixels.width, $0.pixels.height] }) == [[200, 100]])
    #expect(log.finished == [false])
}

@Test(arguments: planRenderings)
func planSizesHalfEvenAndMovieEvenAtFullSize(rendering: any CompositionRendering) throws {
    #expect(try size(rendering, keyed(), .pngSequence, half: true) == [960, 540])
    #expect(try size(rendering, keyed(), .movie, half: true) == [960, 540])
    let odd = comp("Odd", 1081, 721)
    #expect(try size(rendering, odd, .pngSequence, half: true) == [540, 360])
    #expect(try size(rendering, odd, .movie, half: true) == [540, 360])
    #expect(try size(rendering, odd, .movie, half: false) == [1080, 720])
    #expect(try size(rendering, odd, .pngSequence, half: false) == [1081, 721])
    let tiny = comp("Tiny", 3, 3)
    #expect(try size(rendering, tiny, .pngSequence, half: true) == [2, 2])
    #expect(try size(rendering, tiny, .movie, half: false) == [2, 2])
}

@Test(arguments: planRenderings)
func planNamesOneMovieAndSanitizesTheBase(rendering: any CompositionRendering) throws {
    let movie = try rendering.plan(keyed(), settings: HaloRenderSettings(format: .movie))
    #expect(movie.fileNames == ["Bounce.mp4"])
    #expect(movie.frames == Array(0..<48))
    let png = HaloRenderSettings(format: .pngSequence)
    #expect(try rendering.plan(comp("A/B"), settings: png).fileNames.first == "A-B_0001.png")
    #expect(try rendering.plan(comp("A:B"), settings: png).fileNames.first == "A-B_0001.png")
    #expect(try rendering.plan(comp(""), settings: png).fileNames.first == "Untitled_0001.png")
    #expect(try rendering.plan(comp("A/B"), settings: HaloRenderSettings(format: .movie)).fileNames == ["A-B.mp4"])
}

@Test(arguments: planRenderings)
func runStopsOnceTenFramesAreWritten(rendering: any CompositionRendering) throws {
    let c = comp()
    let plan = try rendering.plan(c, settings: HaloRenderSettings(format: .pngSequence, halfSize: true))
    let log = SinkLog()
    var sink = LoggingSink(log: log)
    let outcome = rendering.run(plan, of: c, text: nil, into: &sink, isCancelled: { log.names.count >= 10 })
    #expect(outcome == .cancelled(frames: 10))
    #expect(log.names.count == 10)
    #expect(log.names.last == "Intro_0010.png")
    #expect(log.finished == [true])
}

@Test(arguments: planRenderings)
func runStopsAtTheFrameASinkRefuses(rendering: any CompositionRendering) throws {
    let c = comp()
    let plan = try rendering.plan(c, settings: HaloRenderSettings(format: .pngSequence, halfSize: true))
    let log = SinkLog()
    var sink = LoggingSink(log: log, failAt: 5)
    let outcome = rendering.run(plan, of: c, text: nil, into: &sink, isCancelled: { false })
    #expect(outcome == .failed(frame: 5, message: HaloEditError.notBuilt("x").message))
    #expect(log.frames.map(\.frame) == [0, 1, 2, 3, 4])
    #expect(log.finished == [true])
}

@Test(arguments: planRenderings)
func runReportsBeginAndFinishErrors(rendering: any CompositionRendering) throws {
    let c = comp()
    let plan = try rendering.plan(c, settings: HaloRenderSettings(format: .movie, halfSize: true))
    let begun = SinkLog()
    var refusesBegin = LoggingSink(log: begun, failBegin: true)
    #expect(
        rendering.run(plan, of: c, text: nil, into: &refusesBegin, isCancelled: { false })
            == .failed(frame: 0, message: HaloEditError.notBuilt("x").message))
    #expect(begun.names.isEmpty && begun.finished.isEmpty)
    let ended = SinkLog()
    var refusesFinish = LoggingSink(log: ended, failure: .emptyName, failFinish: true)
    #expect(
        rendering.run(plan, of: c, text: nil, into: &refusesFinish, isCancelled: { false })
            == .failed(frame: 47, message: HaloEditError.emptyName.message))
    #expect(ended.names == Array(repeating: "Intro.mp4", count: 48))
    #expect(ended.finished == [false])
}

@Test func liveRenderingWorksThroughTheLiveFrameRenderer() throws {
    #expect(HaloServices.live.compositionRendering.unavailableHelp == nil)
    let c = comp(frames: 8)
    let plan = try LiveCompositionRendering().plan(c, settings: HaloRenderSettings(format: .pngSequence, halfSize: true))
    let log = SinkLog()
    var sink = LoggingSink(log: log)
    _ = LiveCompositionRendering().run(plan, of: c, text: nil, into: &sink, isCancelled: { false })
    let expected = try (0..<8).map {
        try LiveFrameRendering().render(LiveFrameDrawing().drawList(c, at: $0), width: 200, height: 100, text: nil)
    }
    #expect(log.frames == expected)
}
