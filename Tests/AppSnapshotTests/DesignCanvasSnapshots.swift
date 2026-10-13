// DesignCanvasSnapshots.swift: Design's canvas (DesignCanvas at half size) with a rectangle and an
// ellipse drawn on a new file, first with nothing selected and then with the rectangle selected
// (its outline and eight handles), and at full size a text node, drawn and then while it is being
// edited (the canvas leaves its text out; the inline field sits there). Each state writes
// design-canvas-<state>-light.png and -dark.png. The paint-order test pins what the canvas paints.
// shootCanvas and drawOnCanvas are shared by DesignDrawSnapshots and DesignResizeSnapshots.
import DesignModel
import SwiftUI
import Testing

@testable import DesignApp

/// Plays one whole gesture of `tool` from `start` to `end` the way the canvas sends it: the press,
/// a move, then the release.
@MainActor
func drawOnCanvas(
    _ model: inout DesignWorkspace, _ tool: DesignTool, from start: (Double, Double), to end: (Double, Double)
) {
    let (a, b) = (DesignPoint(x: start.0, y: start.1), DesignPoint(x: end.0, y: end.1))
    model.selectTool(tool)
    model.drag(from: a, to: a)
    model.drag(from: a, to: b)
    model.endDrag()
}

/// Writes `<name>-light.png` and `<name>-dark.png`: the model's canvas at `zoom`.
@MainActor
func shootCanvas(_ model: DesignWorkspace, _ name: String, zoom: Double = 0.5) throws {
    for scheme in [ColorScheme.light, .dark] {
        try snapshot(
            DesignCanvas(model: model, zoom: zoom), name: "\(name)-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
    }
}

@MainActor
@Suite struct DesignCanvasSnapshots {
    /// A new file with a rectangle and then an ellipse drawn on its Desktop frame, nothing selected;
    /// the rectangle's id comes back too.
    private func sketch() throws -> (model: DesignWorkspace, rectangle: String) {
        var model = DesignWorkspace()
        model.newFile()
        drawOnCanvas(&model, .rectangle, from: (160, 160), to: (640, 480))
        let rectangle = try #require(model.selectedNodeID)
        drawOnCanvas(&model, .ellipse, from: (760, 300), to: (1160, 700))
        model.deselect()
        return (model, rectangle)
    }

    @Test func shapes() throws {
        let (model, _) = try sketch()
        #expect(model.selectedNodeID == nil)
        try shootCanvas(model, "design-canvas")
    }

    @Test func selectedRectangle() throws {
        let drawn = try sketch()
        var model = drawn.model
        model.selectItem(drawn.rectangle)
        #expect(model.selectedNode?.kind == .rectangle)
        try shootCanvas(model, "design-canvas-selected")
    }

    /// A text node wide enough to wrap, placed with the Text tool and committed.
    private func typed() throws -> (model: DesignWorkspace, text: String) {
        var model = DesignWorkspace()
        model.newFile()
        drawOnCanvas(&model, .text, from: (200, 220), to: (200, 220))
        let text = try #require(model.editingTextID)
        model.setTextDraft("Design in the open: a longer line that wraps inside its box")
        model.commitTextEdit()
        try model.setNodeFrame(text, x: 200, y: 220, width: 260, height: 64)
        return (model, text)
    }

    @Test func textNode() throws {
        let made = try typed()
        #expect(made.model.selectedNode?.text == "Design in the open: a longer line that wraps inside its box")
        #expect(made.model.selectedNodeID == made.text)
        try shootCanvas(made.model, "design-canvas-text", zoom: 1)
    }

    @Test func textWhileEditing() throws {
        let made = try typed()
        var model = made.model
        try model.beginTextEdit(made.text)
        #expect(model.editingTextID == made.text)
        try shootCanvas(model, "design-canvas-editing", zoom: 1)
    }

    @Test func paintOrderSkipsHiddenSubtreesAndTracksTheFillBehind() throws {
        var model = DesignWorkspace()
        model.newFile()
        // Desktop (node-1) holds a group (node-2) holding a rectangle (node-3), then an ellipse (node-4).
        let box = DesignRect(x: 100, y: 100, width: 200, height: 200)
        try model.addNode(.group, frame: box, in: "node-1")
        try model.addNode(.rectangle, frame: box, in: "node-2")
        try model.addNode(.ellipse, frame: box, in: "node-1")
        var page = try #require(model.selectedPage)
        #expect(page.painted.map(\.id) == ["node-1", "node-2", "node-3", "node-4"])
        // A group is no frame, so its child sits on the Desktop's fill, and the Desktop on the bare page.
        #expect(page.painted.map(\.backdrop) == [nil, .white, .white, .white])
        // Hiding the group takes its rectangle with it; a black Desktop is what the ellipse then sits on.
        try model.setNodeHidden("node-2", true)
        try model.setFill("node-1", .black)
        page = try #require(model.selectedPage)
        #expect(page.painted.map(\.id) == ["node-1", "node-4"])
        #expect(page.painted.map(\.backdrop) == [nil, .black])
    }
}
