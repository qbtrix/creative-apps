// ListEditingTests.swift: SuiteListEditing (lists-and-layers LL-2, UC10).
// A rename trims, an empty or same title is no change, a refusal keeps the
// draft as typed; a reorder never drops or duplicates an id; a drop index
// never divides by zero. No SwiftUI. macOS only.
import SuiteUI
import Testing

@Suite struct ListEditingTests {
    let editing = SuiteListEditing()

    @Test func aRenameTrimsTheDraft() {
        #expect(editing.commitRename("  Hero ", original: "Ball", validate: { _ in nil }) == .renamed("Hero"))
        #expect(editing.commitRename("\tHero\n", original: "Ball", validate: { _ in nil }) == .renamed("Hero"))
    }

    @Test func anEmptyOrSameTitleIsUnchanged() {
        #expect(editing.commitRename("", original: "Ball", validate: { _ in "never" }) == .unchanged)
        #expect(editing.commitRename("   ", original: "Ball", validate: { _ in "never" }) == .unchanged)
        #expect(editing.commitRename("Ball", original: "Ball", validate: { _ in "never" }) == .unchanged)
        #expect(editing.commitRename(" Ball ", original: "Ball", validate: { _ in "never" }) == .unchanged)
    }

    @Test func aRefusalKeepsTheDraftAsTyped() {
        let refuse: (String) -> String? = { $0 == "Taken" ? "Taken." : nil }
        #expect(editing.commitRename("Taken", original: "Shadow", validate: refuse)
            == .refused(message: "Taken.", draft: "Taken"))
        #expect(editing.commitRename(" Taken ", original: "Shadow", validate: refuse)
            == .refused(message: "Taken.", draft: " Taken "))
    }

    @Test func validateSeesTheTrimmedName() {
        var seen: [String] = []
        _ = editing.commitRename("  Hero ", original: "Ball", validate: { seen.append($0); return nil })
        #expect(seen == ["Hero"])
    }

    @Test func cancelIsCancelled() {
        #expect(editing.cancelRename("Hero", original: "Ball") == .cancelled)
    }

    @Test func reorderMovesOneIdAndClamps() {
        #expect(editing.reordered(["a", "b", "c"], moving: "c", to: 0) == ["c", "a", "b"])
        #expect(editing.reordered(["a", "b", "c"], moving: "c", to: 99) == ["a", "b", "c"])
        #expect(editing.reordered(["a", "b", "c"], moving: "a", to: 99) == ["b", "c", "a"])
        #expect(editing.reordered(["a", "b", "c"], moving: "b", to: -4) == ["b", "a", "c"])
        #expect(editing.reordered(["a", "b", "c"], moving: "a", to: 1) == ["b", "a", "c"])
        #expect(editing.reordered(["a", "b", "c"], moving: "z", to: 0) == ["a", "b", "c"])
        #expect(editing.reordered([String](), moving: "a", to: 0) == [])
    }

    @Test func reorderNeverDropsOrDuplicatesAnId() {
        let order = Array(0..<12)
        for id in order {
            for index in -2...14 {
                let moved = editing.reordered(order, moving: id, to: index)
                #expect(moved.count == order.count)
                #expect(Set(moved) == Set(order))
                #expect(moved.firstIndex(of: id) == min(max(index, 0), order.count - 1))
            }
        }
    }

    @Test func dropIndexRoundsToTheNearestGap() {
        #expect(editing.dropIndex(atY: 50, rowHeight: 28, count: 3) == 2)
        #expect(editing.dropIndex(atY: 0, rowHeight: 28, count: 3) == 0)
        #expect(editing.dropIndex(atY: 13, rowHeight: 28, count: 3) == 0)
        #expect(editing.dropIndex(atY: 15, rowHeight: 28, count: 3) == 1)
        #expect(editing.dropIndex(atY: 500, rowHeight: 28, count: 3) == 3)
        #expect(editing.dropIndex(atY: -40, rowHeight: 28, count: 3) == 0)
    }

    @Test func dropIndexNeverDividesByZeroOrTrapsOnBadInput() {
        #expect(editing.dropIndex(atY: .nan, rowHeight: 28, count: 3) == 0)
        #expect(editing.dropIndex(atY: .infinity, rowHeight: 28, count: 3) == 0)
        #expect(editing.dropIndex(atY: 50, rowHeight: 0, count: 3) == 0)
        #expect(editing.dropIndex(atY: 50, rowHeight: -28, count: 3) == 0)
        #expect(editing.dropIndex(atY: 50, rowHeight: .nan, count: 3) == 0)
        #expect(editing.dropIndex(atY: 1e300, rowHeight: 1e-300, count: 3) == 3)
        #expect(editing.dropIndex(atY: 50, rowHeight: 28, count: 0) == 0)
        #expect(editing.dropIndex(atY: 50, rowHeight: 28, count: -2) == 0)
    }
}
