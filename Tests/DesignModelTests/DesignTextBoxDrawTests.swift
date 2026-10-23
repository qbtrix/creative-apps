// DesignTextBoxDrawTests.swift: a Text click-drag makes a fixed-width text box as
// wide as the drag, and a click keeps the default auto-width box (canvas-basics
// CB-3, packet docs/blueprints/design/features/canvas-basics.md, the CB-3
// acceptance row). `fixedWidth` is left out of the file when unset, so a file
// written before it opens as auto width and keeps its bytes. On `cards` with the
// live services. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import Testing

@Suite struct DesignTextBoxDrawTests {
    /// `cards` after one Text gesture from `start` to `end`; returns it and the placed node.
    private func drawText(_ start: DesignPoint, _ end: DesignPoint) throws -> (DesignWorkspace, DesignNode) {
        var workspace = DesignFixtures.cards
        #expect(workspace.services == .live)
        workspace.gesture(.text, start, end)
        let node = try #require(workspace.selectedNode)
        #expect(node.kind == .text)
        return (workspace, node)
    }

    @Test func aTextClickPlacesTheDefaultAutoWidthBox() throws {
        let (workspace, node) = try drawText(pt(200, 300), pt(200, 300))
        #expect(node.frame == rc(200, 300, 120, 24))
        #expect(node.textStyle.fixedWidth == nil)
        #expect(workspace.editingTextID == node.id)
    }

    @Test func aTextDragMakesAFixedWidthBoxAsWideAsTheDragAndOpensItsEdit() throws {
        let (workspace, node) = try drawText(pt(200, 300), pt(500.4, 310))
        #expect(node.frame == rc(200, 300, 300, 24))
        #expect(node.textStyle.fixedWidth == true)
        #expect(workspace.editingTextID == node.id && workspace.textDraft == "Text")
        #expect(workspace.tool == .move)
    }

    @Test func aShortDragGivesTheMinimumWidth() throws {
        let (_, node) = try drawText(pt(200, 300), pt(203, 300))
        #expect(node.frame == rc(200, 300, 8, 24))
        #expect(node.textStyle.fixedWidth == true)
    }

    @Test func aTallDragKeepsItsHeight() throws {
        let (_, node) = try drawText(pt(200, 300), pt(260, 380))
        #expect(node.frame == rc(200, 300, 60, 80))
    }

    @Test func aDragOrClickIsOneAddTextStep() throws {
        for end in [pt(200, 300), pt(500.4, 310)] {
            let (drawn, node) = try drawText(pt(200, 300), end)
            var workspace = drawn
            #expect(!workspace.canUndo)
            workspace.setTextDraft("Hello")
            workspace.commitTextEdit()
            #expect(workspace.undoActionName == "Undo Add Text")
            workspace.undo()
            #expect(workspace.treeNode(node.id) == nil && !workspace.canUndo)
            workspace.redo()
            #expect(workspace.treeNode(node.id)?.textStyle == node.textStyle)
        }
    }

    @Test func aFileHoldingOneOfEachRoundTrips() throws {
        let (drawn, click) = try drawText(pt(200, 300), pt(200, 300))
        var workspace = drawn
        workspace.commitTextEdit()
        workspace.gesture(.text, pt(200, 400), pt(500.4, 410))
        let drag = try #require(workspace.selectedNode)
        workspace.commitTextEdit()
        let data = try workspace.fileData()
        var opened = DesignWorkspace()
        try opened.open(data)
        #expect(opened.treeNode(click.id)?.textStyle.fixedWidth == nil)
        #expect(opened.treeNode(drag.id)?.textStyle.fixedWidth == true)
        #expect(opened.treeNode(drag.id)?.frame == rc(200, 400, 300, 24))
        #expect(try opened.fileData() == data)
    }

    @Test func aFileWithoutTheKeyOpensAsAutoWidthWithTheSameBytes() throws {
        let (drawn, click) = try drawText(pt(200, 300), pt(200, 300))
        var workspace = drawn
        workspace.commitTextEdit()
        let data = try workspace.fileData()
        #expect(String(decoding: data, as: UTF8.self).contains("fixedWidth") == false)
        var opened = DesignWorkspace()
        try opened.open(data)
        #expect(opened.treeNode(click.id)?.textStyle.fixedWidth == nil)
        #expect(try opened.fileData() == data)
    }

    @Test func aStyleDecodesItsFlagAndLeavesANilOneOut() throws {
        let old = Data(#"{"alignment":"leading","family":"System","size":16,"weight":400}"#.utf8)
        let style = try JSONDecoder().decode(DesignTextStyle.self, from: old)
        #expect(style == .default && style.fixedWidth == nil)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(try encoder.encode(style) == old)
        var fixed = style
        fixed.fixedWidth = true
        #expect(try JSONDecoder().decode(DesignTextStyle.self, from: encoder.encode(fixed)) == fixed)
    }
}
