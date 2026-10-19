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

/// A history is Hashable when its payload is (#2747: Halo's undo state is
/// Hashable): equal histories hash alike, and the saved mark and the redo
/// stack each change the hash.
@Suite struct HistoryHashTests {
    @Test func equalHistoriesHashAlike() {
        var a = History<String>(), b = History<String>()
        a.record("Move", "a", key: "drag")
        b.record("Move", "a", key: "drag")
        #expect(a == b && a.hashValue == b.hashValue)
        #expect(Set([a, b]).count == 1)
        #expect(a.undoSteps.last?.hashValue == b.undoSteps.last?.hashValue)
    }

    @Test func theSavedMarkChangesTheHash() {
        var a = History<String>()
        a.record("Move", "a")
        var b = a
        b.markSaved()
        #expect(a.hashValue != b.hashValue)
    }

    @Test func theRedoStackChangesTheHash() {
        var a = History<String>(), b = History<String>()
        a.record("Move", "a")
        b.record("Move", "a")
        _ = a.undo { $0 }
        _ = b.undo { _ in "other" }
        #expect(a != b && a.hashValue != b.hashValue)
    }
}
