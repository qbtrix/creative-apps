// DesignTextSnapshots.swift: Design's text on the canvas, in Light and Dark. A text node placed
// with the Text tool and committed as "Hello", then the same node with its inline editor open
// (design-text-{light,dark}.png, design-text-editing-{light,dark}.png). Title on `cards` set to
// 32 pt Bold Center and committed as "Big title" at 50% (design-text-committed-50-*.png), and a
// page of text layers at several sizes, weights and alignments in the system family drawn by the
// artwork (design-text-sizes-*.png): the canvas draws each in its own style (style-rows ST-5t).
// macOS only.
import DesignModel
import SuiteUI
import SwiftUI
import Testing

@testable import DesignApp
@testable import DesignModel

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

    @Test func committedAtHalfSize() throws {
        var model = DesignWorkspace()
        model.useServices(.fake)
        let opened = model.openFixture("cards")
        #expect(opened)
        model.selectItem("node-5")
        var style = try #require(model.selectedNode).textStyle
        style.size = 32
        style.weight = 700
        style.alignment = .center
        try model.setStyle(.textStyle(style))
        model.endEditRun()
        try model.beginTextEdit("node-5")
        model.setTextDraft("Big title")
        model.commitTextEdit()
        #expect(model.findNode("node-5")?.text == "Big title" && model.editingTextID == nil)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignCanvas(model: model, zoom: 0.5),
                name: "design-text-committed-50-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }

    @Test func sizesWeightsAndAlignments() throws {
        let rows: [(size: Double, weight: Int, alignment: DesignTextAlignment)] = [
            (12, 400, .leading), (16, 400, .leading), (16, 700, .leading), (24, 300, .center),
            (32, 700, .center), (48, 900, .trailing),
        ]
        var texts: [DesignNode] = []
        var top = 24.0
        for (index, row) in rows.enumerated() {
            let style = DesignTextStyle(
                family: DesignTextStyle.default.family, size: row.size, weight: row.weight, alignment: row.alignment)
            texts.append(DesignNode(
                id: "t\(index)", name: "T\(index)", kind: .text,
                frame: DesignRect(x: 24, y: top, width: 560, height: row.size * 1.4), fill: .black,
                text: "\(Int(row.size)) pt, weight \(row.weight)", textStyle: style))
            top += row.size * 1.6
        }
        let frame = DesignNode(
            id: "f", name: "F", kind: .frame, frame: DesignRect(x: 0, y: 0, width: 608, height: top + 24),
            children: texts, fill: .white)
        let page = DesignPage(id: "p", name: "P", frameWidth: 608, frameHeight: top + 24, nodes: [frame])
        #expect(page.painted.count == rows.count + 1)
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(
                DesignArtwork(painted: page.painted, zoom: 1),
                name: "design-text-sizes-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}
