// HaloWindow+Playback.swift: the playback area's routes and hook
// (viewer-playback #37, VP-10). Set In Point, Set Out Point and moving the
// playhead call the Model, which refuses with no layer selected. Play/Pause
// (Space, the transport, Animation > Play/Pause) plays from `now` on the
// media clock, `CACurrentMediaTime()`, the clock the display link's target
// timestamps use, so the first tick lines up with play. Loop flips the
// Model's loop flag; ← and → step a frame, Home and End jump; the transport's
// driver sends `.tick(now)` each refresh. A tick or a ruler scrub writes the
// Model only when the Model says it changes something, so a refresh or drag
// sample between two frames writes nothing (#1296). A playing tick or a ruler
// scrub goes to HaloLiveEdit's `playing`, redrawing the viewer and playhead,
// not the window (#4274, #4448), as HaloLivePlayhead decides; `takePlayback`
// writes it back before any other command, when play-once ends and once a
// ruler drag rests `HaloLivePlayhead.settle` seconds. Playback is never an
// undo step.
// `playbackScene(_:)` adds nothing.
import HaloModel
import QuartzCore
import SwiftUI

extension HaloWindow {
    func playbackPerform(_ command: HaloCommand) {
        switch command {
        case .setInPoint: _ = model.setSelectedLayerInPoint()
        case .setOutPoint: _ = model.setSelectedLayerOutPoint()
        case .scrub(let frame):
            showLive(.scrub(frame: frame))
            live.settle(after: HaloLivePlayhead.settle) { takePlayback() }
        case .playPause: model.togglePlay(at: CACurrentMediaTime())
        case .toggleLoop: model.setLoops(!model.playback.loops)
        case .nextFrame: model.stepFrame(by: 1)
        case .previousFrame: model.stepFrame(by: -1)
        case .goToStart: model.goToStart()
        case .goToEnd: model.goToEnd()
        case .tick(let now): showLive(.tick(now: now))
        default: break
        }
    }

    func playbackScene(_ content: some View) -> some View { content }

    /// Shows `step` live; the window's project changes only when the Model
    /// says so (another kind of step pending, or play-once's end).
    private func showLive(_ step: HaloLivePlayhead.Step) {
        guard let outcome = live.playhead.apply(step, model: model, shown: live.playing) else { return }
        if live.playing != outcome.shown { live.playing = outcome.shown }
        if let write = outcome.write { model = write }
    }

    /// Writes the frame shown live (playing or scrubbed) into the window's
    /// project, so a command or an edit acts at the frame on screen; nothing
    /// with no frame live.
    func takePlayback() {
        live.cancelSettle()
        guard live.playhead.pending != nil else { return }
        let next = live.playhead.take(model)
        live.playing = nil
        if let next { model = next }
    }
}
