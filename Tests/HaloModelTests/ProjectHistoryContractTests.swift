// ProjectHistoryContractTests.swift: what every ProjectHistory promises
// (#208, HF-1), run over the fake and the live type in `projectHistories`.
// Both call HaloHistoryRules, so they must agree. Runs on Linux and macOS.
import HaloModel
import Testing

let projectHistories: [any ProjectHistory] = [FakeProjectHistory(), LiveProjectHistory()]

private func state(_ n: Int) -> HaloDocumentState { HaloDocumentState(nextCompositionNumber: n) }

@Test(arguments: projectHistories)
func fakeHistoryCoalescesEndsAndClearsRedo(history: any ProjectHistory) {
    var h = HaloHistory()
    let a = HaloDocumentState(), b = state(2)
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
func threeCoalescedRecordsAreOneStepKeepingTheFirstBefore(history: any ProjectHistory) {
    var h = HaloHistory()
    for n in 1...3 { history.record("Change Rotation", before: state(n), coalesceKey: "rot", in: &h) }
    #expect(h.undo.count == 1)
    #expect(h.undo.first?.before == state(1))
    history.endCoalescing(in: &h)
    history.record("Change Rotation", before: state(4), coalesceKey: "rot", in: &h)
    #expect(h.undo.count == 2)
    #expect(h.undo.last?.before == state(4))
}

@Test(arguments: projectHistories)
func aCoalescedRecordAfterAnUndoStillEmptiesRedo(history: any ProjectHistory) {
    var h = HaloHistory()
    history.record("Change Rotation", before: state(1), coalesceKey: "rot", in: &h)
    history.record("Change Rotation", before: state(2), coalesceKey: "rot", in: &h)
    _ = history.undo(state(3), in: &h)
    #expect(h.redo.count == 1)
    history.record("New Layer", before: state(1), coalesceKey: "layer", in: &h)
    history.record("New Layer", before: state(2), coalesceKey: "layer", in: &h)
    #expect(h.undo.count == 1 && h.redo.isEmpty)
}

@Test(arguments: projectHistories)
func theStepPastTheLimitDropsTheOldest(history: any ProjectHistory) {
    var h = HaloHistory()
    for n in 1...(history.limit + 1) {
        history.record("Step \(n)", before: state(n), coalesceKey: nil, in: &h)
    }
    #expect(history.limit == 100)
    #expect(h.undo.count == 100)
    #expect(h.undo.first?.name == "Step 2")
    #expect(h.undoTitle == "Undo Step 101")
}

@Test(arguments: projectHistories)
func undoAndRedoWalkTheSteps(history: any ProjectHistory) {
    var h = HaloHistory()
    let a = HaloDocumentState(), b = state(2)
    #expect(history.undo(a, in: &h) == nil)
    #expect(history.redo(a, in: &h) == nil)
    history.record("New Composition", before: a, coalesceKey: nil, in: &h)
    #expect(history.undo(b, in: &h) == a)
    #expect(h.redoTitle == "Redo New Composition" && h.undoTitle == nil)
    #expect(history.redo(a, in: &h) == b)
    #expect(h.undoTitle == "Undo New Composition" && h.redoTitle == nil)
    #expect(history.redo(b, in: &h) == nil)
}

@Test(arguments: projectHistories)
func endCoalescingOnAnEmptyHistoryChangesNothing(history: any ProjectHistory) {
    var h = HaloHistory()
    history.endCoalescing(in: &h)
    #expect(h == HaloHistory())
}

@Test func liveHistoryIsAvailable() {
    #expect(LiveProjectHistory().unavailableHelp == nil)
    #expect(LiveProjectHistory().limit == 100)
}
