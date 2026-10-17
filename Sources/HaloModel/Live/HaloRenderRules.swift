// Live/HaloRenderRules.swift: the one render-to-files rule (#429), shared by
// LiveCompositionRendering and FakeCompositionRendering so the two can't
// drift apart. `plan` sizes and names the files: half size halves and rounds
// down to even (at least 2), a movie rounds its full size down to even (H.264
// needs even sizes), a PNG sequence keeps the exact size; the base name is
// SuiteModel's UniqueFileNames stem ("/" and ":" become "-", empty is
// "Untitled"), and only the "_0001" frame suffix is Halo's. `run` is the frame
// loop: it checks `isCancelled` before each frame, renders it with `drawing`
// and `rendering`, writes it, and stops at the first error. Linux-safe.
import SuiteModel

enum HaloRenderRules {
    /// The frames, size and file names for `s`. Throws `.noComposition` for a
    /// composition with no frames.
    static func plan(_ c: HaloComposition, _ s: HaloRenderSettings) throws -> HaloRenderPlan {
        guard c.durationFrames > 0 else { throw HaloEditError.noComposition }
        let even = { (n: Int) in max(2, n / 2 * 2) }
        let (w, h): (Int, Int) =
            if s.halfSize { (even(c.width / 2), even(c.height / 2)) }
            else if s.format == .movie { (even(c.width), even(c.height)) }
            else { (c.width, c.height) }
        let frames = Array(0..<c.durationFrames)
        let base = UniqueFileNames.name(c.name, extension: "", among: [])
        let names: [String] = switch s.format {
        case .movie: ["\(base).mp4"]
        case .pngSequence: frames.map { "\(base)_\(pad4($0 + 1)).png" }
        }
        return HaloRenderPlan(width: w, height: h, framesPerSecond: c.framesPerSecond, frames: frames, fileNames: names)
    }

    /// Sends every planned frame to `sink` in order and says how it ended.
    /// Cancel stops before the next frame; a render or sink error stops at
    /// that frame. Either way the sink is finished with `cancelled: true`.
    static func run(
        _ plan: HaloRenderPlan, of c: HaloComposition, text: (any TextRasterizing)?,
        drawing: any FrameDrawing, rendering: any FrameRendering,
        into sink: inout some RenderSink, isCancelled: () -> Bool
    ) -> HaloRenderOutcome {
        do { try sink.begin(plan) } catch { return .failed(frame: plan.frames.first ?? 0, message: words(error)) }
        for (i, frame) in plan.frames.enumerated() {
            if isCancelled() {
                try? sink.finish(cancelled: true)
                return .cancelled(frames: i)
            }
            do {
                let image = try rendering.render(
                    drawing.drawList(c, at: frame), width: plan.width, height: plan.height, text: text)
                try sink.write(image, named: name(plan, i))
            } catch {
                try? sink.finish(cancelled: true)
                return .failed(frame: frame, message: words(error))
            }
        }
        do { try sink.finish(cancelled: false) } catch {
            return .failed(frame: plan.frames.last ?? 0, message: words(error))
        }
        return .finished(frames: plan.frames.count)
    }

    /// The name of the `i`th planned frame: its own for a PNG sequence, the
    /// one movie name otherwise.
    static func name(_ plan: HaloRenderPlan, _ i: Int) -> String {
        if plan.fileNames.count == plan.frames.count, plan.fileNames.indices.contains(i) { return plan.fileNames[i] }
        return plan.fileNames.first ?? ""
    }

    /// An error in words: a HaloEditError's message, else its description.
    static func words(_ failure: any Error) -> String {
        (failure as? HaloEditError)?.message ?? String(describing: failure)
    }

    /// `n` with leading zeros to four digits: 1 is "0001", 12345 stays.
    static func pad4(_ n: Int) -> String {
        let digits = String(n)
        return String(repeating: "0", count: max(0, 4 - digits.count)) + digits
    }
}
