// HaloInspectorFitTests.swift: Halo's inspector fits the height its column
// offers. A selected layer's TRANSFORM rows stack under their bars at the
// inspector's width; unscrolled they stood about 800 pt tall, taller than
// the journeys' 640 pt window, and the window's content grew past the window
// both ways (run 38767265986: sidebar rows above it, the status bar,
// timeline and layer rows below it). Asked for its size in a 240 × 400 pt
// column, the live inspector (scrolling; snapshots draw it unscrolled) must
// take no more than the 400 pt. A TRANSFORM row stacks its keyframe button
// under its bar below `besideWidth`. macOS only.
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

    /// A TRANSFORM row puts its keyframe button beside its bar from
    /// `besideWidth` up (one row) and under it below that (bar, gap, button).
    /// HaloBarAndKeyLayout decides from the width it gets, so a divider drag
    /// measures each row once per step; the ViewThatFits over two copies of
    /// the rows it replaces measured them twice (64 to 30 ms a step). The
    /// rows sit beside at the inspector's ideal width and stack at its minimum.
    @Test func rowsPutTheButtonBesideFromBesideWidthUp() throws {
        var project = try threeLayers()
        project.selectLayer("comp-1-layer-2")
        let row = try #require(project.propertyRows.first, "no TRANSFORM rows")
        func height(at width: CGFloat) -> CGFloat {
            let view = HaloPropertyRowView(row: row, refusal: nil, rowHelp: nil, keyHelp: nil, perform: { _ in })
            return NSHostingController(rootView: view).sizeThatFits(in: CGSize(width: width, height: 1000)).height
        }
        let need = HaloPropertyRowView.besideWidth
        let one = max(SuiteSize.studioRow, SuiteSize.keyframeButton)
        #expect(height(at: need) == one, "at \(need) pt")
        #expect(height(at: need - 1) == SuiteSize.studioRow + SuiteSpacing.xs + SuiteSize.keyframeButton, "at \(need - 1) pt")
        let content = { (inspector: CGFloat) in inspector - 2 * SuiteSpacing.m }
        #expect(need <= content(SuiteSize.inspectorWidth.ideal), "\(need) pt doesn't fit the ideal inspector")
        #expect(need > content(SuiteSize.inspectorWidth.min), "\(need) pt fits the minimum inspector")
    }
}
