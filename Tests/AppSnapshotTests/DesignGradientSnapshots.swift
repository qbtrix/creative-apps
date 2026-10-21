// DesignGradientSnapshots.swift (gradient-fill DG-6): Design's gradient fills on the canvas and in the
// inspector's Fill section, side by side at the editor's panel width. `cards` opened with A (node-2) given a
// blue-to-white linear gradient and Title (node-5) a radial one, as a file saved with them opens (the fill
// commands are DG-4's), then: A selected (the chips on Linear, SuiteUI's GradientEditor with its stop bar,
// colour and angle rows), Title selected (Radial, no angle row, the text painted through the radial), and B
// (solid) selected, the chips on Solid with no editor. Writes design-fill-linear-, design-fill-radial-text- and
// design-fill-solid-switch-{light,dark}.png. `DesignGradientSeed` is the document RenderBudgetDesignGradientTests
// drives too. macOS only.
import AppKit
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

/// `cards` with A's linear and Title's radial gradient, as a file holding them opens.
enum DesignGradientSeed {
    static let blue = FillColor(r: 0.09, g: 0.47, b: 0.95)
    static let stops = [GradientStop(offset: 0, color: blue), GradientStop(offset: 1, color: FillColor(r: 1, g: 1, b: 1))]
    static let linear = Fill.linear(stops: stops, start: Point(x: 0, y: 0.5), end: Point(x: 1, y: 0.5))
    static let radial = Fill.radial(stops: stops, center: Point(x: 0.5, y: 0.5), radius: 0.5)

    /// The workspace with `selected` selected.
    static func cards(selecting selected: String) -> DesignWorkspace {
        var model = DesignFixtures.cards
        model.useServices(.live)
        func filled(_ nodes: [DesignNode]) -> [DesignNode] {
            nodes.map { node in
                var node = node
                node.gradient = ["node-2": linear, "node-5": radial][node.id] ?? node.gradient
                node.children = filled(node.children)
                return node
            }
        }
        model.load(model.pages.map { page in
            var page = page
            page.nodes = filled(page.nodes)
            return page
        })
        model.selectItem(selected)
        return model
    }
}

@MainActor
@Suite struct DesignGradientSnapshots {
    private func shoot(_ model: DesignWorkspace, _ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(FillSample(model: model), name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func linear() throws {
        let model = DesignGradientSeed.cards(selecting: "node-2")
        let selection = try #require(model.fillSelection)
        #expect(GradientRules.type(of: selection.fill) == .linear)
        try shoot(model, "design-fill-linear")
    }

    @Test func radialText() throws {
        let model = DesignGradientSeed.cards(selecting: "node-5")
        #expect(model.selectedNode?.kind == .text)
        #expect(model.fillSelection.map { GradientRules.type(of: $0.fill) } == .radial)
        try shoot(model, "design-fill-radial-text")
    }

    @Test func solidSwitch() throws {
        let model = DesignGradientSeed.cards(selecting: "node-3")
        #expect(model.fillSelection.map { GradientRules.type(of: $0.fill) } == .solid)
        try shoot(model, "design-fill-solid-switch")
    }
}

/// The canvas at 50% beside the inspector at the editor's panel width.
private struct FillSample: View {
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
