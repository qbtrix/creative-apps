// FlareTransportSnapshots.swift: Flare's transport above the timeline
// (draw-key-save DK-11). On `bounce` at frame 30: paused with Loop off (Play
// shows play, Loop unselected), and playing with Loop on (Play shows pause and
// reads selected, Loop selected). The transport owns no driver, so the frame
// stays 30. Writes
// flare-transport-paused.png and flare-transport-playing.png. The flat row
// (#1858) shows Play on accentFill and the whole Loop toggle; two checks pin
// the controls' kinds and that the row asks for room for every control, and
// that the whole readout row fits the narrowest content column (#2101).
// The status pills (inspector-timeline IT-9) in the stage's status bar, from
// `statusPills(measuredFPS:)` on `bounce` playing: at a measured 60 the
// actual-fps pill reads 24 fps plain, at 18 it reads 18 fps in the warning
// color; on `showcase` the "Text not shown (1)" warning. Writes
// flare-status-playing.png, flare-status-dropping.png and flare-status-text.png.
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
        let row = FlareTransport(model: model, perform: { _ in })
        let taken = NSHostingController(rootView: row).sizeThatFits(in: CGSize(width: 2000, height: 2000))
        let least = 5 * SuiteSize.transportButton + SuiteSize.playButton
        #expect(taken.width >= least - 0.5, "the transport is \(taken.width) pt wide, under \(least)")
        #expect(taken.height >= SuiteSize.playButton - 0.5, "the transport is \(taken.height) pt tall")
    }

    /// #2101: the transport and both readouts, playing with Loop on at the last frame, fit inside
    /// SuiteSize.contentMinimum's width, so the row never overflows the content column under the side columns.
    @Test func timelineRowFitsTheNarrowestColumn() {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.setCurrentFrame(model.timelineFrames - 1)
        model.setLoops(true)
        model.play()
        let row = FlareTimeline(model: model, perform: { _ in })
        let taken = NSHostingController(rootView: row).sizeThatFits(in: CGSize(width: 0, height: 2000))
        #expect(taken.width <= SuiteSize.contentMinimum.width, "the timeline needs \(taken.width) pt")
    }

    @Test func statusPlaying() throws {
        let pills = playing("bounce").statusPills(measuredFPS: 60)
        #expect(pills.actualFPS == "24 fps" && !pills.isDropping)
        try snapshot(status(pills), name: "flare-status-playing", scheme: .light)
    }

    @Test func statusDropping() throws {
        let pills = playing("bounce").statusPills(measuredFPS: 18)
        #expect(pills.actualFPS == "18 fps" && pills.isDropping)
        try snapshot(status(pills), name: "flare-status-dropping", scheme: .dark)
    }

    @Test func statusHiddenText() throws {
        let pills = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "showcase"])).statusPills(measuredFPS: nil)
        #expect(pills.textWarning == "Text not shown (1)" && pills.actualFPS == nil)
        try snapshot(status(pills), name: "flare-status-text", scheme: .light)
    }

    private func playing(_ fixture: String) -> FlareWorkspace {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", fixture]))
        model.setCurrentFrame(30)
        model.play()
        return model
    }

    private func status(_ pills: StatusPills) -> some View {
        ViewerStatusBar(zoom: 1, size: "550 × 400 pt") { FlareStage.statusPills(pills) }
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func transport(_ model: FlareWorkspace) -> some View {
        FlareTransport(model: model, perform: { _ in })
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
