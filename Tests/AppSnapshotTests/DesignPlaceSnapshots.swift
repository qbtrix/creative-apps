// DesignPlaceSnapshots.swift (placed-images PD-u, PD-3 and PD-4): Design's pictures on the canvas, drawn by
// cover through SuiteUI's drawPlaced in DesignArtwork's Canvas, over the fill and under the stroke, and the
// inspector's Image section. A 1200 × 800 photo fitted at its own shape, the same photo in a 400 × 400 frame
// with radius 24 (cropped and rounded), an SVG logo in a rectangle, the frame selected beside the inspector
// (File, Replace…, Reset Size, Place…, Fill), and a canvas under a drop with SuiteUI's accent ring. Writes
// design-image-fitted-, design-image-in-frame-, design-image-svg-, design-image-inspector- and
// design-place-drop-{light,dark}.png. `DesignPlaceSeed` is the document RenderBudgetDesignPlaceTests drives too.
// macOS only.
import AppKit
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

/// Pages of pictures, as a file holding them opens.
enum DesignPlaceSeed {
    /// A `width` × `height` JPEG named "photo-<width>x<height>.jpg", red on the left half and blue on the right.
    static func photo(width: Int = 1200, height: Int = 800) throws -> PlacedAsset {
        PlacedAsset(id: "photo-\(width)x\(height)", name: "photo-\(width)x\(height).jpg", format: .jpeg,
                    natural: Size(width: Double(width), height: Double(height)),
                    data: try HaloPlaceSnapshots.jpeg(width: width, height: height))
    }

    /// `node` showing `asset` on an 800 × 600 page, selected.
    static func page(_ node: DesignNode) -> DesignWorkspace {
        var model = DesignFixtures.cards
        model.useServices(.live)
        model.load([DesignPage(id: "page-1", name: "Page 1", frameWidth: 800, frameHeight: 600, nodes: [node])])
        model.selectItem(node.id)
        return model
    }

    /// node-1, a 400 × 400 frame at (100, 100) with radius 24, showing the photo.
    static func framed() throws -> DesignWorkspace {
        try page(DesignNode(id: "node-1", name: "Frame", kind: .frame, frame: DesignRect(x: 100, y: 100, width: 400, height: 400),
                            cornerRadius: 24, placedAsset: photo()))
    }
}

@MainActor
@Suite struct DesignPlaceSnapshots {
    private func shoot(_ view: some View, _ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(view, name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    /// `node` alone on the canvas's paint at 100%.
    private func art(_ node: DesignNode) -> some View {
        DesignArtwork(painted: [DesignPainted(node: node, backdrop: nil, opacity: 1, stroke: node.vectorStroke)], zoom: 1)
            .frame(width: 800, height: 600).background(SuiteColor.canvasSurround)
    }

    @Test func fitted() throws {
        let node = DesignNode(id: "node-1", name: "photo-1200x800", kind: .rectangle,
                              frame: DesignRect(x: 100, y: 100, width: 600, height: 400), placedAsset: try DesignPlaceSeed.photo())
        #expect(node.placedImage?.box == Rect(minX: 100, minY: 100, maxX: 700, maxY: 500))
        try shoot(art(node), "design-image-fitted")
    }

    @Test func inFrame() throws {
        let node = try #require(try DesignPlaceSeed.framed().selectedNode)
        #expect(node.placedImage.map { PlaceRules.drawnRect($0, natural: Size(width: 1200, height: 800)).width } == 600)
        try shoot(art(node), "design-image-in-frame")
    }

    @Test func svg() throws {
        var node = DesignNode(id: "node-1", name: "logo", kind: .rectangle, frame: DesignRect(x: 160, y: 220, width: 480, height: 160),
                              cornerRadius: 12, placedAsset: HaloPlaceSnapshots.logoAsset)
        node.stroke = DesignStroke(color: DesignColor(28, 28, 30), width: 2)
        #expect(node.placedAsset?.format == .svg)
        try shoot(art(node), "design-image-svg")
    }

    @Test func inspector() throws {
        let model = try DesignPlaceSeed.framed()
        #expect(model.placedSelection?.asset.name == "photo-1200x800.jpg")
        try shoot(PlaceSample(model: model), "design-image-inspector")
    }

    @Test func drop() throws {
        let model = try DesignPlaceSeed.framed()
        // The drop's own ring is private to SuiteUI's modifier and shows only while a drag is over it; this draws it the same way.
        let ring = RoundedRectangle(cornerRadius: SuiteRadius.medium).stroke(SuiteColor.accent, lineWidth: SuiteSize.focusRing)
        try shoot(DesignCanvas(model: model, zoom: 0.5).overlay { ring.padding(SuiteSpacing.xxl) }, "design-place-drop")
    }
}

/// The canvas at 50% beside the inspector at the editor's panel width.
private struct PlaceSample: View {
    let model: DesignWorkspace
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            DesignCanvas(model: model, zoom: 0.5)
            DesignInspector(model: model, perform: { _ in })
                .frame(width: SuiteSize.editorPanelWidth)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(SuiteSpacing.xxl)
        }
    }
}
