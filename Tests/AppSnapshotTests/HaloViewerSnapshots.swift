// HaloViewerSnapshots.swift: HaloViewer's own controls on `three-layers` on
// `.fake`. Shape-tools HS-2: the Shape button sits at the viewer's top
// trailing corner, disabled with HaloProject's `shapeHelp` until HS-5 builds
// the tool, and its options popover's content (HaloShapeOptions: SuiteUI's
// ShapeToolOptions on the Model's tool, its help under the rows). Light and
// Dark. Writes halo-viewer-shape-*.png and halo-viewer-shape-options-*.png.
// macOS only.
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloViewerSnapshots {
    private func project() throws -> HaloProject {
        HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
    }

    @Test func shapeButton() throws {
        let project = try project()
        #expect(project.selectedComposition != nil)
        #expect(project.shapeHelp != nil, "the stubbed Shape button has no help to say why it is off")
        #expect(HaloShapeTool.action(project) { }.unavailableHelp == project.shapeHelp)
        try snapshot(HaloViewer(model: project), name: "halo-viewer-shape-light", scheme: .light)
        try snapshot(HaloViewer(model: project), name: "halo-viewer-shape-dark", scheme: .dark)
    }

    @Test func shapeOptions() throws {
        let project = try project()
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloShapeOptions(model: project)
                    .padding(SuiteSpacing.m)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading),
                name: "halo-viewer-shape-options-\(scheme.name)", scheme: scheme)
        }
    }
}
