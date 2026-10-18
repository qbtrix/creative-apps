// HistoryTests.swift: the kernel's undo history (editor-kernel EK-7, slice
// EK-undo). Named steps, a run under one key folded into one step, the run
// ending on undo, redo and `endRun`, step ids that never repeat, dirty read
// exactly as saved-vs-current, the limit rolling old steps into the base, and
// `jump(to:)`. KJ1, the history walk, is the last test. Written from the
// packet ahead of the body, so every test waits on EK-8, which turns them on
// (docs/factory/lead.md rule 13).
import Testing
import SuiteKernel

/// Every payload an `apply` closure was handed, in order, so a test can read
/// which steps undo and redo reverted.
private struct Applied {
    var payloads: [String] = []
    /// Logs `payload` and answers the redo payload: the same text marked "redo:".
    mutating func flip(_ payload: String) -> String {
        payloads.append(payload)
        return payload.hasPrefix("redo:") ? String(payload.dropFirst(5)) : "redo:" + payload
    }
}

/// Reads a history through the protocol a menu or title bar sees.
private func menuState(_ history: some HistoryReading) -> (Bool, Bool, String?, String?, Bool) {
    (history.canUndo, history.canRedo, history.undoName, history.redoName, history.isDirty)
}

@Suite struct HistoryTests {
    @Test(.disabled("waits on EK-8")) func recordsNamedSteps() {
        var history = History<String>()
        #expect(!history.canUndo && !history.canRedo && !history.isDirty)
        history.record("Move", "move-back")
        history.record("Fill", "fill-back")
        #expect(history.steps == ["Move", "Fill"])
        #expect(history.index == 2)
        #expect(history.undoName == "Fill")
        #expect(history.redoName == nil)
        #expect(history.canUndo && !history.canRedo)
        #expect(history.isDirty)
    }

    @Test(.disabled("waits on EK-8")) func undoAndRedoHandPayloadsThrough() {
        var history = History<String>()
        var applied = Applied()
        history.record("Move", "move-back")
        #expect(history.undo { applied.flip($0) })
        #expect(applied.payloads == ["move-back"])
        #expect(history.redoName == "Move" && history.undoName == nil)
        #expect(history.redo { applied.flip($0) })
        // Redo gets back the payload undo's `apply` returned.
        #expect(applied.payloads == ["move-back", "redo:move-back"])
        #expect(!history.redo { applied.flip($0) })
        #expect(history.undoName == "Move")
    }

    @Test(.disabled("waits on EK-8")) func emptyHistoryRefusesUndoAndRedo() {
        var history = History<String>()
        var applied = Applied()
        #expect(!history.undo { applied.flip($0) })
        #expect(!history.redo { applied.flip($0) })
        #expect(applied.payloads.isEmpty)
        #expect(history.currentStepID == 0)
    }

    @Test(.disabled("waits on EK-8")) func foldKeepsOneStep() {
        var history = History<String>()
        var applied = Applied()
        for nudge in 0..<120 { history.record("Nudge", "nudge-\(nudge)", key: "nudge") }
        #expect(history.steps == ["Nudge"])
        #expect(history.index == 1)
        // Every fold takes a fresh id: 120 records, 120 ids.
        #expect(history.currentStepID == 120)
        // Undoing the run reverts to before its first edit, in one step.
        #expect(history.undo { applied.flip($0) })
        #expect(applied.payloads == ["nudge-0"])
        #expect(!history.canUndo)
        #expect(history.currentStepID == 0)
    }

    @Test(.disabled("waits on EK-8")) func differentKeysAndNoKeyDoNotFold() {
        var history = History<String>()
        history.record("Nudge", "a", key: "nudge")
        history.record("Resize", "b", key: "resize")
        history.record("Fill", "c")
        history.record("Fill", "d")
        #expect(history.steps == ["Nudge", "Resize", "Fill", "Fill"])
    }

    @Test(.disabled("waits on EK-8")) func endRunEndsRun() {
        var history = History<String>()
        history.record("Nudge", "a", key: "nudge")
        history.record("Nudge", "b", key: "nudge")
        history.endRun()
        history.record("Nudge", "c", key: "nudge")
        #expect(history.steps == ["Nudge", "Nudge"])
        #expect(history.index == 2)
    }

    @Test(.disabled("waits on EK-8")) func undoEndsRun() {
        var history = History<String>()
        var applied = Applied()
        history.record("Nudge", "a", key: "nudge")
        #expect(history.undo { applied.flip($0) })
        // The next edit under the same key is a new step, not a fold into the undone one.
        history.record("Nudge", "b", key: "nudge")
        #expect(history.steps == ["Nudge"])
        #expect(history.index == 1)
        #expect(history.canUndo && !history.canRedo)
        #expect(history.undo { applied.flip($0) })
        #expect(applied.payloads == ["a", "b"])
    }

    @Test(.disabled("waits on EK-8")) func redoEndsRun() {
        var history = History<String>()
        var applied = Applied()
        history.record("Nudge", "a", key: "nudge")
        #expect(history.undo { applied.flip($0) })
        #expect(history.redo { applied.flip($0) })
        history.record("Nudge", "b", key: "nudge")
        #expect(history.steps == ["Nudge", "Nudge"])
        #expect(history.index == 2)
    }

    @Test(.disabled("waits on EK-8")) func recordDropsRedo() {
        var history = History<String>()
        var applied = Applied()
        history.record("Move", "a")
        history.record("Fill", "b")
        #expect(history.undo { applied.flip($0) })
        history.record("Rotate", "c")
        #expect(history.steps == ["Move", "Rotate"])
        #expect(!history.canRedo)
        #expect(history.redoName == nil)
    }

    @Test(.disabled("waits on EK-8")) func idsNeverRepeat() {
        var history = History<String>()
        var applied = Applied()
        var seen: [Int] = [history.currentStepID]
        history.record("Nudge", "a", key: "nudge")
        seen.append(history.currentStepID)
        history.record("Nudge", "b", key: "nudge")
        seen.append(history.currentStepID)
        #expect(history.undo { applied.flip($0) })
        #expect(history.currentStepID == seen[0])
        // A new edit after the undo never reuses an id a fold already took.
        history.record("Fill", "c")
        #expect(!seen.contains(history.currentStepID))
        seen.append(history.currentStepID)
        history.endRun()
        history.record("Fill", "d")
        #expect(!seen.contains(history.currentStepID))
    }

    @Test(.disabled("waits on EK-8")) func redoRestoresTheStepsID() {
        var history = History<String>()
        var applied = Applied()
        history.record("Move", "a")
        let afterMove = history.currentStepID
        #expect(history.undo { applied.flip($0) })
        #expect(history.redo { applied.flip($0) })
        #expect(history.currentStepID == afterMove)
    }

    @Test(.disabled("waits on EK-8")) func dirtyExactAfterUndoToSaved() {
        var history = History<String>()
        var applied = Applied()
        history.record("Move", "a")
        history.savedStepID = history.currentStepID
        #expect(!history.isDirty)
        history.record("Move", "b")
        #expect(history.isDirty)
        #expect(history.undo { applied.flip($0) })
        #expect(!history.isDirty)
        #expect(history.redo { applied.flip($0) })
        #expect(history.isDirty)
        #expect(history.undo { applied.flip($0) })
        #expect(history.undo { applied.flip($0) })
        #expect(history.isDirty)
        // The same name at the same depth is still a different document.
        history.record("Move", "c")
        #expect(history.steps == ["Move"])
        #expect(history.isDirty)
    }

    @Test(.disabled("waits on EK-8")) func foldPastSavedIsDirty() {
        var history = History<String>()
        history.record("Nudge", "a", key: "nudge")
        history.savedStepID = history.currentStepID
        history.record("Nudge", "b", key: "nudge")
        #expect(history.steps == ["Nudge"])
        #expect(history.isDirty)
    }

    @Test(.disabled("waits on EK-8")) func limitRollsIntoBase() {
        var history = History<String>(limit: 3)
        var applied = Applied()
        for step in ["A", "B", "C", "D", "E"] { history.record(step, step.lowercased()) }
        #expect(history.steps == ["C", "D", "E"])
        #expect(history.index == 3)
        #expect(history.undo { applied.flip($0) })
        #expect(history.undo { applied.flip($0) })
        #expect(history.undo { applied.flip($0) })
        #expect(!history.undo { applied.flip($0) })
        #expect(applied.payloads == ["e", "d", "c"])
        #expect(history.index == 0)
        #expect(history.undoName == nil && history.redoName == "C")
        // The base holds A and B: undoing everything is still not the empty document.
        #expect(history.isDirty)
    }

    @Test(.disabled("waits on EK-8")) func jumpUndoesAndRedoesInOrder() {
        var history = History<String>()
        var applied = Applied()
        history.record("Move", "a")
        history.record("Fill", "b")
        history.record("Rotate", "c")
        let afterRotate = history.currentStepID
        history.jump(to: 1) { applied.flip($0) }
        #expect(applied.payloads == ["c", "b"])
        #expect(history.index == 1)
        #expect(history.undoName == "Move" && history.redoName == "Fill")
        history.jump(to: 3) { applied.flip($0) }
        #expect(applied.payloads == ["c", "b", "redo:b", "redo:c"])
        #expect(history.index == 3)
        #expect(history.currentStepID == afterRotate)
        // A jump to where it already is, or past the end, applies nothing.
        history.jump(to: 3) { applied.flip($0) }
        history.jump(to: 9) { applied.flip($0) }
        #expect(applied.payloads.count == 4)
        #expect(history.index == 3)
        #expect(history.steps == ["Move", "Fill", "Rotate"])
    }

    /// KJ1, the history walk: an edit session read the way a menu and title bar read it.
    @Test(.disabled("waits on EK-8")) func historyWalk() {
        var history = History<String>()
        var applied = Applied()
        #expect(menuState(history) == (false, false, nil, nil, false))
        history.record("Move", "move-back")
        history.savedStepID = history.currentStepID
        #expect(menuState(history) == (true, false, "Move", nil, false))
        for nudge in 0..<10 { history.record("Nudge", "nudge-\(nudge)", key: "nudge") }
        history.endRun()
        #expect(history.steps == ["Move", "Nudge"])
        #expect(menuState(history) == (true, false, "Nudge", nil, true))
        #expect(history.undo { applied.flip($0) })
        #expect(applied.payloads == ["nudge-0"])
        #expect(menuState(history) == (true, true, "Move", "Nudge", false))
        history.jump(to: 0) { applied.flip($0) }
        #expect(menuState(history) == (false, true, nil, "Move", true))
        history.jump(to: 2) { applied.flip($0) }
        #expect(applied.payloads == ["nudge-0", "move-back", "redo:move-back", "redo:nudge-0"])
        #expect(menuState(history) == (true, false, "Nudge", nil, true))
    }
}
