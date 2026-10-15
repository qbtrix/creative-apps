// Fakes/FakeCompositionRendering.swift: a small, predictable
// CompositionRendering (#429). It plans every frame (half size rounds down to
// an even number, at least 2), draws each with FakeFrameDrawing and
// FakeFrameRendering, and stops before the next frame once `isCancelled`.
// Linux-safe; never used by `.live`.

public struct FakeCompositionRendering: CompositionRendering {
    public init() {}
    public func plan(_ composition: HaloComposition, settings: HaloRenderSettings) throws -> HaloRenderPlan {
        guard composition.durationFrames > 0 else { throw HaloEditError.noComposition }
        let half = { (n: Int) in max(2, n / 2 / 2 * 2) }
        let w = settings.halfSize ? half(composition.width) : composition.width
        let h = settings.halfSize ? half(composition.height) : composition.height
        let frames = Array(0..<composition.durationFrames)
        let names: [String] = switch settings.format {
        case .movie: ["\(composition.name).mp4"]
        case .pngSequence: frames.map { f in
            let n = String(f + 1)
            return "\(composition.name)_\(String(repeating: "0", count: max(0, 4 - n.count)))\(n).png"
        }
        }
        return HaloRenderPlan(width: w, height: h, framesPerSecond: composition.framesPerSecond, frames: frames, fileNames: names)
    }

    public func run(
        _ plan: HaloRenderPlan, of composition: HaloComposition, text: (any TextRasterizing)?,
        into sink: inout some RenderSink, isCancelled: () -> Bool
    ) -> HaloRenderOutcome {
        do { try sink.begin(plan) } catch { return .failed(frame: 0, message: "\(error)") }
        for (i, frame) in plan.frames.enumerated() {
            if isCancelled() {
                try? sink.finish(cancelled: true)
                return .cancelled(frames: i)
            }
            do {
                let list = FakeFrameDrawing().drawList(composition, at: frame)
                let image = try FakeFrameRendering().render(list, width: plan.width, height: plan.height, text: text)
                let name = plan.fileNames.count == plan.frames.count ? plan.fileNames[i] : plan.fileNames.first ?? ""
                try sink.write(image, named: name)
            } catch {
                try? sink.finish(cancelled: true)
                return .failed(frame: frame, message: "\(error)")
            }
        }
        do { try sink.finish(cancelled: false) } catch { return .failed(frame: plan.frames.last ?? 0, message: "\(error)") }
        return .finished(frames: plan.frames.count)
    }
}
