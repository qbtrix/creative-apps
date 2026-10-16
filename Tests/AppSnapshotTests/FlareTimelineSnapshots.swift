// FlareTimelineSnapshots.swift: Flare's timeline under the stage (draw-key-save
// DK-10). On `bounce` with the playhead at 12: a TimelineStrip lane per layer
// with its diamonds, the playhead at 12 and the readouts "00:12 / 02:00" and
// "12 / 48". On `empty`: "No layers yet. Draw on the stage to add one."
// Writes flare-timeline-bounce.png and flare-timeline-empty.png. macOS only.
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@testable import FlareApp

@MainActor
@Suite struct FlareTimelineSnapshots {
    @Test func bounce() throws {
        var model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "bounce"]))
        model.setCurrentFrame(12)
        #expect(model.timelineEmptyText == nil)
        #expect(model.timelineRows.count == 3)
        #expect(model.timecode == "00:12 / 02:00")
        #expect(model.frameReadout == "12 / 48")
        try snapshot(timeline(model), name: "flare-timeline-bounce", scheme: .light)
    }

    @Test func empty() throws {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "empty"]))
        #expect(model.document != nil, "the empty fixture opened no document")
        #expect(model.timelineEmptyText == "No layers yet. Draw on the stage to add one.")
        try snapshot(timeline(model), name: "flare-timeline-empty", scheme: .light)
    }

    private func timeline(_ model: FlareWorkspace) -> some View {
        FlareTimeline(model: model, zoom: nil, perform: { _ in }, tick: { _, _ in false })
            .frame(width: SuiteSize.windowLaunch.width)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
