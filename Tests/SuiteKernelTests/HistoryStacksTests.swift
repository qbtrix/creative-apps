// HistoryStacksTests.swift: what an app adapter reads from the kernel history
// (#2938, Design's undo on History): the undo and redo stacks with their names,
// payloads and step ids, `markSaved` at the current step, and two histories
// comparing equal exactly when their steps and ids do.
import Testing
import SuiteKernel

@Suite struct HistoryStacksTests {
    @Test func theStacksHoldNamesPayloadsAndIDs() {
        var history = History<String>()
        history.record("Move", "a")
        history.record("Fill", "b")
        #expect(history.undoSteps.map(\.name) == ["Move", "Fill"])
        #expect(history.undoSteps.map(\.payload) == ["a", "b"])
        #expect(history.undoSteps.last?.idAfter == history.currentStepID)
        #expect(history.undo { "redo:" + $0 })
        #expect(history.undoSteps.map(\.name) == ["Move"])
        #expect(history.redoSteps.map(\.payload) == ["redo:b"])
        #expect(history.redoSteps.last?.idBefore == history.currentStepID)
    }

    @Test func markSavedCleansTheCurrentStep() {
        var history = History<String>()
        history.record("Move", "a")
        #expect(history.isDirty)
        history.markSaved()
        #expect(!history.isDirty && history.savedStepID == history.currentStepID)
        _ = history.undo { $0 }
        #expect(history.isDirty)
        _ = history.redo { $0 }
        #expect(!history.isDirty)
    }

    @Test func historiesAreEqualOnlyWithTheSameSteps() {
        var a = History<String>(), b = History<String>()
        #expect(a == b)
        a.record("Move", "a")
        #expect(a != b)
        b.record("Move", "a")
        #expect(a == b)
        b.markSaved()
        #expect(a != b)
    }
}
