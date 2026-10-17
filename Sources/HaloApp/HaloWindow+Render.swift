// HaloWindow+Render.swift: the render area's routes and hook. Render Frame
// (⌘R, render-out RO-5, #451) calls the Model's `renderCurrentFrame()`, and
// the viewer shows the frame (HaloRenderedFrameView). Render… (⇧⌘R), Cancel
// Render and Close call the Model's render job (#429), and `renderScene(_:)`
// presents HaloRenderSheet while the Model has a render job (RO-8). The
// sheet's Render calls `renderStart(_:into:)`: the Model plans the render, a
// detached task writes the frames through the PNG or movie writer off the
// main actor, and its progress and outcome come back over a stream that a
// main-actor task hands to the Model's `renderProgress(frame:)` and
// `finishRender(_:)`. `.startRender` from a menu does nothing: only the sheet
// knows the destination folder, so only the sheet starts a render.
import HaloModel
import SwiftUI

extension HaloWindow {
    func renderPerform(_ command: HaloCommand) {
        switch command {
        case .renderFrame: model.renderCurrentFrame()
        case .openRenderSheet: model.openRenderSheet()
        case .cancelRender: model.cancelRender()
        case .closeRenderSheet: model.closeRenderSheet()
        default: break
        }
    }

    func renderScene(_ content: some View) -> some View {
        content.sheet(
            isPresented: Binding(get: { model.renderJob != nil }, set: { if !$0 { model.closeRenderSheet() } })
        ) {
            HaloRenderSheet(
                model: model, destination: HaloLaunch.current.renderTo.map { URL(fileURLWithPath: $0) },
                onRender: { renderStart($0, into: $1) }, onCommand: { perform($0) })
        }
    }

    /// Starts rendering the selected composition into `folder`; nil when the
    /// Model refuses (the sheet then shows why).
    func renderStart(_ settings: HaloRenderSettings, into folder: URL) -> HaloRenderRun? {
        let existing = HaloRenderRun.names(in: folder)
        guard let name = model.renderOutputName(settings, existing: existing),
            let started = model.startRender(settings)
        else { return nil }
        let (plan, composition) = (started.plan, started.composition)
        let output = folder.appending(path: name, directoryHint: settings.format == .movie ? .notDirectory : .isDirectory)
        let rendering = model.services.compositionRendering
        let text = model.services.text
        let (events, continuation) = AsyncStream.makeStream(of: HaloRenderRun.Event.self)
        let worker = Task.detached(priority: .userInitiated) {
            let report: (Int) -> Void = { continuation.yield(.progress($0)) }
            let outcome: HaloRenderOutcome
            switch settings.format {
            case .pngSequence:
                var sink = HaloRenderProgress(base: HaloPNGWriter(folder: output), onWrite: report)
                outcome = rendering.run(plan, of: composition, text: text, into: &sink, isCancelled: { Task.isCancelled })
            case .movie:
                var sink = HaloRenderProgress(base: HaloMovieWriter(url: output), onWrite: report)
                outcome = rendering.run(plan, of: composition, text: text, into: &sink, isCancelled: { Task.isCancelled })
            }
            continuation.yield(.ended(outcome))
            continuation.finish()
        }
        Task { @MainActor in
            for await event in events {
                switch event {
                case .progress(let frame): model.renderProgress(frame: frame)
                case .ended(let outcome): model.finishRender(outcome)
                }
            }
        }
        return HaloRenderRun(worker: worker, output: output)
    }
}

/// A started render: the detached task writing it, cancelled by the sheet
/// when the Model's job ends as cancelled, and what it writes (the folder of
/// PNGs or the movie file), which Reveal in Finder selects.
struct HaloRenderRun {
    enum Event: Sendable {
        case progress(Int)
        case ended(HaloRenderOutcome)
    }

    let worker: Task<Void, Never>
    let output: URL

    /// What `folder` holds, so a render never writes over an earlier one.
    static func names(in folder: URL?) -> Set<String> {
        guard let folder else { return [] }
        return Set((try? FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false))) ?? [])
    }
}

/// Passes every call to `base` and reports how many frames are written.
struct HaloRenderProgress<Base: RenderSink>: RenderSink {
    var base: Base
    let onWrite: (Int) -> Void
    var written = 0

    mutating func begin(_ plan: HaloRenderPlan) throws { try base.begin(plan) }

    mutating func write(_ frame: HaloRenderedFrame, named fileName: String) throws {
        try base.write(frame, named: fileName)
        written += 1
        onWrite(written)
    }

    mutating func finish(cancelled: Bool) throws { try base.finish(cancelled: cancelled) }
}
