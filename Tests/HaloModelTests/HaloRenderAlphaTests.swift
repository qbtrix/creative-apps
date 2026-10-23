// HaloRenderAlphaTests.swift: MJ-HX (export-pack HX-3), what a rendered
// movie frame holds where the composition draws nothing. Bounce on the fake
// services: Ball near the top, Floor across the bottom, nothing at the right
// edge's middle. With Transparent background on, that pixel stays clear
// (alpha 0) and Floor's stays opaque; with it off, a movie frame is opaque
// black there, as the movie shows it. A PNG sequence's frames are as they
// were. Linux and macOS.
import CoreRaster
import HaloModel
import SuiteModel
import Testing

/// A sink that keeps each frame's pixels at `points`.
struct PixelSink: RenderSink {
    var points: [(x: Int, y: Int)]
    var seen: [[RGBA]] = []
    mutating func begin(_ plan: HaloRenderPlan) throws {}
    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
        seen.append(try points.map { try frame.pixels.pixel(x: $0.x, y: $0.y) })
    }
    mutating func finish(cancelled: Bool) throws {}
}

@Suite struct HaloRenderAlphaTests {
    /// The right edge's middle (nothing drawn) and Floor's middle, at 1920 × 1080.
    private static let empty = (x: 1919, y: 540), floor = (x: 960, y: 1000)

    /// Frame 0 of Bounce rendered with `settings`: the empty pixel, then Floor's.
    private static func firstFrame(_ settings: HaloRenderSettings) throws -> [RGBA] {
        let project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let comp = try #require(project.selectedComposition)
        let rendering = project.services.compositionRendering
        var plan = try rendering.plan(comp, settings: settings)
        plan.frames = [0]
        var sink = PixelSink(points: [empty, floor])
        let outcome = rendering.run(plan, of: comp, text: nil, into: &sink, isCancelled: { false })
        #expect(outcome == .finished(frames: 1))
        return try #require(sink.seen.first)
    }

    @Test func alphaLeavesTheBackgroundClear() throws {
        let pixels = try Self.firstFrame(HaloRenderSettings(format: .movie, codec: .prores4444, alpha: true))
        #expect(pixels.first == .clear, "the background was drawn with Transparent background on")
        #expect(pixels.last?.a == 1, "Floor isn't opaque")
    }

    @Test func aMovieWithoutAlphaIsOpaqueBlackThere() throws {
        for codec in [MovieCodec.h264, .prores4444] {
            let pixels = try Self.firstFrame(HaloRenderSettings(format: .movie, codec: codec))
            #expect(pixels.first == RGBA(r: 0, g: 0, b: 0, a: 1), "\(codec): the background isn't opaque black")
            #expect(pixels.last?.a == 1, "\(codec): Floor isn't opaque")
        }
    }

    @Test func aPNGSequenceKeepsItsFrames() throws {
        for alpha in [false, true] {
            let pixels = try Self.firstFrame(HaloRenderSettings(format: .pngSequence, alpha: alpha))
            #expect(pixels.first == .clear, "alpha \(alpha): a PNG frame changed where nothing draws")
        }
    }
}
