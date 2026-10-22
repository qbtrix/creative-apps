// HaloWindow+Playback.swift: the playback area's routes and hook
// (viewer-playback #37, VP-10). Set In Point, Set Out Point and moving the
// playhead call the Model, which refuses with no layer selected. Play/Pause
// (Space, the transport, Animation > Play/Pause) plays from `now` on the
// media clock, `CACurrentMediaTime()`, the clock the display link's target
// timestamps use, so the first tick lines up with play. Loop flips the
// Model's loop flag; ← and → step a frame, Home and End jump; the transport's
// driver sends `.tick(now)` each refresh. A tick or a ruler scrub writes the
// Model only when the Model says it changes something, so a refresh or drag
// sample between two frames writes nothing (#1296). A playing tick goes to
// HaloLiveEdit's `playing`, redrawing the viewer and playhead, not the window
// (#4274); `takePlayback` writes it back before any other command and when
// play-once ends. Playback is never an undo step.
// `playbackScene(_:)` adds nothing.
import HaloModel
import QuartzCore
import SwiftUI

extension HaloWindow {
    func playbackPerform(_ command: HaloCommand) {
        switch command {
        case .setInPoint: _ = model.setSelectedLayerInPoint()
        case .setOutPoint: _ = model.setSelectedLayerOutPoint()
        case .scrub(let frame): if model.scrubChanges(to: frame) { model.scrub(to: frame) }
        case .playPause: model.togglePlay(at: CACurrentMediaTime())
        case .toggleLoop: model.setLoops(!model.playback.loops)
        case .nextFrame: model.stepFrame(by: 1)
        case .previousFrame: model.stepFrame(by: -1)
        case .goToStart: model.goToStart()
        case .goToEnd: model.goToEnd()
        case .tick(let now):
            var next = model
            next.tick(now: now)
            guard next != (live.playing ?? model) else { return }
            if next.playback.playing {
                (live.playing, live.playedAt) = (next, now)
            } else {
                (live.playing, live.playedAt) = (nil, nil)
                model.tick(now: now)
            }
        default: break
        }
    }

    func playbackScene(_ content: some View) -> some View { content }

    /// Writes the frame playing now into the window's project, so a command
    /// or an edit acts at the frame on screen; nothing while paused.
    func takePlayback() {
        guard let now = live.playedAt else { return }
        (live.playing, live.playedAt) = (nil, nil)
        if model.tickChanges(now: now) { model.tick(now: now) }
    }
}
