// HaloShapeSnapshots.swift: shape-tools HS-4 on `three-layers`, Light and
// Dark. halo-shape-tool-*.png: the viewer, tool on, beside the Shape options.
// halo-shape-star-*.png: a six-point star's draft mid-drag. macOS only.
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
