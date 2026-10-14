// HaloTimelineSnapshots.swift: HaloViewer with three layers of different
// spans and the playhead at frame 36, so the timeline strip shows three span
// bars and the readout shows 00:00:01:06 at 30 fps, in Light and Dark. Writes
// halo-timeline-light.png and halo-timeline-dark.png. macOS only.
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloTimelineSnapshots {
    @Test func timeline() throws {
        var project = HaloProject()
        project.newComposition()
        project.newLayer(.solid)
        project.newLayer(.shape)
        project.scrub(to: 60)
        project.setSelectedLayerInPoint()
        project.newLayer(.text)
        project.scrub(to: 24)
        project.setSelectedLayerInPoint()
        project.scrub(to: 180)
        project.setSelectedLayerOutPoint()
        project.scrub(to: 36)
        #expect(project.selectedComposition?.playheadTimecode == "00:00:01:06")
        #expect(project.timelineRows.map(\.span) == [24...181, 60...300, 0...300])
        try snapshot(HaloViewer(model: project), name: "halo-timeline-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-timeline-dark", scheme: .dark)
    }
}
