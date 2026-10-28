// HaloMovieSinkTests.swift: export-pack HX-4, a movie render written through
// the suite's media service. Bounce on the fake services at half size
// (960 × 540) into FakeMedia: every planned frame reaches the movie in order
// with the plan's size, rate and codec; a frame's alpha reaches it only when
// the plan keeps alpha; Cancel deletes the movie; an unavailable service
// fails in its own sentence; and ProRes 4444 and HEVC need a whole frame
// rate. Linux and macOS.
import HaloModel
import SuiteKernel
import SuiteModel
import Testing

@Suite struct HaloMovieSinkTests {
    private static let path = "/renders/Bounce.mp4"
    /// The right edge's middle at 960 × 540, where Bounce draws nothing.
    private static let empty = (x: 959, y: 270)

    /// Bounce's composition and its half-size plan for `settings`, cut to `frames`.
    private static func bounce(
        _ settings: HaloRenderSettings, frames: [Int] = [0, 12, 24]
    ) throws -> (HaloComposition, HaloRenderPlan, any CompositionRendering) {
        let project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let comp = try #require(project.selectedComposition)
        let rendering = project.services.compositionRendering
        var halved = settings
        halved.halfSize = true
        var plan = try rendering.plan(comp, settings: halved)
        plan.frames = frames
        return (comp, plan, rendering)
    }

    /// The bytes of the pixel at `point` in `frame`.
    private static func pixel(_ frame: MediaFrame, _ point: (x: Int, y: Int)) -> [UInt8] {
        let start = (point.y * frame.width + point.x) * 4
        guard start >= 0, start + 4 <= frame.rgba.count else { return [] }
        return Array(frame.rgba[start..<start + 4])
    }

    @Test func everyFrameReachesTheMovieInOrder() async throws {
        let (comp, plan, rendering) = try Self.bounce(HaloRenderSettings(format: .movie))
        let media = FakeMedia()
        var written: [Int] = []
        let outcome = await rendering.writeMovie(
            plan, of: comp, text: nil, media: media, path: Self.path, onWrite: { written.append($0) },
            isCancelled: { false })
        #expect(outcome == .finished(frames: 3))
        #expect(written == [1, 2, 3])
        #expect(media.settings[Self.path] == MovieSettings(width: 960, height: 540, fps: 24, codec: .h264, quality: 1))
        let frames = try #require(media.movies[Self.path])
        #expect(frames.count == 3)

        var reversed = plan
        reversed.frames = plan.frames.reversed()
        let backwards = FakeMedia()
        _ = await rendering.writeMovie(
            reversed, of: comp, text: nil, media: backwards, path: Self.path, isCancelled: { false })
        #expect(backwards.movies[Self.path] == frames.reversed(), "frames reached the movie out of order")
    }

    @Test func alphaReachesTheMovieOnlyWhenThePlanKeepsIt() async throws {
        for alpha in [true, false] {
            let (comp, plan, rendering) = try Self.bounce(
                HaloRenderSettings(format: .movie, codec: .prores4444, alpha: alpha), frames: [0])
            let media = FakeMedia()
            _ = await rendering.writeMovie(plan, of: comp, text: nil, media: media, path: Self.path, isCancelled: { false })
            let frame = try #require(media.movies[Self.path]?.first)
            let expected: [UInt8] = alpha ? [0, 0, 0, 0] : [0, 0, 0, 255]
            #expect(Self.pixel(frame, Self.empty) == expected, "alpha \(alpha): the empty pixel reached the movie wrong")
        }
    }

    @Test func cancelDeletesTheMovie() async throws {
        let (comp, plan, rendering) = try Self.bounce(HaloRenderSettings(format: .movie))
        let media = FakeMedia()
        var written = 0
        let outcome = await rendering.writeMovie(
            plan, of: comp, text: nil, media: media, path: Self.path, onWrite: { written = $0 },
            isCancelled: { written >= 1 })
        #expect(outcome == .cancelled(frames: 1))
        #expect(media.movies[Self.path] == nil, "a cancelled movie was kept")
        #expect(media.cancelled == [Self.path])
    }

    @Test func anUnavailableServiceFailsInItsOwnSentence() async throws {
        let (comp, plan, rendering) = try Self.bounce(HaloRenderSettings(format: .movie))
        let media = FakeMedia(unavailable: "Movies can't be written on this Mac.")
        let outcome = await rendering.writeMovie(
            plan, of: comp, text: nil, media: media, path: Self.path, isCancelled: { false })
        #expect(outcome == .failed(frame: 0, message: "Movies can't be written on this Mac."))
    }

    @Test func proResAndHevcNeedAWholeFrameRate() throws {
        let project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        var comp = try #require(project.selectedComposition)
        comp.frameRate = FrameRate(numerator: 30000, denominator: 1001)
        let rendering = project.services.compositionRendering
        #expect(throws: HaloEditError.refused("ProRes 4444 needs a whole-number frame rate. Choose H.264 for 29.97 fps.")) {
            try rendering.plan(comp, settings: HaloRenderSettings(format: .movie, codec: .prores4444))
        }
        #expect(throws: HaloEditError.refused("HEVC needs a whole-number frame rate. Choose H.264 for 29.97 fps.")) {
            try rendering.plan(comp, settings: HaloRenderSettings(format: .movie, codec: .hevc))
        }
        let h264 = try rendering.plan(comp, settings: HaloRenderSettings(format: .movie))
        #expect(h264.movie == nil, "a 29.97 fps H.264 movie was planned for the media service")
        let whole = try rendering.plan(
            try #require(project.selectedComposition), settings: HaloRenderSettings(format: .movie, codec: .hevc))
        #expect(whole.movie?.codec == .hevc)
    }
}
