// DesignPageSnapshots.swift: the page's size and the layers past its edge (canvas-basics CB-9).
// The inspector with the page selected and no layer shows Width and Height as ScrubFields
// (design-inspector-page-size-{light,dark}.png); the hosted check finds both by their ids. On
// `cards` cut to 800 × 1024 pt, with a rectangle added up and left of the page, the canvas at 40%
// draws Desktop's part past 800, Pair and the rectangle dimmed outside the page
// (design-canvas-past-edge-{light,dark}.png); DesignPastEdge.layers picks exactly the layers that
// reach past the page. macOS only.
#if canImport(AppKit)
import AppKit
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

@MainActor
@Suite struct DesignPageSnapshots {
    /// A new file with its page selected and no layer: the inspector's page rows.
    private var pageSelected: DesignWorkspace {
        var model = DesignWorkspace()
        model.newFile()
        model.deselect()
        return model
    }

    @Test func inspectorPageSize() throws {
        let model = pageSelected
        #expect(model.selectedNode == nil)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PageInspectorSample(model: model),
                name: "design-inspector-page-size-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test(.timeLimit(.minutes(1))) func pageSizeRowsHaveTheirIDs() async throws {
        let w = RenderBudgetWindow(PageInspectorSample(model: pageSelected))
        defer { w.close() }
        try await w.settle(500)
        #expect(await w.element(DesignControlID.inspectorPageWidth) != nil, "no Width (design.inspector.page-width)")
        #expect(await w.element(DesignControlID.inspectorPageHeight) != nil, "no Height (design.inspector.page-height)")
    }

    @Test func layersPastTheEdgeDrawDimmed() throws {
        var model = DesignFixtures.cards
        model.useServices(.live)
        let outside = try model.addNode(.rectangle, frame: DesignRect(x: -200, y: -150, width: 120, height: 100))
        model.setPageSize(width: 800, height: 1024)
        #expect(model.undoActionName == "Undo Change Page Size")
        let page = try #require(model.selectedPage)
        #expect(page.frameWidth == 800 && page.frameHeight == 1024)

        let past = Set(DesignPastEdge.layers(page.painted, on: page).map(\.id))
        #expect(past.contains(outside), "the rectangle above and left of the page isn't past its edge")
        #expect(past.contains("node-1"), "Desktop, 1440 wide, isn't past an 800 pt page")
        #expect(past.contains("node-6"), "Pair, at x 900, isn't past an 800 pt page")
        #expect(!past.contains("node-2") && !past.contains("node-4"), "A or C, inside the page, drew dimmed")
        #expect(!past.contains("node-10"), "the hidden layer drew")

        model.deselect()
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignCanvas(model: model, zoom: 0.4),
                name: "design-canvas-past-edge-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct PageInspectorSample: View {
    let model: DesignWorkspace
    var body: some View {
        DesignInspector(model: model, perform: { _ in })
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
#endif
