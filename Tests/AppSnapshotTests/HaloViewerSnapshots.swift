// HaloViewerSnapshots.swift: HaloViewer on `keyed` (fake services) at frame
// 12 with Ball selected: SuiteUI's selection handles, eight and the knob, on
// Ball's box from the Model's transformSelection (transform HT-2, on the HT-1
// stubs, so the box is unturned until HT-5 reads the turn). Light and Dark.
// Writes halo-viewer-handles-*.png. macOS only.
import FlareCore
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloViewerSnapshots {
    @Test func handlesOnTheSelectedLayer() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" }).id
        project.selectLayer(ball)
        project.scrub(to: 12)
        let item = try #require(project.transformSelection)
        let drawn = try #require(project.viewerDrawList?.worldBox(of: ball))
        #expect(HaloViewerHandles.rect(item) == CGRect(x: drawn.x, y: drawn.y, width: drawn.width, height: drawn.height))
        #expect(HaloViewerHandles.zoom(artboardWidth: 1920, width: 960) == 0.5)
        #expect(HaloViewerHandles.zoom(artboardWidth: 0, width: 960) == 1)
        try snapshot(HaloViewer(model: project), name: "halo-viewer-handles-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-viewer-handles-dark", scheme: .dark)
    }
}
