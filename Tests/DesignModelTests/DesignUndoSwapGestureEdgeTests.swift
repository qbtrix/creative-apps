// DesignUndoSwapGestureEdgeTests.swift: edge cases for #435. undoSwapsDocument and
// redoSwapsDocument must agree with whether the next Undo/Redo runs and replaces
// the document, for every kind of open gesture (one that does nothing, one that
// never starts, one that opens a text edit) and across seeded random sessions.
// A failing seed replays. Runs on Linux and macOS.
import DesignModel
import Testing

/// A file with one rectangle, then New File over it: Undo is the New File swap.
private func swapOnTop() throws -> DesignWorkspace {
    var workspace = openDesign()
    try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: "node-1")
    workspace.newFile()
    return workspace
}

@Test func aPenDragThatDrawsNothingStillHidesTheSwap() throws {
    var workspace = try swapOnTop()
    workspace.selectTool(.pen)
    workspace.drag(from: pt(40, 40), to: pt(90, 90))
    #expect(!workspace.undoSwapsDocument, "Undo is ignored while any gesture is open")
    let pages = workspace.pages
    workspace.undo()
    #expect(workspace.pages == pages)
    workspace.endDrag()
    #expect(workspace.undoSwapsDocument)
}

@Test func aMovePressOnEmptyCanvasHidesTheSwapUntilRelease() throws {
    var workspace = try swapOnTop()
    workspace.undo()
    workspace.selectTool(.move)
    workspace.drag(from: pt(5000, 5000), to: pt(5010, 5010))
    #expect(!workspace.redoSwapsDocument)
    workspace.endDrag()
    #expect(workspace.redoSwapsDocument)
    workspace.redo()
    #expect(workspace.undoActionName == "Undo New File")
}

@Test func aDragWithANonFiniteStartOpensNoGestureSoTheSwapStays() throws {
    var workspace = try swapOnTop()
    workspace.selectTool(.rectangle)
    workspace.drag(from: pt(.nan, 0), to: pt(10, 10))
    #expect(workspace.undoSwapsDocument, "no gesture opened, so Undo runs")
    let pages = workspace.pages
    workspace.undo()
    #expect(workspace.pages != pages, "and it does replace the document")
}

@Test func aTextClickOpensAnEditThatHidesTheSwapUntilCancelled() throws {
    var workspace = try swapOnTop()
    workspace.selectTool(.text)
    workspace.drag(from: pt(200, 200), to: pt(200, 200))
    workspace.endDrag()
    #expect(workspace.editingTextID != nil)
    #expect(!workspace.undoSwapsDocument, "Undo is ignored while editing text")
    workspace.cancelTextEdit()
    #expect(workspace.undoSwapsDocument, "the cancelled text left no step, so New File is on top")
}

@Test func newFileMidDragEndsTheDragAndIsTheSwapOnTop() throws {
    var workspace = try swapOnTop()
    workspace.selectTool(.rectangle)
    workspace.drag(from: pt(40, 40), to: pt(120, 90))
    workspace.newFile()
    #expect(workspace.undoSwapsDocument)
    #expect(workspace.undoActionName == "Undo New File")
}

private struct SplitMix64: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(below bound: Int) -> Int { Int(next() % UInt64(Swift.max(bound, 1))) }
}

/// What the window can see of the workspace; an ignored Undo/Redo changes none of it.
private struct Visible: Equatable {
    var pages: [DesignPage]
    var selection: [String?]
    var names: [String]

    init(_ workspace: DesignWorkspace) {
        pages = workspace.pages
        selection = [workspace.selectedPageID, workspace.selectedNodeID, workspace.editingTextID]
        names = [workspace.undoActionName, workspace.redoActionName]
    }
}

@Test(arguments: 0..<24)
func swapFlagsAgreeWithWhatUndoAndRedoDoInRandomSessions(seed: UInt64) throws {
    var rng = SplitMix64(state: seed)
    var workspace = try swapOnTop()
    // The test's own record of an open gesture, kept apart from the Model's.
    var dragging = false
    let tools: [DesignTool] = [.move, .frame, .rectangle, .ellipse, .text, .pen]
    func point() -> DesignPoint { pt(Double(rng.next(below: 900)), Double(rng.next(below: 700))) }
    for step in 0..<150 {
        switch rng.next(below: 9) {
        case 0:
            workspace.newFile()
            dragging = false
        case 1, 2:
            let isLive = !dragging && workspace.editingTextID == nil
            let swaps = workspace.undoActionName == "Undo New File"
            #expect(workspace.undoSwapsDocument == (isLive && swaps), "seed \(seed) step \(step): undo flag")
            let flag = workspace.undoSwapsDocument
            let before = Visible(workspace)
            workspace.undo()
            if flag { #expect(workspace.redoActionName == "Redo New File", "seed \(seed) step \(step)") }
            if !isLive { #expect(Visible(workspace) == before, "seed \(seed) step \(step): ignored undo changed state") }
        case 3:
            let isLive = !dragging && workspace.editingTextID == nil
            let swaps = workspace.redoActionName == "Redo New File"
            #expect(workspace.redoSwapsDocument == (isLive && swaps), "seed \(seed) step \(step): redo flag")
            let flag = workspace.redoSwapsDocument
            let before = Visible(workspace)
            workspace.redo()
            if flag { #expect(workspace.undoActionName == "Undo New File", "seed \(seed) step \(step)") }
            if !isLive { #expect(Visible(workspace) == before, "seed \(seed) step \(step): ignored redo changed state") }
        case 4, 5:
            if !dragging { workspace.selectTool(tools[rng.next(below: tools.count)]) }
            workspace.drag(from: point(), to: point())
            dragging = true
        case 6:
            workspace.endDrag()
            dragging = false
        case 7:
            if rng.next(below: 2) == 0 { workspace.commitTextEdit() } else { workspace.cancelTextEdit() }
        default:
            workspace.setTextDraft(rng.next(below: 3) == 0 ? " " : "T\(step)")
        }
    }
}
