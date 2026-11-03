// BatchFoldedStepTests.swift: a batch report names only the undo steps the history still holds. A draft
// step a later commit folds into its own one step (Photo's Scale inside Free Transform) loses its
// `undoStep`, while steps a run coalesces or an undo moves to Redo keep theirs.
import Foundation
import Testing
import SuiteKernel

/// A number with a draft (`draft.scale`, one step each) that `draft.commit` folds into one step.
struct FoldDoc: Sendable {
    var value = 1, history = History<Int>()

    static func edit(_ id: String, _ run: @escaping @Sendable (inout FoldDoc) -> Void) -> CommandSpec<FoldDoc> {
        .typed(id, title: id, summary: id, kind: .edit, params: FakeCanvasDocument.NoParams.self,
               schema: ParamSchema.none, example: .object([:])) { doc, _ in run(&doc); return JSONValue.object([:]) }
    }
    static let catalog = (try? CommandCatalog<FoldDoc>(app: "fold", [
        edit("value.move") { $0.history.record("Move", $0.value); $0.value += 1 },
        edit("value.nudge") { $0.history.record("Nudge", $0.value, key: "nudge"); $0.value += 1 },
        edit("draft.scale") { $0.history.record("Scale", $0.value); $0.value *= 2 },
        edit("draft.commit") { doc in
            var value = doc.value
            _ = doc.history.undo { old in defer { value = old }; return value }
            doc.history.record("Free Transform", value)
        },
        .typed("edit.undo", title: "Undo", summary: "Undo", kind: .view, params: FakeCanvasDocument.NoParams.self,
               schema: ParamSchema.none, example: .object([:])) { doc, _ in
            var value = doc.value
            _ = doc.history.undo { old in defer { value = old }; return value }
            doc.value = value
            return JSONValue.object([:])
        },
    ], history: { $0.history })) ?? .empty(app: "fold")

    static func step(_ id: String) -> CommandEnvelope { CommandEnvelope(id: id, params: .object([:])) }
}

@Suite struct BatchFoldedStepTests {
    @Test func aCommittedDraftReportsOneStep() {
        var doc = FoldDoc()
        let report = FoldDoc.catalog.runBatch(["value.move", "draft.scale", "draft.commit"].map(FoldDoc.step), on: &doc, atomic: true)
        #expect(doc.history.steps == ["Move", "Free Transform"])
        #expect(report.steps.map(\.undoStep) == ["Move", nil, "Free Transform"])
    }

    @Test func coalescedAndUndoneStepsKeepTheirNames() {
        var doc = FoldDoc()
        let report = FoldDoc.catalog.runBatch(["value.nudge", "value.nudge", "value.move", "edit.undo"].map(FoldDoc.step),
                                              on: &doc, atomic: false)
        #expect(doc.history.steps == ["Nudge", "Move"] && doc.history.index == 1)
        #expect(report.steps.map(\.undoStep) == ["Nudge", "Nudge", "Move", nil])
    }
}
