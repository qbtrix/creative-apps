// DesignPageSnapshots.swift: the page's size and the layers past its edge (canvas-basics CB-9).
// The inspector with the page selected and no layer shows Width and Height as ScrubFields
// (design-inspector-page-size-{light,dark}.png); the hosted check finds both by their ids. Cut
// smaller than its layers, the section's note says what shows dimmed
// (design-inspector-page-past-edge-{light,dark}.png). On
// `cards` cut to 800 × 1024 pt, with a rectangle added up and left of the page, the canvas at 40%
// draws Desktop's part past 800, Pair and the rectangle dimmed outside the page
// (design-canvas-past-edge-{light,dark}.png); DesignPastEdge.layers picks exactly the layers that
// reach past the page. layersPastTheEdgeStayReadable (#3340) reads pixels of the same document
// drawn at a known place: past-edge layers and the page's edge clear 1.5:1 in Light and Dark.
// macOS only.
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

    /// #3342: cut smaller than Desktop, the Page Size section says what shows dimmed and why.
    @Test func inspectorPastEdgeNote() throws {
        var model = DesignFixtures.cards
        model.setPageSize(width: 800, height: 1024)
        model.deselect()
        #expect(model.selectedPage?.pastEdgeNote?.hasPrefix("Desktop reaches past the page") == true)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PageInspectorSample(model: model),
                name: "design-inspector-page-past-edge-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
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

    /// #3340: past the page, a layer stays readable in Light and Dark. The same document drawn by
    /// PastEdgeSample at a known place: the off-page rectangle against the surround next to it,
    /// and Pair's E1 past the 800 pt edge against the dimmed Desktop, each read as the strongest
    /// contrast inside the layer's box (its outline counts), at least 1.5:1; the page's edge shows
    /// as a line against the dimmed Desktop; and in Dark the dimmed Desktop is no brighter than
    /// Desktop inside the page.
    @Test(arguments: [ColorScheme.light, .dark])
    func layersPastTheEdgeStayReadable(scheme: ColorScheme) throws {
        var model = DesignFixtures.cards
        model.useServices(.live)
        _ = try model.addNode(.rectangle, frame: DesignRect(x: -200, y: -150, width: 120, height: 100))
        model.setPageSize(width: 800, height: 1024)
        let page = try #require(model.selectedPage)
        let image = try #require(render(PastEdgeSample(page: page), scheme: scheme))
        // Page point (x, y) lands at origin + 0.4 × (x, y) in the image.
        func at(_ x: Double, _ y: Double) -> (Int, Int) {
            (Int(PastEdgeSample.origin + PastEdgeSample.zoom * x), Int(PastEdgeSample.origin + PastEdgeSample.zoom * y))
        }
        func strongest(in box: DesignRect, against ground: Double) -> Double {
            let (x0, y0) = at(box.x, box.y)
            let (x1, y1) = at(box.maxX, box.maxY)
            var best = 1.0
            for y in (y0 - 1)...(y1 + 1) {
                for x in (x0 - 1)...(x1 + 1) { best = max(best, wcag(luma(image, x, y), ground)) }
            }
            return best
        }
        let surround = luma(image, at(-250, -100).0, at(-250, -100).1)
        let rectangle = strongest(in: DesignRect(x: -200, y: -150, width: 120, height: 100), against: surround)
        #expect(rectangle >= 1.5, "the off-page rectangle reads \(rectangle):1 on the surround (\(scheme))")
        let dimmed = luma(image, at(850, 250).0, at(850, 250).1)
        let circle = strongest(in: DesignRect(x: 900, y: 400, width: 100, height: 100), against: dimmed)
        #expect(circle >= 1.5, "E1 past the edge reads \(circle):1 on the dimmed Desktop (\(scheme))")
        let edge = (at(800, 250).0...at(800, 250).0 + 1).map { wcag(luma(image, $0, at(800, 250).1), dimmed) }.max() ?? 1
        #expect(edge >= 1.5, "the page's edge reads \(edge):1 on the dimmed Desktop (\(scheme))")
        if scheme == .dark {
            let inside = luma(image, at(600, 250).0, at(600, 250).1)
            #expect(dimmed <= inside, "the dimmed Desktop (\(dimmed)) is brighter than Desktop in the page (\(inside))")
        }
    }
}

/// The page at 40% with its top-left corner `origin` pt into a surround-filled image: the artwork
/// clipped to the page, as CanvasViewport clips it, and DesignPastEdge over it, unclipped.
private struct PastEdgeSample: View {
    static let origin = 200.0
    static let zoom = 0.4
    let page: DesignPage

    var body: some View {
        let painted = page.painted
        DesignArtwork(painted: painted, zoom: Self.zoom)
            .frame(width: page.frameWidth * Self.zoom, height: page.frameHeight * Self.zoom)
            .clipped()
            .overlay { DesignPastEdge(page: page, painted: painted, zoom: Self.zoom) }
            .padding(.leading, Self.origin)
            .padding(.top, Self.origin)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(SuiteColor.canvasSurround)
    }
}

/// WCAG relative luminance of the sRGB pixel at (x, y), top-left origin; 0 off the image.
@MainActor
private func luma(_ image: NSBitmapImageRep, _ x: Int, _ y: Int) -> Double {
    guard let c = image.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return 0 }
    func lin(_ v: CGFloat) -> Double { v <= 0.04045 ? Double(v) / 12.92 : pow((Double(v) + 0.055) / 1.055, 2.4) }
    return 0.2126 * lin(c.redComponent) + 0.7152 * lin(c.greenComponent) + 0.0722 * lin(c.blueComponent)
}

/// The WCAG contrast ratio of two luminances.
private func wcag(_ a: Double, _ b: Double) -> Double { (max(a, b) + 0.05) / (min(a, b) + 0.05) }

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
