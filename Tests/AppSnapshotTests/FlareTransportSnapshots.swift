// FlareTransportSnapshots.swift: Flare's transport above the timeline
// (draw-key-save DK-11). On `bounce` at frame 30: paused with Loop off (Play
// shows play, Loop unselected), and playing with Loop on (Play shows pause and
// reads selected, Loop selected). The playing shot never ticks: its `tick`
// returns false, so the driver stops at once and the frame stays 30. Writes
// flare-transport-paused.png and flare-transport-playing.png. macOS only.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareTransportSnapshots {
    @Test func paused() throws {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.setCurrentFrame(30)
        model.setLoops(false)
        #expect(model.canPlay)
        #expect(!model.isPlaying)
        #expect(!model.loops)
        try snapshot(transport(model), name: "flare-transport-paused", scheme: .light)
    }

    @Test func playing() throws {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.setCurrentFrame(30)
        model.setLoops(true)
        model.play()
        #expect(model.isPlaying)
        #expect(model.loops)
        #expect(model.currentFrame == 30)
        try snapshot(transport(model), name: "flare-transport-playing", scheme: .light)
    }

    private func transport(_ model: FlareWorkspace) -> some View {
        FlareTransport(model: model, zoom: nil, perform: { _ in }, tick: { _, _ in false })
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
