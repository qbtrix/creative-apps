// HaloWindow+Playback.swift: the playback area's routes and hook
// (viewer-playback #37, VP-10). Set In Point, Set Out Point and moving the
// playhead call the Model, which refuses with no layer selected. Play/Pause
// (Space, the transport, Animation > Play/Pause) plays from `now` on the
// media clock, `CACurrentMediaTime()`, the clock the display link's target
// timestamps use, so the first tick lines up with play. Loop flips the
// Model's loop flag; ← and → step a frame, Home and End jump; the transport's
// driver sends `.tick(now)` each refresh. Playback is never an undo step.
// `playbackScene(_:)` adds nothing.
import HaloModel
import QuartzCore
import SwiftUI

extension HaloWindow {
    func playbackPerform(_ command: HaloCommand) {
        switch command {
        case .setInPoint: _ = model.setSelectedLayerInPoint()
        case .setOutPoint: _ = model.setSelectedLayerOutPoint()
        case .scrub(let frame): model.scrub(to: frame)
        case .playPause: model.togglePlay(at: CACurrentMediaTime())
        case .toggleLoop: model.setLoops(!model.playback.loops)
        case .nextFrame: model.stepFrame(by: 1)
        case .previousFrame: model.stepFrame(by: -1)
        case .goToStart: model.goToStart()
        case .goToEnd: model.goToEnd()
        case .tick(let now): model.tick(now: now)
        default: break
        }
    }

    func playbackScene(_ content: some View) -> some View { content }
}
