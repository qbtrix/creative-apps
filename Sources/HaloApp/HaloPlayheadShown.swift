// HaloPlayheadShown.swift: `content` on the window's playing frame, else
// `model` (HaloLiveNeed.playhead, #4589), for a leaf that shows only the
// playhead and what it alone decides: the timeline's playhead, the
// timecode, the transport's frame watch and the viewer's summary readouts.
// It never reads the live edit's `project`, so an inspector scrub or a
// viewer drag, which only moves layers, re-runs none of them; a playing
// tick (or a ruler scrub) re-runs this leaf alone, as HaloLiveShown does.
import HaloModel
import SwiftUI

struct HaloPlayheadShown<Content: View>: View {
    let model: HaloProject
    @ViewBuilder let content: (HaloProject) -> Content
    @Environment(\.haloLiveEdit) private var live

    var body: some View {
        content(HaloLiveNeed.playhead.shown(model, edit: { live?.project }, playing: { live?.playing }))
    }
}
