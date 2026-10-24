// HaloViewerSnapshots.swift: HaloViewer's own controls on the fake services.
// Transform HT-2: on `keyed` at frame 12 with Ball selected, SuiteUI's
// selection handles, eight and the knob, on Ball's box from the Model's
// transformSelection (on the HT-1 stubs, so the box is unturned until HT-5
// reads the turn). Shape-tools HS-2: on `three-layers`, the Shape button at the
// viewer's top trailing corner, enabled (HaloProject's `shapeHelp` is nil
// once a composition is selected, HS-5), and its options popover's content (HaloShapeOptions:
// SuiteUI's ShapeToolOptions on the Model's tool, its help under the rows).
// Light and Dark. Writes halo-viewer-handles-*.png, halo-viewer-shape-*.png and
// halo-viewer-shape-options-*.png. macOS only.
import FlareCore
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloViewerSnapshots {
    private func threeLayers() throws -> HaloProject {
        HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
    }

    @Test func shapeButton() throws {
        let project = try threeLayers()
        #expect(project.selectedComposition != nil)
        #expect(project.shapeHelp == nil, "the Shape button is off on a selected composition: \(project.shapeHelp ?? "")")
        #expect(HaloShapeTool.action(project) { }.unavailableHelp == project.shapeHelp)
        try snapshot(HaloViewer(model: project), name: "halo-viewer-shape-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-viewer-shape-dark", scheme: .dark)
    }

    @Test func shapeOptions() throws {
        let project = try threeLayers()
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloShapeOptions(model: project)
                    .padding(SuiteSpacing.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                name: "halo-viewer-shape-options-\(scheme.name)", scheme: scheme)
        }
    }

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
