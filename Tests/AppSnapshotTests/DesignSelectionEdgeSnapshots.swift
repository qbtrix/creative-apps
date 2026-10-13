// DesignSelectionEdgeSnapshots.swift: selections the page edge and the zoom make
// hard to see. A frame drawn across the page's top edge, selected: its outline
// and top handles show past the edge. A "Hello" text node at the fit zoom of a
// laptop window (43%): selected, only its four corner handles show, outside the
// box; being edited, its field draws at full size. Writes
// design-selection-edge-, design-text-small- and design-text-small-editing-
// {light,dark}.png. macOS only.
import DesignModel
import Testing

@testable import DesignApp

@MainActor
@Suite struct DesignSelectionEdgeSnapshots {
    @Test func frameAcrossThePageTopShowsItsTopHandles() throws {
        var model = DesignWorkspace()
        model.newFile()
        drawOnCanvas(&model, .frame, from: (200, -80), to: (700, 400))
        #expect(model.selectedNode?.frame == DesignRect(x: 200, y: -80, width: 500, height: 480))
        try shootCanvas(model, "design-selection-edge")
    }

    @Test func smallTextShowsCornerHandlesAndEditsAtFullSize() throws {
        var model = DesignWorkspace()
        model.newFile()
        model.selectTool(.text)
        let click = DesignPoint(x: 300, y: 820)
        model.drag(from: click, to: click)
        model.endDrag()
        model.setTextDraft("Hello")
        model.commitTextEdit()
        let node = try #require(model.selectedNode)
        #expect(node.frame.isCompact(handleSize: 8 / 0.43))
        try shootCanvas(model, "design-text-small", zoom: 0.43)
        try model.beginTextEdit(node.id)
        try shootCanvas(model, "design-text-small-editing", zoom: 0.43)
    }
}
