// LibraryHistoryTests.swift: CatalogHistory, the undo and redo stacks of named
// before-and-after steps, and coalescing a drag into one step. Runs on Linux
// and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
import LibraryModel
import Testing

private func photo(_ name: String, rating: Int = 0) -> PhotoItem {
    PhotoItem(name: name, captureDate: Date(timeIntervalSince1970: 0), color: Color3(0, 0, 0), rating: rating)
}

private func step(_ name: String, from: Int, to: Int, key: String? = nil) -> CatalogHistory.Step {
    CatalogHistory.Step(
        name: name, before: [photo("A", rating: from)], after: [photo("A", rating: to)], coalesceKey: key)
}

@Test func anEmptyHistoryHasNoTop() {
    var history = CatalogHistory()
    #expect(history.top == nil)
    #expect(history.redoTop == nil)
    #expect(history.undo.isEmpty && history.redo.isEmpty)
    #expect(history.popUndo() == nil)
    #expect(history.popRedo() == nil)
    #expect(history == CatalogHistory())
}

@Test func popsGiveStepsBackInReverse() {
    var history = CatalogHistory()
    let first = step("Set Rating", from: 0, to: 1)
    let second = step("Pick", from: 1, to: 2)
    history.push(first)
    history.push(second)
    #expect(history.top == second)

    #expect(history.popUndo() == second)
    #expect(history.popUndo() == first)
    #expect(history.popUndo() == nil)
    #expect(history.redo == [second, first])

    #expect(history.popRedo() == first)
    #expect(history.popRedo() == second)
    #expect(history.popRedo() == nil)
    #expect(history.undo == [first, second])
}

@Test func aPushClearsRedo() {
    var history = CatalogHistory()
    history.push(step("Set Rating", from: 0, to: 1))
    _ = history.popUndo()
    #expect(history.redoTop?.name == "Set Rating")
    history.push(step("Pick", from: 0, to: 2))
    #expect(history.redo.isEmpty)
    #expect(history.undo.map(\.name) == ["Pick"])
}

@Test func anOpenCoalesceKeyKeepsOneStep() {
    var history = CatalogHistory()
    history.push(step("Exposure", from: 0, to: 1, key: "exposure"))
    history.push(step("Exposure", from: 1, to: 2, key: "exposure"))
    #expect(history.undo.count == 1)
    #expect(history.top?.before == [photo("A", rating: 0)])
    #expect(history.top?.after == [photo("A", rating: 2)])
    #expect(history.open)
}

@Test func coalescingStopsWhenClosedOrTheKeyDiffers() {
    var history = CatalogHistory()
    history.push(step("Exposure", from: 0, to: 1, key: "exposure"))
    history.endCoalescing()
    #expect(!history.open)
    history.push(step("Exposure", from: 1, to: 2, key: "exposure"))
    #expect(history.undo.count == 2)
    history.push(step("Contrast", from: 2, to: 3, key: "contrast"))
    #expect(history.undo.count == 3)
    history.push(step("Set Rating", from: 3, to: 4))
    history.push(step("Set Rating", from: 4, to: 5))
    #expect(history.undo.count == 5)
}

@Test func undoClosesCoalescing() {
    var history = CatalogHistory()
    history.push(step("Exposure", from: 0, to: 1, key: "exposure"))
    _ = history.popUndo()
    _ = history.popRedo()
    history.push(step("Exposure", from: 1, to: 2, key: "exposure"))
    #expect(history.undo.count == 2)
}
