// DesignInspectorSnapshots.swift: Design's inspector (Properties) at the
// editor's panel width: a page with no layer selected, a rectangle selected
// (Layer, Frame, Corners, Stroke and Fill), a locked rectangle (its rows
// disabled, with the hint saying why in the value column, whose x is checked
// against the X field's on the hosted view), a rectangle inside a locked group
// (disabled the same way), and A on `cards` styled: radius 12, opacity 50% and
// a 4 pt stroke, A's Fill section with its type switch, and A's Transform
// section. The styled A's Corners and Stroke sections also get a shot of their
// own, framing the whole stroke editor (Color, Width, Join, Cap, Dash, the dash
// note and Remove Stroke) that the full panel pushes below the fold (#3866),
// with a test that every stroke row sits inside the window. Writes
// design-inspector-page-, -node-, -locked-, -locked-group-, -style-, -stroke-,
// -fill- and -transform-{light,dark}.png. macOS only.
import AppKit
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignInspectorSnapshots {
    private func shoot(_ state: String, _ model: DesignWorkspace) throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                PanelSample(model: model), name: "design-inspector-\(state)-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
    }

    /// A on `cards` selected with radius 12, opacity 50% and a 4 pt black stroke.
    private func styledModel() throws -> DesignWorkspace {
        var model = DesignFixtures.cards
        model.useServices(.live)
        model.selectItem("node-2")
        try model.setStyle(.cornerRadius(12))
        try model.setStyle(.opacity(0.5))
        try model.setStyle(.stroke(DesignStroke(color: .black, width: 4)))
        return model
    }

    /// The stroke editor's rows (`suite.stroke.<row>`, no trim in Design), Remove Stroke last.
    static let strokeRows = ["color", "width", "join", "cap", "dash", "remove"].map { "suite.stroke.\($0)" }

    @Test func pageAndLayer() throws {
        var model = DesignWorkspace()
        model.newFile()
        try shoot("page", model)
        let box = DesignRect(x: 40.4, y: 56, width: 160.4, height: 119.6)
        let rectangle = try model.addNode(.rectangle, frame: box, in: "node-1")
        try model.setFill(rectangle, DesignColor(24, 119, 242))
        try shoot("node", model)
        try model.setNodeLocked(rectangle, true)
        try shoot("locked", model)
    }

    @Test func layerInsideALockedGroup() throws {
        var model = DesignWorkspace()
        model.newFile()
        let group = try model.addNode(.group, frame: DesignRect(x: 40, y: 40, width: 240, height: 180), in: "node-1")
        let rectangle = try model.addNode(.rectangle, frame: DesignRect(x: 60, y: 64, width: 120, height: 90), in: group)
        try model.setNodeLocked(group, true)
        model.selectItem(rectangle)
        try shoot("locked-group", model)
    }

    @Test func styledLayer() throws {
        let model = try styledModel()
        let a = try #require(model.selectedNode)
        #expect(a.cornerRadius == 12)
        #expect(a.opacity == 0.5)
        #expect(a.stroke == DesignStroke(color: .black, width: 4))
        #expect(model.opacityPercentText == "50%")
        try shoot("style", model)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(StrokeSample(model: model), name: "design-inspector-stroke-\(scheme.name)", scheme: scheme)
        }
    }

    /// The stroke shot frames the whole Stroke section: each row lies inside the 1440 x 900 window (#3866;
    /// in the full panel Dash and Remove Stroke fall below y = 900).
    @Test(.timeLimit(.minutes(1))) func strokeRowsInsideFrame() async throws {
        let model = try styledModel()
        let window = CGRect(x: 0, y: 0, width: 1440, height: 900)
        let w = RenderBudgetWindow(StrokeSample(model: model), size: window.size)
        defer { w.close() }
        try await w.settle(500)
        for id in Self.strokeRows {
            let frame = try #require(await w.element(id), "no \(id)")
            #expect(frame.height > 0 && frame.width > 0, "\(id) is \(frame)")
            #expect(window.contains(frame), "\(id) at \(frame) is outside the window")
        }
    }

    /// The Fill section's Solid/Linear/Radial switch over a solid rectangle, on now that gradient fills are
    /// built (gradient-fill DG-4).
    @Test func fillTypeSwitch() throws {
        var model = DesignFixtures.cards
        model.useServices(.live)
        model.selectItem("node-2")
        let selection = try #require(model.fillSelection)
        #expect(GradientRules.type(of: selection.fill) == .solid)
        #expect(model.fillHelp == nil)
        try shoot("fill", model)
    }

    /// The Transform section's Rotation bar and Flip buttons over A, on now the catalog has the
    /// transform specs (transform DT-6).
    @Test func transformRows() throws {
        var model = DesignFixtures.cards
        model.useServices(.live)
        model.selectItem("node-2")
        #expect(model.transformSelection?.degrees == 0)
        #expect(model.turnHelp == nil)
        try shoot("transform", model)
    }

    /// The hint starts where the X field does, not at the gutter (#276).
    @Test(.timeLimit(.minutes(1))) func lockedHintSitsInTheValueColumn() async throws {
        var model = DesignFixtures.cards
        model.useServices(.live)
        model.selectItem("node-2")
        try model.setNodeLocked("node-2", true)
        #expect(model.styleHint(.opacity) == "Unlock A to change it.")
        let w = RenderBudgetWindow(PanelSample(model: model))
        defer { w.close() }
        try await w.settle(500)
        let x = try #require(await w.element(DesignControlID.frameField(.x)), "no X field")
        let hint = try #require(await w.element("design.inspector.hint"), "no hint")
        #expect(abs(hint.minX - x.minX) < 1, "the hint starts at \(hint.minX), the X field at \(x.minX)")
    }
}

/// The Corners and Stroke sections alone at the panel's width, as the inspector lays them out.
private struct StrokeSample: View {
    let model: DesignWorkspace
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            DesignInspectorStyle(model: model, perform: { _ in })
        }
        .frame(width: SuiteSize.editorPanelWidth)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(SuiteSpacing.xxl)
    }
}

private struct PanelSample: View {
    let model: DesignWorkspace
    var body: some View {
        DesignInspector(model: model, perform: { _ in })
            .frame(width: SuiteSize.editorPanelWidth)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(SuiteSpacing.xxl)
    }
}
