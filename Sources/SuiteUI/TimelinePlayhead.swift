// TimelinePlayhead.swift: the playhead line TimelineStrip lays over its ruler
// and lanes: a 1 pt accent line at the current frame's tick. It takes no
// pointer events; the strip turns hit testing off.
import SwiftUI

struct TimelinePlayhead: View {
    let mapping: FrameMapping
    let playhead: Int

    #if DEBUG
    /// How many times a playhead's body ran; the real-window budget tests count a scrub's.
    static var bodyRuns = 0
    #endif

    var body: some View {
        #if DEBUG
        Self.bodyRuns += 1
        #endif
        let x = tickX(mapping, playhead)
        return Canvas { context, size in
            let line = CGRect(x: x - 0.5, y: 0, width: 1, height: size.height)
            context.fill(Path(line), with: .color(SuiteColor.accent))
        }
    }
}
