// DesignTextSnapshots.swift: Design's text on the canvas at half size, in Light and Dark: a
// text node placed with the Text tool and committed as "Hello", then the same node with its
// inline editor open. Writes design-text-{light,dark}.png and design-text-editing-{light,dark}.png.
// The canvas paints node text, so the first pair shows "Hello" once that lands; the second pair
// shows the editor's field over the node. macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignTextSnapshots {
    @Test func text() throws {
        var model = DesignWorkspace()
        model.newFile()
        model.selectTool(.text)
        let click = DesignPoint(x: 200, y: 200)
        model.drag(from: click, to: click)
        model.endDrag()
        model.setTextDraft("Hello")
        model.commitTextEdit()
        let node = try #require(model.selectedNode)
        #expect(node.kind == .text && node.text == "Hello" && model.editingTextID == nil)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignCanvas(model: model, zoom: 0.5), name: "design-text-\(scheme == .dark ? "dark" : "light")",
                scheme: scheme)
        }
        // Picking the node to edit opens the field over it, holding the node's text.
        try model.beginTextEdit(node.id)
        #expect(model.editingTextID == node.id && model.textDraft == "Hello")
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignCanvas(model: model, zoom: 0.5),
                name: "design-text-editing-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
