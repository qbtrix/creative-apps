// PathLiveDragTests.swift (#5145): a point editor press held on a PathLiveDrag until release. The copy shows each
// sample through the same path commands the app runs, holds every intent in order, and the held intents run on the
// app's target give the copy's path in one undo step. Mutations: Tests/mutations/SuiteKernel.PathLiveDrag.json.
import Testing
import SuiteKernel

@Suite struct PathLiveDragTests {
    /// Runs `held` on `doc` as the app does at release, through the catalog.
    static func commit(_ held: [PathIntent], on doc: inout PathDoc) throws {
        for intent in held { _ = try PathCommandsTests.run(intent, &doc) }
    }

    @Test func anAnchorDragShowsEachSampleAndCommitsAsOneStep() throws {
        var doc = PathDoc.editing
        doc.anchorSelection = Selection()
        var live = PathLiveDrag(draft: doc.penDraft, path: doc.pathInEdit, selection: doc.anchorSelection)
        live.run(.select(anchors: [AnchorEditTests.mid], rect: nil, extend: false))
        for _ in 1...30 { live.run(.move(dx: 1, dy: 2, drag: "d1")) }
        let shown = live.pathInEdit?.path.contours.first?.anchors.dropFirst().first
        #expect(shown?.point == Point(x: 130, y: 60) && shown?.handleOut == Point(x: 150, y: 60))
        #expect(live.anchorSelection.set == [AnchorEditTests.mid])
        #expect(live.held.count == 31 && live.held.first == .select(anchors: [AnchorEditTests.mid], rect: nil, extend: false))
        #expect(doc.pathInEdit?.path == AnchorEditTests.path(), "the copy changed the document")
        try Self.commit(live.held, on: &doc)
        #expect(doc.pathInEdit == live.pathInEdit)
        #expect(doc.history.undoSteps.map(\.name) == ["Move Points"])
    }

    @Test func aHandleDragShowsWhereItIsAndCommitsTheSamePath() throws {
        var doc = PathDoc.editing
        var live = PathLiveDrag(draft: nil, path: doc.pathInEdit, selection: doc.anchorSelection)
        live.run(.handle(AnchorEditTests.mid, .handleOut, to: Point(x: 100, y: 40), breaking: false, drag: "h"))
        live.run(.handle(AnchorEditTests.mid, .handleOut, to: Point(x: 100, y: 20), breaking: false, drag: "h"))
        #expect(live.pathInEdit?.path.contours.first?.anchors.dropFirst().first == AnchorEditTests.dragged())
        try Self.commit(live.held, on: &doc)
        #expect(doc.pathInEdit == live.pathInEdit)
        #expect(doc.history.undoSteps.map(\.name) == ["Move Handle"])
    }

    @Test func aRefusedIntentLeavesTheCopyAndIsStillHeld() {
        let doc = PathDoc.editing
        var live = PathLiveDrag(draft: nil, path: doc.pathInEdit, selection: doc.anchorSelection)
        live.run(.handle(AnchorRef(contour: 0, index: 9), .handleOut, to: Point(x: 1, y: 1), breaking: false, drag: "h"))
        #expect(live.pathInEdit == doc.pathInEdit)
        #expect(live.held.count == 1, "the app's own run reports the refusal, so the intent goes to it")
    }
}
