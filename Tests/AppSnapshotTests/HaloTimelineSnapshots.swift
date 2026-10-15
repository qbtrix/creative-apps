// HaloTimelineSnapshots.swift: HaloViewer with three layers of different
// spans and the playhead at frame 36, so the timeline strip shows three span
// bars and the status bar shows 00:00:01:06 at 30 fps; the keyed fixture, so
// Ball's lane shows diamonds at 0, 12 and 24; and the keyed fixture after I
// with no layer selected, so the refusal's caption shows under the timeline.
// Light and Dark. Writes halo-timeline-*.png, halo-timeline-keys-*.png and
// halo-refusal-*.png. macOS only.
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

    @Test func keys() throws {
        let project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        #expect(project.timelineRows.first { $0.name == "Ball" }?.keyFrames == [0, 12, 24])
        try snapshot(HaloViewer(model: project), name: "halo-timeline-keys-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-timeline-keys-dark", scheme: .dark)
    }

    @Test func refusal() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        project.setSelectedLayerInPoint()
        #expect(project.refusal == HaloRefusal(control: "halo.timeline", message: "Select a layer first."))
        try snapshot(HaloViewer(model: project), name: "halo-refusal-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-refusal-dark", scheme: .dark)
    }
}
