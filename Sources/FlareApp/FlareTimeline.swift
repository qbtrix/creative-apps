// FlareTimeline.swift: the timeline under the stage. A stub that shows
// nothing; DK-10 fills it with TimelineStrip, the readouts and the transport,
// whose PlaybackDriver ticks the model through `tick`. It only reads `model`.
import FlareModel
import SwiftUI

struct FlareTimeline: View {
    let model: FlareWorkspace
    let zoom: Double?
    let perform: @MainActor (FlareIntent) -> Void
    let tick: @MainActor (Double, inout PlaybackTicker) -> Bool

    var body: some View {
        EmptyView()
    }
}
