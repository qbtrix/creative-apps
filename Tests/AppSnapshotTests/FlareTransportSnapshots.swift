// FlareTransportSnapshots.swift: Flare's transport above the timeline
// (draw-key-save DK-11). On `bounce` at frame 30: paused with Loop off (Play
// shows play, Loop unselected), and playing with Loop on (Play shows pause and
// reads selected, Loop selected). The transport owns no driver, so the frame
// stays 30. Writes
// flare-transport-paused.png and flare-transport-playing.png. It is the
// shared TransportCapsule in its pill; two checks pin the controls' order,
// unique ids and reasons, and that the row asks for a pillHit square per
// control, and one that the whole readout row fits the narrowest content
// column (#2101).
// The status pills (inspector-timeline IT-9) in the stage's status bar, from
// `statusPills(measuredFPS:)` on `bounce` playing: at a measured 60 the
// actual-fps pill reads 24 fps plain, at 18 it reads 18 fps in the warning
// color; on `showcase` the "Text not shown (1)" warning. Writes
// flare-status-playing.png, flare-status-dropping.png and flare-status-text.png;
// paused on `bounce`, flare-status-paused-light.png and flare-status-paused-dark.png.
// macOS only.
import AppKit
import FlareModel
import SwiftUI
import Testing

@testable import FlareApp
@testable import SuiteUI

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

    /// The shared transport's six controls in order, each its intent's id (the steps suffixed), live mid-timeline.
    @Test func controlsAreTheIntentsInOrder() {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.setCurrentFrame(30)
        let items = FlareTransportAdapter(model: model, perform: { _ in }).capsule.items
        #expect(items.map(\.button) == TransportButton.allCases)
        #expect(items.map(\.id) == ["flare.timeline.goToStart", "flare.timeline.step.back", "flare.timeline.togglePlay",
                                    "flare.timeline.step.forward", "flare.timeline.goToEnd", "flare.timeline.setLoops"])
        #expect(items.allSatisfy { $0.help == nil })
        model.setCurrentFrame(0)
        model.setLoops(false)
        let first = FlareTransportAdapter(model: model, perform: { _ in }).capsule.items
        #expect(first.map(\.help) == ["Already at the first frame.", "Already at the first frame.", nil, nil, nil, nil])
    }

    /// Laid out unconstrained, the row holds six pillHit squares, at least pillHit tall.
    @Test func rowHoldsEveryControlWhole() {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.setCurrentFrame(30)
        model.setLoops(true)
        model.play()
        let row = FlareTransportAdapter(model: model, perform: { _ in })
        let taken = NSHostingController(rootView: row).sizeThatFits(in: CGSize(width: 2000, height: 2000))
        let least = 6 * SuiteSize.pillHit
        #expect(taken.width >= least - 0.5, "the transport is \(taken.width) pt wide, under \(least)")
        #expect(taken.height >= SuiteSize.pillHit - 0.5, "the transport is \(taken.height) pt tall")
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

    /// The stage's status bar paused, in light and dark: zoom, size, aspect and rate in primary text on the pill fill
    /// (the audit measured a secondary "1:1" at 3.89:1).
    @Test func statusPaused() throws {
        let pills = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"])).statusPills(measuredFPS: nil)
        #expect(pills.actualFPS == nil && pills.textWarning == nil)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(status(pills), name: "flare-status-paused-\(scheme.name)", scheme: scheme)
        }
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
        FlareTransportAdapter(model: model, perform: { _ in })
            .padding(SuiteSpacing.m)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
