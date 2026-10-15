// HaloKeyByDragSnapshots.swift: HaloViewer on `keyed` (fake services) at
// frame 15, mid-drag: Ball hit at its center and moved 100 px right through
// the Model, so the viewer shows the drag's preview offset with Ball selected
// (#207, LK-11). Light and Dark. Writes halo-key-by-drag-*.png. macOS only.
import FlareCore
import HaloModel
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloKeyByDragSnapshots {
    @Test func midDrag() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("keyed")))
        project.scrub(to: 15)
        let ball = try #require(project.selectedComposition?.layers.first { $0.name == "Ball" }).id
        let box = try #require(project.viewerDrawList?.worldBox(of: ball))
        let center = HaloPoint(x: box.x + box.width / 2, y: box.y + box.height / 2)
        project.beginViewerDrag(at: center)
        project.moveViewerDrag(to: HaloPoint(x: center.x + 100, y: center.y))
        #expect(project.selectedLayerID == ball)
        let drag = try #require(project.viewerDrag)
        #expect(drag.layerID == ball && drag.delta.x == 100 && drag.delta.y == 0)
        try snapshot(HaloViewer(model: project), name: "halo-key-by-drag-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-key-by-drag-dark", scheme: .dark)
    }
}
