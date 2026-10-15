// HaloPreviewSnapshots.swift: HaloViewer drawing `three-layers` on `.fake`
// (#37, VP-8): at frame 0 the viewer canvas shows Background and Badge; at
// frame 36 Title "Hello Halo" sits over them; with Badge selected its world
// box carries SuiteUI's SelectionOutline. Light and Dark. Writes
// halo-preview-*.png, halo-preview-frame-36-*.png and
// halo-preview-selected-*.png. macOS only.
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloPreviewSnapshots {
    private func project() throws -> HaloProject {
        HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
    }

    private func names(_ project: HaloProject) -> [String] {
        let layers = project.selectedComposition?.layers ?? []
        return (project.viewerDrawList?.items ?? []).compactMap { item in layers.first { $0.id == item.layerID }?.name }
    }

    @Test func frameZero() throws {
        let project = try project()
        #expect(names(project) == ["Background", "Badge"])
        #expect(project.viewerDrawList?.drawnSummary == "2 layers drawn")
        try snapshot(HaloViewer(model: project), name: "halo-preview-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-preview-dark", scheme: .dark)
    }

    @Test func frame36() throws {
        var project = try project()
        project.scrub(to: 36)
        #expect(names(project) == ["Background", "Badge", "Title"])
        #expect(project.viewerDrawList?.items.last?.text?.string == "Hello Halo")
        #expect(project.viewerDrawList?.drawnSummary == "3 layers drawn")
        try snapshot(HaloViewer(model: project), name: "halo-preview-frame-36-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-preview-frame-36-dark", scheme: .dark)
    }

    @Test func selected() throws {
        var project = try project()
        let badge = try #require(project.selectedComposition?.layers.first { $0.name == "Badge" })
        project.selectLayer(badge.id)
        #expect(project.selectedLayerID == badge.id)
        let box = try #require(project.viewerDrawList?.worldBox(of: badge.id))
        #expect(box.width > 0 && box.height > 0)
        try snapshot(HaloViewer(model: project), name: "halo-preview-selected-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-preview-selected-dark", scheme: .dark)
    }
}
