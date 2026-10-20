// HaloShapeSnapshots.swift: shape-tools HS-4, the packet's screens on
// `three-layers` on `.fake`. `halo-shape-tool`: the viewer with the shape
// tool on (its Shape button selected once HS-5 enables it) beside the Shape
// popover's options, as the popover shows them. `halo-shape-star`: the
// viewer mid-drag, a six-point star's draft stroked over the artboard from
// composition (760, 340) to (1160, 740). Light and Dark. Writes
// halo-shape-tool-*.png and halo-shape-star-*.png. macOS only.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloShapeSnapshots {
    static let star = ShapeSpec(kind: .star, points: 6, innerRatio: 0.5)

    private func project() throws -> HaloProject {
        HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
    }

    @Test func shapeTool() throws {
        let project = try project()
        let drawing = HaloShapeDrawing(tool: Self.star)
        drawing.isOn = true
        #expect(HaloShapeTool.action(project, isOn: true) { }.isSelected)
        for scheme in [ColorScheme.light, .dark] {
            let view = HStack(alignment: .top, spacing: 0) {
                HaloViewer(model: project).environment(\.haloShapeDrawing, drawing)
                HaloShapeOptions(model: project)
            }
            try snapshot(view, name: "halo-shape-tool-\(scheme.name)", scheme: scheme)
        }
    }

    @Test func starDraft() throws {
        let project = try project()
        let drawing = HaloShapeDrawing(tool: Self.star)
        drawing.isOn = true
        drawing.drag(project.shapeTool, from: HaloPoint(x: 760, y: 340), to: HaloPoint(x: 1160, y: 740))
        let draft = try #require(drawing.draft)
        #expect(draft.spec == Self.star && draft.box.width == 400)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                HaloViewer(model: project).environment(\.haloShapeDrawing, drawing),
                name: "halo-shape-star-\(scheme.name)", scheme: scheme)
        }
    }
}
