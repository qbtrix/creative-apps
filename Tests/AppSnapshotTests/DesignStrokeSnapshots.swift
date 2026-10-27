// DesignStrokeSnapshots.swift (stroke-style DK-4): Design's strokes on the canvas and in the inspector's Stroke
// section, side by side at the editor's panel width, the inspector scrolled to its end so the Stroke rows show.
// `cards` opened with B (node-3) given a 2 pt stroke and selected (SuiteUI's StrokeEditor: Width, Join, Cap, Dash),
// and with B selected and no stroke (Add Stroke alone). The dashed border, 8 on and 4 off with round caps, is drawn
// by DesignArtwork alone through the canvas's own paint (DesignPainted's stroke): Design's stroke holds no dash
// until DK-5. Writes design-stroke-editor-, design-stroke-no-stroke- and design-stroke-dashed-{light,dark}.png.
// `DesignStrokeSeed` is the document RenderBudgetDesignStrokeTests drives too. macOS only.
import AppKit
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

/// `cards` with B stroked 2 pt in near-black, as a file holding it opens.
enum DesignStrokeSeed {
    static let stroke = DesignStroke(color: DesignColor(28, 28, 30), width: 2)

    /// The workspace with `selected` selected; B stroked when `stroked`.
    static func cards(selecting selected: String, stroked: Bool = true) -> DesignWorkspace {
        var model = DesignFixtures.cards
        model.useServices(.live)
        model.load(model.pages.map { page in
            // B sits inside the Desktop frame, so the stroke goes on through the tree, not the top level.
            var page = page
            _ = page.nodes.update("node-3") { $0.stroke = stroked ? stroke : nil }
            return page
        })
        model.selectItem(selected)
        return model
    }
}

@MainActor
@Suite struct DesignStrokeSnapshots {
    private func shoot(_ view: some View, _ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(view, name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func editor() throws {
        let model = DesignStrokeSeed.cards(selecting: "node-3")
        #expect(model.selectedStroke?.width == 2)
        try shoot(StrokeSample(model: model), "design-stroke-editor")
    }

    @Test func noStroke() throws {
        let model = DesignStrokeSeed.cards(selecting: "node-3", stroked: false)
        #expect(model.selectedStroke == nil)
        try shoot(StrokeSample(model: model), "design-stroke-no-stroke")
    }

    @Test func dashed() throws {
        let border = DesignNode(id: "b", name: "Border", kind: .rectangle,
                                frame: DesignRect(x: 160, y: 120, width: 480, height: 280), fill: DesignColor(255, 255, 255),
                                cornerRadius: 12, stroke: DesignStrokeSeed.stroke)
        var dashed = try #require(border.vectorStroke)
        (dashed.dash, dashed.cap) = (StrokeRules.pattern(.dashed, width: 2), .round)
        #expect(dashed.dash == [8, 4])
        let line = ShapeSpec(kind: .line, start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))
        var rule = DesignNode(id: "l", name: "Rule", kind: .shape, frame: DesignRect(x: 200, y: 480, width: 400, height: 20),
                              stroke: DesignStroke(color: DesignColor(28, 28, 30), width: 6))
        rule.shape = line
        var ruleStroke = try #require(rule.vectorStroke)
        (ruleStroke.dash, ruleStroke.cap) = ([18, 12], .round)
        let art = DesignArtwork(painted: [
            DesignPainted(node: border, backdrop: nil, opacity: 1, stroke: dashed),
            DesignPainted(node: rule, backdrop: nil, opacity: 1, stroke: ruleStroke),
        ], zoom: 1)
        try shoot(art.background(SuiteColor.canvasSurround), "design-stroke-dashed")
    }
}

/// The canvas at 50% beside the inspector at the editor's panel width.
private struct StrokeSample: View {
    let model: DesignWorkspace
    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            DesignCanvas(model: model, zoom: 0.5)
            DesignInspector(model: model, perform: { _ in })
                // Scrolled to the end, where Stroke sits under Fill, so its editor rows show.
                .defaultScrollAnchor(.bottom)
                .frame(width: SuiteSize.editorPanelWidth)
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(SuiteSpacing.xxl)
        }
    }
}
