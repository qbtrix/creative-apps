// FlareTransportSnapshots.swift: Flare's transport above the timeline
// (draw-key-save DK-11). On `bounce` at frame 30: paused with Loop off (Play
// shows play, Loop unselected), and playing with Loop on (Play shows pause and
// reads selected, Loop selected). The playing shot never ticks: its `tick`
// returns false, so the driver stops at once and the frame stays 30. Writes
// flare-transport-paused.png and flare-transport-playing.png. The flat row
// (#1858) shows Play on accentFill and the whole Loop toggle; two checks pin
// the controls' kinds and that the row asks for room for every control.
// macOS only.
import AppKit
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

    /// #1858: Play is the one prominent control, Loop a toggle, the rest plain steps, with unique ids.
    @Test func playIsTheProminentControl() {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.setCurrentFrame(30)
        let items = FlareTransport.items(for: model)
        #expect(items.map(\.kind) == [.step, .step, .play, .step, .step, .loop])
        #expect(Set(items.map(\.id)).count == items.count)
        #expect(items.allSatisfy { $0.help == nil })
    }

    /// #1858: laid out unconstrained, the flat row holds five transportButton squares and the larger
    /// playButton whole (nothing clipped by a capsule), and is at least playButton tall.
    @Test func rowHoldsEveryControlWhole() {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.setCurrentFrame(30)
        model.setLoops(true)
        model.play()
        let row = FlareTransport(model: model, zoom: nil, perform: { _ in }, tick: { _, _ in false })
        let taken = NSHostingController(rootView: row).sizeThatFits(in: CGSize(width: 2000, height: 2000))
        let least = 5 * SuiteSize.transportButton + SuiteSize.playButton
        #expect(taken.width >= least - 0.5, "the transport is \(taken.width) pt wide, under \(least)")
        #expect(taken.height >= SuiteSize.playButton - 0.5, "the transport is \(taken.height) pt tall")
    }

    private func transport(_ model: FlareWorkspace) -> some View {
        FlareTransport(model: model, zoom: nil, perform: { _ in }, tick: { _, _ in false })
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
