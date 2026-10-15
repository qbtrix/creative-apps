// HaloTimelineEmptySnapshots.swift: HaloViewer on a new composition with no
// layers, so the timeline shows its whole ruler with every frame label clear
// and the "No layers yet" hint in the lane under it, inside the timeline's
// minimum height. Light and Dark. Writes halo-timeline-empty-*.png. macOS only.
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloTimelineEmptySnapshots {
    @Test func emptyTimeline() throws {
        var project = HaloProject()
        project.newComposition()
        #expect(project.timelineRows.isEmpty)
        try snapshot(HaloViewer(model: project), name: "halo-timeline-empty-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-timeline-empty-dark", scheme: .dark)
    }
}
