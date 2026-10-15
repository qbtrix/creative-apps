// ProjectHistoryContractTests.swift: what every ProjectHistory promises
// (#208), run over each conforming type in `projectHistories`; the live type
// joins by adding itself there. Runs on Linux and macOS.
import HaloModel
import Testing

let projectHistories: [any ProjectHistory] = [FakeProjectHistory()]

@Test(arguments: projectHistories)
func historyCoalescesEndsAndClearsRedo(history: any ProjectHistory) {
    var h = HaloHistory()
    let a = HaloDocumentState(), b = HaloDocumentState(nextCompositionNumber: 2)
    history.record("Change Rotation", before: a, coalesceKey: "rot", in: &h)
    history.record("Change Rotation", before: b, coalesceKey: "rot", in: &h)
    #expect(h.undo.count == 1)
    #expect(h.undoTitle == "Undo Change Rotation")
    history.endCoalescing(in: &h)
    history.record("Change Rotation", before: b, coalesceKey: "rot", in: &h)
    #expect(h.undo.count == 2)
    #expect(history.undo(b, in: &h) == b)
    history.record("Change Rotation", before: a, coalesceKey: "rot", in: &h)
    #expect(h.redo.isEmpty)
}

@Test(arguments: projectHistories)
func theStepPastTheLimitDropsTheOldest(history: any ProjectHistory) {
    var h = HaloHistory()
    for n in 1...(history.limit + 1) {
        history.record("Step \(n)", before: HaloDocumentState(nextCompositionNumber: n), coalesceKey: nil, in: &h)
    }
    #expect(history.limit == 100)
    #expect(h.undo.count == 100)
    #expect(h.undo.first?.name == "Step 2")
    #expect(h.undoTitle == "Undo Step 101")
}

@Test(arguments: projectHistories)
func undoAndRedoWalkTheSteps(history: any ProjectHistory) {
    var h = HaloHistory()
    let a = HaloDocumentState(), b = HaloDocumentState(nextCompositionNumber: 2)
    #expect(history.undo(a, in: &h) == nil)
    #expect(history.redo(a, in: &h) == nil)
    history.record("New Composition", before: a, coalesceKey: nil, in: &h)
    #expect(history.undo(b, in: &h) == a)
    #expect(h.redoTitle == "Redo New Composition" && h.undoTitle == nil)
    #expect(history.redo(a, in: &h) == b)
    #expect(h.undoTitle == "Undo New Composition" && h.redoTitle == nil)
}
