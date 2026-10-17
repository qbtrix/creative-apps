// FlareTimelineSnapshots.swift: Flare's timeline under the stage (draw-key-save
// DK-10). On `bounce` with the playhead at 12: a TimelineStrip lane per layer
// with its diamonds, the playhead at 12 and the readouts "00:12 / 02:00" and
// "Frame 12 / 48", current values in primary text and totals in secondary, the
// lanes inset to end under the readouts. On `empty`: "No layers yet. Draw on the stage to add one."
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
        #expect(model.timecodeParts?.current == "00:12" && model.frameReadoutParts?.current == "12")
        try snapshot(timeline(model), name: "flare-timeline-bounce", scheme: .light)
    }

    /// The strip takes the readout row's inset, so at the launch width its lanes end where the readouts do, inside
    /// the window, with room for every frame of the bounce scene (#1859).
    @Test func stripLinesUpWithTheReadouts() {
        let window = SuiteSize.windowLaunch.width
        let strip = window - 2 * FlareTimeline.inset
        let lanes = FlareTimeline.laneWidth(strip: strip)
        let lanesEnd = FlareTimeline.inset + SuiteSize.timelineLabelColumn + 1 + lanes
        #expect(lanesEnd + SuiteSpacing.xl == window - FlareTimeline.inset)
        #expect(lanesEnd < window && lanes > 0)
        #expect(lanes / 47 >= 4, "a frame is under 4 pt wide")
        #expect(FlareTimeline.laneWidth(strip: 0) == 0)
    }

    @Test func empty() throws {
        let model = FlareWorkspace(launch: FlareLaunch(arguments: ["-FlareFixture", "empty"]))
        #expect(model.document != nil, "the empty fixture opened no document")
        #expect(model.timelineEmptyText == "No layers yet. Draw on the stage to add one.")
        try snapshot(timeline(model), name: "flare-timeline-empty", scheme: .light)
    }

    private func timeline(_ model: FlareWorkspace) -> some View {
        FlareTimeline(model: model, perform: { _ in })
            .frame(width: SuiteSize.windowLaunch.width)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
