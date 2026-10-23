// DesignJ5KeysTests.swift: the canvas keys (DesignCanvasKeys, #2706) and J5's steps 4
// and 5 (DesignSelectJourneyTests, select-several SS-a). macOS marks every arrow press
// as a numeric-pad key, so ⇧→ arrives as Shift plus numeric pad and must still nudge;
// Command, Option or Control leaves the key to the menus. After J5's marquee, move and
// resize on `cards` with the live services, ⇧→ moves A and B 10 right as one Nudge
// step, and ⌫ removes both as one Delete step that ⌘Z takes back. Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignJ5KeysTests {
    /// J5 up to the resize: A and B selected, Undo reads Undo Resize.
    static func resized() -> DesignWorkspace {
        var workspace = DesignJ5GeometryTests.moved()
        workspace.gesture(.move, pt(540, 220), pt(560, 220))
        return workspace
    }

    @Test func anArrowWithTheNumericPadFlagNudgesSeveralLayers() {
        let workspace = Self.resized()
        #expect(workspace.hasSelection)
        #expect(workspace.canvasKeyAction(.arrow(.right), modifiers: [.shift, .numericPad]) == .nudge(.right, shift: true))
        #expect(workspace.canvasKeyAction(.arrow(.up), modifiers: [.numericPad, .capsLock]) == .nudge(.up, shift: false))
        #expect(workspace.canvasKeyAction(.delete, modifiers: []) == .deleteSelection)
    }

    @Test func commandOptionOrControlLeavesTheKeyToTheMenus() {
        let workspace = Self.resized()
        for held: DesignKeyModifiers in [.command, .option, .control, [.shift, .numericPad, .command]] {
            #expect(workspace.canvasKeyAction(.arrow(.right), modifiers: held) == nil)
            #expect(workspace.canvasKeyAction(.delete, modifiers: held) == nil)
        }
    }

    @Test func withNothingSelectedArrowsAndDeleteAreLeftToTheSystem() {
        var workspace = Self.resized()
        workspace.deselect()
        #expect(!workspace.hasSelection)
        #expect(workspace.canvasKeyAction(.arrow(.left), modifiers: .numericPad) == nil)
        #expect(workspace.canvasKeyAction(.delete, modifiers: []) == nil)
        #expect(workspace.canvasKeyAction(.escape, modifiers: []) == .deselect)
    }

    @Test func returnEditsASelectedTextNodeOnly() {
        var workspace = DesignFixtures.cards
        workspace.selectItem("node-5")
        #expect(workspace.canvasKeyAction(.enter, modifiers: []) == .editText("node-5"))
        workspace.selectItem("node-2")
        #expect(workspace.canvasKeyAction(.enter, modifiers: []) == nil)
    }

    @Test func shiftRightNudgesBothTenAsOneStep() {
        var workspace = Self.resized()
        let before = workspace.selectionBounds
        workspace.nudge(.right, shift: true)
        #expect(workspace.undoActionName == "Undo Nudge")
        #expect(workspace.selectedNodeIDs == ["node-2", "node-3"])
        #expect(workspace.selectionBounds?.x == before.map { $0.x + 10 })
    }

    @Test func deleteRemovesBothAsOneStepThatUndoBringsBack() {
        var workspace = Self.resized()
        workspace.nudge(.right, shift: true)
        workspace.deleteSelection()
        #expect(workspace.undoActionName == "Undo Delete")
        #expect(workspace.selectedPage?.nodes.node("node-2") == nil)
        #expect(workspace.selectedPage?.nodes.node("node-3") == nil)
        workspace.undo()
        #expect(workspace.selectedPage?.nodes.node("node-2") != nil)
        #expect(workspace.selectedPage?.nodes.node("node-3") != nil)
        #expect(workspace.undoActionName == "Undo Nudge")
    }
}
