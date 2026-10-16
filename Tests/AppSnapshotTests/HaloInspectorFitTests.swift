// HaloInspectorFitTests.swift: Halo's inspector fits the height its column
// offers. A selected layer's TRANSFORM rows stack under their bars at the
// inspector's width; unscrolled they stood about 800 pt tall, taller than
// the journeys' 640 pt window, and the window's content grew past the window
// both ways (run 38767265986: sidebar rows above it, the status bar,
// timeline and layer rows below it). Asked for its size in a 240 × 400 pt
// column, the live inspector (scrolling; snapshots draw it unscrolled) must
// take no more than the 400 pt. macOS only.
import AppKit
import HaloModel
import SuiteUI
import SwiftUI
import Testing

@testable import HaloApp

@MainActor
@Suite struct HaloInspectorFitTests {
    private static let column = CGSize(width: 240, height: 400)

    /// The height the inspector takes in the column, laid out as the window does.
    private func height(_ project: HaloProject) -> CGFloat {
        NSHostingController(rootView: HaloCompositionInspector(model: project)).sizeThatFits(in: Self.column).height
    }

    /// `-HaloSample three-layers`: four layers, the composition selected.
    private func threeLayers() throws -> HaloProject {
        HaloProject(services: .fake, document: try #require(HaloFixtures.project("three-layers")))
    }

    @Test func aSelectedLayerFitsTheColumn() throws {
        var project = try threeLayers()
        project.selectLayer("comp-1-layer-2")
        #expect(project.selectedLayerHeader != nil, "no layer selected")
        let taken = height(project)
        #expect(taken <= Self.column.height + 0.5, "the layer inspector takes \(taken) pt of a \(Self.column.height) pt column")
    }

    @Test func theCompositionFitsTheColumn() throws {
        let project = try threeLayers()
        #expect(project.selectedLayerHeader == nil, "a layer is selected")
        let taken = height(project)
        #expect(taken <= Self.column.height + 0.5, "the composition inspector takes \(taken) pt of a \(Self.column.height) pt column")
    }
}
