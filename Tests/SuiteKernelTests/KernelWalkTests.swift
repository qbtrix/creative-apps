// KernelWalkTests.swift: KJ9, the full Linux walk (editor-kernel EK-25, slice
// EK-z). One document on the kernel fixtures goes through every module in
// turn: a selection, a layer-tree move, a nudge run folded into one History
// step, undo back to the saved step with DocumentSession reading clean, a key
// toggle (KeyRules), a snap candidate set (Snapping) and an ExportRun to
// finished. After each move the modules must agree on that one document.
import Foundation
import Testing
import SuiteKernel

@Suite struct KernelWalkTests {
    /// The walk's document: the snapping page's tree and the keys of A's x.
    struct Doc: Hashable, Sendable {
        var tree = KernelFixtures.cards
        var keys: [Keyframe] = []

        func frame(_ id: String) -> Rect? { tree.node(id)?.payload.frame }
    }

    /// The export sheet's options for the walk.
    struct Options: Hashable, Sendable {
        var format: String
        var ids: [String]
    }

    @Test func walk() throws {
        var doc = Doc()
        let opened = doc
        var history = History<Doc>()
        var session = DocumentSession(token: history.currentStepID, status: .saved)
        let t0 = Date(timeIntervalSince1970: 1_000)
        func edited(_ seconds: Double) { session.didEdit(token: history.currentStepID, at: t0 + seconds) }
        func agreeOnDirty(_ expected: Bool, _ comment: Comment) {
            #expect(history.isDirty == expected, comment)
            #expect(session.isDirty == expected, comment)
        }
        func undo() -> Bool { history.undo { previous in defer { doc = previous }; return doc } }
        func redo() -> Bool { history.redo { next in defer { doc = next }; return doc } }
        agreeOnDirty(false, "a fresh document reads clean")

        // 1. Selection: a click picks A, a Command-click adds B; locked and
        //    hidden layers can't join.
        let canAdd: (String) -> Bool = { [tree = doc.tree] id in
            !tree.isEffectivelyLocked(id) && !tree.isEffectivelyHidden(id)
        }
        var selection = Selection<String>()
        let picks = [
            selection.pick("a", .replace, canAdd: canAdd), selection.pick("b", .toggle, canAdd: canAdd),
            selection.pick("locked", .toggle, canAdd: canAdd), selection.pick("hidden", .toggle, canAdd: canAdd),
        ]
        #expect(picks == [true, true, false, false])
        #expect(selection.ordered == ["a", "b"] && selection.primary == "b")
        agreeOnDirty(false, "selecting is not an edit")

        // 2. Layer tree: B moves into Pair, one named step.
        var before = doc
        try doc.tree.move("b", into: "pair", at: 2)
        history.record("Move to Group", before)
        history.endRun()
        edited(1)
        #expect(doc.tree.ancestors(of: "b") == ["desktop", "pair"])
        #expect(doc.tree.node("pair")?.children.map(\.id) == ["e1", "e2", "b"])
        selection.prune { doc.tree.node($0) != nil }
        #expect(selection.ordered == ["a", "b"], "the move keeps both picked")
        agreeOnDirty(true, "after the move")

        // 3. A nudge run: right, right, Shift-right fold into one step.
        let key = Nudge.runKey("nudge", selection.ordered)
        for large in [false, false, true] {
            before = doc
            let d = Nudge.delta(.right, large: large)
            for id in selection.ordered {
                _ = doc.tree.update(id) { node in node.payload.x += d.x; node.payload.y += d.y }
            }
            history.record("Nudge", before, key: key)
            edited(2)
        }
        history.endRun()
        #expect(history.steps == ["Move to Group", "Nudge"], "three presses are one step")
        #expect(history.undoName == "Nudge")
        #expect(doc.frame("a")?.minX == 112 && doc.frame("b")?.minX == 312 && doc.frame("a")?.minY == 100)
        agreeOnDirty(true, "after the nudge run")

        // The snap candidates read the moved tree: A's siblings and Desktop,
        // then B's new siblings in Pair, then the page; the moving layers and
        // Hidden are skipped, Locked is kept.
        let page = try #require(doc.frame("desktop"))
        let moved = Snapping.candidates(in: doc.tree, moving: selection.ordered, drawingInto: nil, page: page) {
            $0.payload.frame
        }
        #expect(moved.map(\.id) == ["c", "title", "pair", "locked", "desktop", "e1", "e2", nil])
        for candidate in moved {
            #expect(candidate.frame == (candidate.id.flatMap(doc.frame) ?? page), "candidate \(candidate.id ?? "page")")
        }

        // 4. Undo back to the saved step: the run undoes whole, then the move;
        //    the history and the session both read clean on the opened document.
        #expect(undo())
        edited(3)
        #expect(doc.frame("a")?.minX == 100 && doc.frame("b")?.minX == 300, "one undo reverts all three presses")
        #expect(doc.tree.ancestors(of: "b") == ["desktop", "pair"])
        agreeOnDirty(true, "one step away from saved")
        #expect(undo())
        edited(4)
        #expect(doc == opened)
        #expect(history.redoName == "Move to Group" && !history.canUndo)
        agreeOnDirty(false, "undone back to the saved step")
        #expect(!session.autosaveDue(now: t0 + 60, delay: 5), "a clean document needs no autosave")
        // A redo is an edit again; undoing it reads clean again.
        #expect(redo())
        edited(5)
        agreeOnDirty(true, "after a redo")
        #expect(undo())
        edited(6)
        agreeOnDirty(false, "undone again")
        selection.prune { doc.tree.node($0) != nil }
        #expect(selection.ordered == ["a", "b"])

        // 5. Keys: animating A's x keys both ends; a toggle mid-range adds a
        //    key; both are steps, and the new step drops the old redo.
        let x = try #require(doc.frame("a")?.minX)
        #expect(KeyRules.state(doc.keys, at: 0) == .notAnimated)
        before = doc
        #expect(KeyRules.toggleAnimated(&doc.keys, at: 0, lastFrame: 24, value: x))
        history.record("Animate X", before)
        edited(7)
        #expect(!history.canRedo, "a new step drops the undone move")
        #expect(KeyRules.state(doc.keys, at: 0) == .keyedHere && KeyRules.state(doc.keys, at: 12) == .animated)
        before = doc
        #expect(KeyRules.toggleKey(&doc.keys, at: 12, value: x + 50, leaving: .singleStays))
        history.record("Add Keyframe", before)
        history.endRun()
        edited(8)
        #expect(doc.keys.map(\.frame) == [0, 12, 24] && doc.keys.map(\.value) == [x, x + 50, x])
        #expect(KeyRules.state(doc.keys, at: 12) == .keyedHere)
        #expect(history.steps == ["Animate X", "Add Keyframe"])
        agreeOnDirty(true, "after the key toggles")
        #expect(session.autosaveDue(now: t0 + 20, delay: 5))
        // Save: both read clean at the new step.
        history.savedStepID = history.currentStepID
        session.didSave(token: history.currentStepID)
        agreeOnDirty(false, "after saving")
        #expect(session.status == .saved)

        // 6. Snap on the saved document: B is back in Desktop, so one scope.
        let candidates = Snapping.candidates(in: doc.tree, moving: selection.ordered, drawingInto: nil, page: page) {
            $0.payload.frame
        }
        #expect(candidates.map(\.id) == ["c", "title", "pair", "locked", "desktop", nil])
        #expect(candidates.first?.frame == doc.frame("c"))
        #expect(Snapping.offset(lines: nil, gaps: nil, wholePoints: 1) == 1)

        // 7. Export the selection: the run walks to finished, naming the layers
        //    the tree has; exporting never dirties the document.
        var run = ExportRun<Options>.idle
        let options = Options(format: "png", ids: selection.ordered)
        let opens = run.begin(options)
        let starts = run.start(total: options.ids.count)
        run.progressed(done: 1)
        let reopens = run.begin(options)
        #expect(opens && starts)
        #expect(!reopens, "the sheet can't reopen while writing")
        run.progressed(done: 9)
        #expect(run == .running(options, done: 2, total: 2))
        let files = options.ids.compactMap { doc.tree.node($0)?.name }.map { "\($0).png" }
        run.end(.success(files))
        #expect(run == .finished(options, ["A.png", "B.png"]))
        run.dismiss()
        #expect(run == .idle)
        #expect(history.steps == ["Animate X", "Add Keyframe"])
        agreeOnDirty(false, "exporting is not an edit")
    }
}
