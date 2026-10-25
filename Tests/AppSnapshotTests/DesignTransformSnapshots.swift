// DesignTransformSnapshots.swift (transform DT-4): Design's turned and mirrored layers on the canvas and the
// inspector's Transform rows. `cards` opened with C (node-4) turned 30° and selected, as a file saved with the
// turn opens: the canvas paints C turned with its handles turned too, and the inspector's Rotation reads
// 30°. Then A (node-2) with a blue-to-white linear gradient mirrored across and Title (node-5) mirrored
// across, A selected. Then the Transform section alone at the editor's panel width over the turned C, its
// Rotation reading 30° and its Rotation and Flip controls live (no `turnHelp`). Writes
// design-transform-turned-, design-transform-flipped- and design-transform-rows-{light,dark}.png.
// `DesignTransformSeed` is the document RenderBudgetDesignTransformTests drives too. macOS only.
import AppKit
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

/// `cards` with nodes turned or mirrored, as a file holding them opens.
enum DesignTransformSeed {
    /// The workspace with each node in `edits` changed by its closure, and `selected` selected.
    static func cards(selecting selected: String, _ edits: [String: (inout DesignNode) -> Void]) -> DesignWorkspace {
        var model = DesignFixtures.cards
        model.useServices(.live)
        func edited(_ nodes: [DesignNode]) -> [DesignNode] {
            nodes.map { node in
                var node = node
                edits[node.id]?(&node)
                node.children = edited(node.children)
                return node
            }
        }
        model.load(model.pages.map { page in
            var page = page
            page.nodes = edited(page.nodes)
            return page
        })
        model.selectItem(selected)
        return model
    }

    /// C (node-4, 700 100 100 × 120) turned 30° clockwise and selected.
    static var turned: DesignWorkspace { cards(selecting: "node-4", ["node-4": { $0.rotation = 30 }]) }

    /// A on a linear gradient mirrored across, Title mirrored across, A selected.
    static var flipped: DesignWorkspace {
        cards(selecting: "node-2", [
            "node-2": { $0.gradient = DesignGradientSeed.linear; $0.flipX = true },
            "node-5": { $0.flipX = true },
        ])
    }
}

@MainActor
@Suite struct DesignTransformSnapshots {
    private func shoot(_ view: some View, _ name: String) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(view, name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func turned() throws {
        let model = DesignTransformSeed.turned
        #expect(model.selectedNode?.rotation == 30)
        #expect(model.transformSelection?.degrees == 30)
        try shoot(TransformSample(model: model), "design-transform-turned")
    }

    @Test func flipped() throws {
        let model = DesignTransformSeed.flipped
        #expect(model.selectedNode?.flipX == true)
        #expect(model.transformSelection?.flipX == true)
        #expect(model.findNode("node-5")?.flipX == true)
        try shoot(TransformSample(model: model), "design-transform-flipped")
    }

    @Test func rows() throws {
        let model = DesignTransformSeed.turned
        #expect(model.transformSelection?.degrees == 30)
        #expect(model.sharedValue(\.rotation) == 30, "Rotation reads 30°, not Mixed")
        #expect(model.turnHelp == nil, "Rotation and both Flips are live on an unlocked layer")
        try shoot(RowsSample(model: model), "design-transform-rows")
    }
}

/// The canvas at 50% beside the inspector at the editor's panel width.
private struct TransformSample: View {
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

/// The Transform section alone at the panel's width, as the inspector lays it out.
private struct RowsSample: View {
    let model: DesignWorkspace
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DesignInspectorTransform(model: model, perform: { _ in })
        }
        .frame(width: SuiteSize.editorPanelWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(SuiteSpacing.xxl)
    }
}
