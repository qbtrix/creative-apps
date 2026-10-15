// HaloWindow+Playback.swift: the playback area's routes and hook. Set In
// Point, Set Out Point and moving the playhead are shipped and call the
// Model, which refuses with no layer selected; the transport (Play/Pause,
// Loop, the frame steps, Go to Start and End, the tick) is not built yet, so
// those do nothing. viewer-playback (#37) replaces this file whole, keeping
// the three shipped routes. `playbackScene(_:)` adds nothing yet.
import HaloModel
import SwiftUI

extension HaloWindow {
    func playbackPerform(_ command: HaloCommand) {
        switch command {
        case .setInPoint: _ = model.setSelectedLayerInPoint()
        case .setOutPoint: _ = model.setSelectedLayerOutPoint()
        case .scrub(let frame): model.scrub(to: frame)
        default: break
        }
    }

    func playbackScene(_ content: some View) -> some View { content }
}
