// PhotoTextBoxKeyTests.swift (#4798, #5951): keys the canvas gets while a Type tool box is open type into it.
// The journey's flow on the model: Type tool, a click, "SUMMER SALE" a key at a time, Return, one text layer.
// Linux and macOS.
import CoreRaster
@testable import PhotoModel
import Testing

/// An 800 × 600 white image with the Type tool picked and a box open at (40, 60).
private func boxOpen() throws -> PhotoWorkspace {
    var workspace = PhotoWorkspace()
    try workspace.newCanvas(width: 800, height: 600)
    workspace.selectTool(.text)
    let at = Mask.Point(x: 40, y: 60)
    workspace.drag(from: at, to: at, modifiers: [])
    workspace.endDrag()
    return workspace
}

/// Presses each of `keys` on the canvas as PhotoEditor does: the box takes the ones it knows.
private func press(_ workspace: inout PhotoWorkspace, _ keys: [String]) {
    for characters in keys {
        guard let key = workspace.textBox?.key(characters) else { continue }
        workspace.pressTextKey(key)
    }
}

@Suite struct PhotoTextBoxKeyTests {
    @Test func lettersTypeAndReturnAddsTheLayer() throws {
        var workspace = try boxOpen()
        press(&workspace, "SUMMER SALE".map(String.init))
        #expect(workspace.textBox?.draft == "SUMMER SALE")
        #expect(workspace.tool == .text, "a letter picked a tool")
        press(&workspace, ["\r"])
        #expect(workspace.textBox == nil)
        #expect(workspace.layers.count == 2 && workspace.undoActionName == "Undo Add Text")
    }

    @Test func deleteDropsTheLastCharacter() throws {
        var workspace = try boxOpen()
        press(&workspace, ["S", "A", "L", "E", "\u{7F}"])
        #expect(workspace.textBox?.draft == "SAL")
    }

    @Test func escapeCancels() throws {
        var workspace = try boxOpen()
        press(&workspace, ["S", "\u{1B}"])
        #expect(workspace.textBox == nil && workspace.layers.count == 1)
    }

    @Test func arrowsAndEmptyPressesStayWithTheCanvas() {
        let box = PhotoTextBox(origin: Mask.Point(x: 0, y: 0), draft: "A")
        #expect(box.key("\u{F700}") == nil)
        #expect(box.key("") == nil)
        #expect(box.key("\t") == nil)
        #expect(box.key("é") == .type("Aé"))
    }

    @Test func noBoxIgnoresTheKey() throws {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 800, height: 600)
        workspace.pressTextKey(.type("SALE"))
        workspace.pressTextKey(.commit)
        #expect(workspace.textBox == nil && workspace.layers.count == 1)
    }
}
