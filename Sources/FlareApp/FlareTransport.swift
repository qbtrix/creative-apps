// FlareTransport.swift: the transport above the timeline strip. A stub that
// shows nothing; DK-11 fills it with start, step, play/pause, end and loop on
// a floating ToolbarGroup, and a PlaybackDriver started and stopped by
// `model.isPlaying` that ticks the model through `tick`. It only reads `model`.
import FlareModel
import SwiftUI

struct FlareTransport: View {
    let model: FlareWorkspace
    let zoom: Double?
    let perform: @MainActor (FlareIntent) -> Void
    let tick: @MainActor (Double, inout PlaybackTicker) -> Bool

    var body: some View {
        EmptyView()
    }
}
