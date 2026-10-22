// PhotoTextBoxTests.swift (text-layers TX-3): the Type tool's text box. A click with the Type tool opens a
// box at the press; typing changes its draft; Esc cancels it; Return, a click elsewhere or another tool
// commits it through `text.add`. Until TX-5 builds that command the commit adds nothing and says so in the
// status line, and an empty box closes without a word. Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

/// An 800 × 600 white image with the Type tool picked.
private func typing() throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 800, height: 600)
    workspace.selectTool(.text)
    return workspace
}

/// A click at (x, y): press and release in place.
private func click(_ workspace: inout PhotoWorkspace, _ x: Double, _ y: Double) {
    let at = Mask.Point(x: x, y: y)
    workspace.drag(from: at, to: at, modifiers: [])
    workspace.endDrag()
}

@Suite struct PhotoTextBoxTests {
    @Test func theTypeToolIsEnabled() {
        #expect(PhotoTool.allCases.contains(.text))
        #expect(PhotoTool.text.isEnabled)
        #expect(PhotoWorkspace().toolHelp(.text) == nil)
    }

    @Test func aClickOpensABoxAtThePress() throws {
        var workspace = try typing()
        #expect(workspace.textBox == nil)
        click(&workspace, 40, 60)
        #expect(workspace.textBox == PhotoTextBox(origin: Mask.Point(x: 40, y: 60), draft: ""))
        #expect(!workspace.isDragging)
        #expect(workspace.layers.count == 1, "opening a box added a layer")
    }

    @Test func typingChangesTheDraftOnly() throws {
        var workspace = try typing()
        click(&workspace, 40, 60)
        let revision = workspace.revision
        workspace.typeText("SALE")
        #expect(workspace.textBox?.draft == "SALE")
        #expect(workspace.revision == revision && !workspace.canUndo)
    }

    @Test func typingWithNoBoxDoesNothing() throws {
        var workspace = try typing()
        workspace.typeText("SALE")
        #expect(workspace.textBox == nil)
    }

    @Test func escapeCancels() throws {
        var workspace = try typing()
        click(&workspace, 40, 60)
        workspace.typeText("SALE")
        workspace.cancelTextBox()
        #expect(workspace.textBox == nil)
        #expect(workspace.statusMessage == nil && workspace.layers.count == 1)
    }

    @Test func committingOnTheStubsSaysWhyAndAddsNothing() throws {
        var workspace = try typing()
        click(&workspace, 40, 60)
        workspace.typeText("SALE")
        workspace.commitTextBox()
        #expect(workspace.textBox == nil)
        #expect(workspace.layers.count == 1 && !workspace.canUndo)
        #expect(workspace.statusMessage == "Text arrives with TX-5.")
    }

    @Test func anEmptyBoxClosesSilently() throws {
        var workspace = try typing()
        click(&workspace, 40, 60)
        workspace.commitTextBox()
        #expect(workspace.textBox == nil && workspace.statusMessage == nil)
    }

    @Test func aClickElsewhereCommitsAndOpensANewBox() throws {
        var workspace = try typing()
        click(&workspace, 40, 60)
        workspace.typeText("SALE")
        click(&workspace, 300, 200)
        #expect(workspace.textBox == PhotoTextBox(origin: Mask.Point(x: 300, y: 200), draft: ""))
        #expect(workspace.statusMessage == "Text arrives with TX-5.")
    }

    @Test func anotherToolCommitsTheBox() throws {
        var workspace = try typing()
        click(&workspace, 40, 60)
        workspace.typeText("SALE")
        workspace.selectTool(.brush)
        #expect(workspace.textBox == nil)
        #expect(workspace.statusMessage == "Text arrives with TX-5.")
    }

    @Test func noImageOpensNoBox() {
        var workspace = PhotoWorkspace()
        workspace.selectTool(.text)
        click(&workspace, 40, 60)
        #expect(workspace.textBox == nil)
    }
}
