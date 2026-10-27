// FlareExport+Kernel.swift: the export sheet's run transitions over the kernel's `ExportRun`
// (docs/blueprints/flare/features/flare-export.md, Contract slice and Pseudocode). Every move delegates to the run:
// it holds the state, clamps progress and keeps a running run open (rule 20); this file only says which move each
// sheet action is and when the sheet may make it. `FlareVideoPlan` (export-pack FV-3) plans an MP4 or GIF run's
// frames on SuiteModel's FrameClock and ExportRules' size.
import FlareCore
import SuiteKernel
import SuiteModel

extension FlareWorkspace {
    /// The run's options in every state but idle.
    public var exportingOptions: ExportOptions? {
        switch exportState {
        case .idle: nil
        case .editing(let o), .running(let o, _, _), .finished(let o, _), .failed(let o, _): o
        }
    }

    /// Idle to editing on the SVG frame defaults; false (and no change) with no document or a sheet already open.
    @discardableResult
    public mutating func openExport() -> Bool {
        guard case .idle = exportState, document != nil, let o = exportOptions(.svgFrame) else { return false }
        return exportState.begin(o)
    }

    /// Editing with no problem to running at 0 of `exportRunTotal`; false (and no change) otherwise.
    @discardableResult
    public mutating func startExport() -> Bool {
        guard exportProblem == nil else { return false }
        return exportState.start(total: exportRunTotal)
    }

    /// What a run counts: an MP4 or GIF run its plan's frames (one file, so the bar moves per frame), any other
    /// run its files (export-pack FV-5).
    var exportRunTotal: Int {
        guard exportingOptions?.format.writesVideo == true, let plan = try? exportVideoPlan() else { return exportFileCount }
        return plan.frames.count
    }

    /// Moves the running run to `fraction` of its total, rounded down; the run clamps and never goes back.
    /// Ignored unless running.
    public mutating func exportProgressed(_ fraction: Double) {
        guard case .running(_, done: _, total: let total) = exportState, !fraction.isNaN else { return }
        exportState.progressed(done: Int((min(max(fraction, 0), 1) * Double(total)).rounded(.down)))
    }

    /// Ends the running run: finished with the written names, idle after a cancel, failed with the sheet's sentence.
    public mutating func endExport(_ outcome: Result<[String], any Error>) {
        switch outcome {
        case .success(let names): exportState.end(.success(names))
        case .failure(let error as CancellationError): exportState.end(.failure(error))
        case .failure(let error): exportState.end(.failure(ExportRefusal(description: Self.exportMessage(error))))
        }
    }

    /// Failed back to editing with the same options; any other state stays.
    public mutating func retryExport() {
        guard case .failed(let o, _) = exportState else { return }
        _ = exportState.begin(o)
    }

    /// Closes an editing, finished or failed run; a running one stays until it ends.
    public mutating func dismissExport() { exportState.dismiss() }

    /// The frame plan of the sheet's MP4 or GIF run on its scene; throws when the sheet is closed, its scene is gone,
    /// or `FlareVideoPlan.plan` refuses the options.
    public func exportVideoPlan() throws -> FlareVideoPlan {
        guard let o = exportingOptions, let scene = scenes.first(where: { $0.id == o.sceneID }) else {
            throw ExportOptionRefusal.invalid("Open the export sheet on a scene first.")
        }
        return try FlareVideoPlan.plan(scene, options: o)
    }
}

/// One planned movie frame: its place in the file, the scene frame it renders, when it shows, and its GIF delay.
public struct FlareVideoFrame: Hashable, Sendable {
    /// 0 for the file's first frame.
    public let index: Int
    /// The scene time to render, in scene frames (fractional when the export rate differs from the scene's).
    public let sceneFrame: Double
    /// When the frame shows, from `FrameClock.seconds(of:)`.
    public let seconds: Double
    /// The frame's GIF delay in centiseconds, from `FrameClock.nextGIFDelay()`.
    public let delay: Int
}

/// What an MP4 or GIF export writes (export-pack FV-3): every frame of the scene at the export rate, at
/// `ExportRules.pixels` (even for MP4), GIF keeping the scene's transparency and looping, MP4 opaque. The writers are
/// SuiteModel's (rule 20); FV-4 renders `scene(_:)` at each frame and appends it to the sink `movie` or
/// `animatedImage` opens.
public struct FlareVideoPlan: Hashable, Sendable {
    public let format: ExportFormat
    public let width: Int, height: Int, fps: Int
    /// GIF only: true plays forever.
    public let loop: Bool
    /// MP4's frames are drawn on the scene's background, made opaque; a GIF's keep its alpha.
    public let fillsBackground: Bool
    public let frames: [FlareVideoFrame]

    /// MP4's writer settings: H.264 at quality 0.9; nil for GIF.
    public var movie: MovieSettings? {
        format == .mp4 ? MovieSettings(width: width, height: height, fps: fps, codec: .h264, quality: 0.9) : nil
    }

    /// GIF's writer settings: loop count 0 (forever) when looping, else 1; nil for MP4.
    public var animatedImage: AnimatedImageSettings? {
        format == .gif ? AnimatedImageSettings(width: width, height: height, fps: fps, format: .gif, loopCount: loop ? 0 : 1) : nil
    }

    /// `scene` as the frames draw it: its background opaque for MP4, clear for GIF.
    public func scene(_ scene: FlareScene) -> FlareScene {
        var drawn = scene
        drawn.background.a = fillsBackground ? 1 : 0
        return drawn
    }

    /// The plan for `options` (format mp4 or gif) on `scene`: frames 0..<n, n the scene's length at `options.fps`
    /// (the scene's rate when nil). Throws for another format, a rate below 1, or a size `ExportRules` refuses.
    public static func plan(_ scene: FlareScene, options: ExportOptions) throws -> FlareVideoPlan {
        let format = options.format
        guard format == .mp4 || format == .gif else {
            throw ExportOptionRefusal.invalid("Only MP4 and GIF have a frame plan.")
        }
        guard scene.fps >= 1 else { throw ExportOptionRefusal.invalid("The scene's frame rate must be at least 1.") }
        var clock = try FrameClock(fps: options.fps ?? scene.fps)
        let fps = clock.fps, sceneFPS = scene.fps
        let count = max(1, Int((Double(scene.durationFrames * fps) / Double(sceneFPS)).rounded()))
        let source = (width: Int(scene.width.rounded()), height: Int(scene.height.rounded()))
        let size = try ExportRules.pixels(of: source, options.size, evenSize: format == .mp4)
        var frames: [FlareVideoFrame] = []
        for i in (0..<count) {
            frames.append(FlareVideoFrame(index: i, sceneFrame: Double(i * sceneFPS) / Double(fps),
                                          seconds: clock.seconds(of: i), delay: clock.nextGIFDelay()))
        }
        return FlareVideoPlan(format: format, width: size.width, height: size.height, fps: fps, loop: options.loop,
                              fillsBackground: format == .mp4, frames: frames)
    }
}
