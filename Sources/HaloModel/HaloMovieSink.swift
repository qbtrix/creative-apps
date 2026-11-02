// HaloMovieSink.swift: Render Out's movie through the suite's media service
// (export-pack HX-4). `HaloMovieSink` is the RenderSink that opens
// `media.movie(at:_:)` with the plan's settings on `begin`, appends each
// frame's 8-bit sRGB bytes (straight alpha, already flattened over black when
// the plan is opaque) and reports the count, and cancels the movie, which
// deletes it, when the run is cancelled or fails. A FrameSink's `finish` is
// async and RenderSink's isn't, so `writeMovie` runs the frame loop and then
// awaits `close()`; a movie that fails to close fails the render at its last
// frame. Linux-safe.
import CoreRaster
import SuiteModel

struct HaloMovieSink: RenderSink {
    let media: any MediaEncoding
    let path: String
    let onWrite: (Int) -> Void
    private var movie: (any FrameSink)?
    private var written = 0

    init(media: any MediaEncoding, path: String, onWrite: @escaping (Int) -> Void) {
        self.media = media; self.path = path; self.onWrite = onWrite
    }

    mutating func begin(_ plan: HaloRenderPlan) throws {
        guard let settings = plan.movie else {
            throw HaloEditError.refused("A \(plan.frameRate) movie is written as H.264 by Halo's own writer.")
        }
        movie = try media.movie(at: path, settings)
    }

    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
        guard let movie else { return }
        let bytes = try frame.pixels.rgba8(colorSpace: .sRGB)
        try movie.append(MediaFrame(width: frame.pixels.width, height: frame.pixels.height, rgba: bytes))
        written += 1
        onWrite(written)
    }

    mutating func finish(cancelled: Bool) throws {
        guard cancelled else { return }
        movie?.cancel()
        movie = nil
    }

    /// Closes the movie once every frame is in.
    func close() async throws(SuiteError) {
        try await movie?.finish()
    }
}

extension CompositionRendering {
    /// Renders every planned frame into one movie at `path` through `media`,
    /// reporting each written frame's count to `onWrite` and checking
    /// `isCancelled` before each frame. Cancel or a failure deletes the movie.
    public func writeMovie(
        _ plan: HaloRenderPlan, of composition: HaloComposition, text: (any TextRasterizing)?,
        media: any MediaEncoding, path: String, onWrite: @escaping (Int) -> Void = { _ in },
        isCancelled: () -> Bool
    ) async -> HaloRenderOutcome {
        var sink = HaloMovieSink(media: media, path: path, onWrite: onWrite)
        let outcome = run(plan, of: composition, text: text, into: &sink, isCancelled: isCancelled)
        guard case .finished = outcome else { return outcome }
        do { try await sink.close() } catch {
            try? sink.finish(cancelled: true)
            return .failed(frame: plan.frames.last ?? 0, message: error.message)
        }
        return outcome
    }
}
