// PhotoTextEditTests.swift (text-layers TX-4): editing a text layer's words. A Type tool click (so a
// double-click) on a text layer opens a box over it holding its words and selects it; its commit runs
// `text.set-words`, one "Edit Text" step; unchanged words add no step. Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

/// An 800 × 600 white image with a "SALE" text layer at (40, 60), the Type tool picked.
private func withText() throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 800, height: 600)
    workspace.selectTool(.text)
    click(&workspace, 40, 60)
    workspace.typeText("SALE")
    workspace.commitTextBox()
    return workspace
}

/// A click at (x, y): press and release in place.
private func click(_ workspace: inout PhotoWorkspace, _ x: Double, _ y: Double) {
    let at = Mask.Point(x: x, y: y)
    workspace.drag(from: at, to: at, modifiers: [])
    workspace.endDrag()
}

@Suite struct PhotoTextEditTests {
    @Test func aClickOnATextLayerEditsItsWords() throws {
        var workspace = try withText()
        let text = try #require(workspace.selectedLayerID)
        workspace.selectLayer(try #require(workspace.layers.last?.id))
        click(&workspace, 45, 70)
        let box = try #require(workspace.textBox)
        #expect(box.draft == "SALE" && box.editing == text)
        #expect(box.origin == Mask.Point(x: 40, y: 60))
        #expect(workspace.selectedLayerID == text)
    }

    @Test func committingAnEditReplacesTheWordsInOneStep() throws {
        var workspace = try withText()
        click(&workspace, 45, 70)
        workspace.typeText("SALE NOW")
        workspace.commitTextBox()
        #expect(workspace.textBox == nil && workspace.statusMessage == nil)
        #expect(workspace.layers.count == 2 && workspace.undoActionName == "Undo Edit Text")
        guard case .text(let text) = workspace.selectedLayer?.kind else { Issue.record("not a text layer"); return }
        #expect(text.words == "SALE NOW")
        workspace.undo()
        guard case .text(let back) = workspace.selectedLayer?.kind else { Issue.record("not a text layer"); return }
        #expect(back.words == "SALE")
    }

    @Test func unchangedWordsAddNoStep() throws {
        var workspace = try withText()
        let revision = workspace.revision
        click(&workspace, 45, 70)
        workspace.commitTextBox()
        #expect(workspace.revision == revision && workspace.undoActionName == "Undo Add Text")
    }

    @Test func aClickBesideTheTextOpensANewBox() throws {
        var workspace = try withText()
        click(&workspace, 600, 400)
        #expect(workspace.textBox == PhotoTextBox(origin: Mask.Point(x: 600, y: 400), draft: ""))
    }

    @Test func aHiddenTextLayerIsNotEdited() throws {
        var workspace = try withText()
        workspace.toggleVisibility(try #require(workspace.selectedLayerID))
        click(&workspace, 45, 70)
        #expect(workspace.textBox?.editing == nil && workspace.textBox?.draft == "")
    }
}
