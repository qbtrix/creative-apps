// GridSelectionTests.swift: ThumbnailGrid's selection math (click, Command
// toggle, Shift range, arrow moves, column count). No SwiftUI import. macOS
// only, like the rest of SuiteUI.
import SuiteUI
import Testing

private let order = ["a", "b", "c", "d", "e", "f", "g"]

@Test func plainClickSelectsOnlyThatItem() {
    let result = GridSelection.click("c", .plain, order: order, selection: ["a", "b"], anchor: "a")
    #expect(result.selection == ["c"])
    #expect(result.anchor == "c")
}

@Test func commandClickTogglesOneItemAndKeepsTheRest() {
    let added = GridSelection.click("d", .toggle, order: order, selection: ["a"], anchor: "a")
    #expect(added.selection == ["a", "d"])
    #expect(added.anchor == "d")
    let removed = GridSelection.click("a", .toggle, order: order, selection: added.selection, anchor: added.anchor)
    #expect(removed.selection == ["d"])
}

@Test func shiftClickSelectsTheRangeForward() {
    let result = GridSelection.click("e", .extend, order: order, selection: ["b"], anchor: "b")
    #expect(result.selection == ["b", "c", "d", "e"])
    #expect(result.anchor == "b")
}

@Test func shiftClickSelectsTheRangeBackwardAndKeepsTheAnchor() {
    let first = GridSelection.click("f", .extend, order: order, selection: ["d"], anchor: "d")
    let back = GridSelection.click("b", .extend, order: order, selection: first.selection, anchor: first.anchor)
    #expect(back.selection == ["b", "c", "d"])
    #expect(back.anchor == "d")
}

@Test func shiftClickWithNoAnchorSelectsJustThatItem() {
    let result = GridSelection.click("c", .extend, order: order, selection: [], anchor: nil)
    #expect(result.selection == ["c"])
    #expect(result.anchor == "c")
}

@Test func clickOnAnUnknownIdChangesNothing() {
    let result = GridSelection.click("z", .plain, order: order, selection: ["a"], anchor: "a")
    #expect(result.selection == ["a"])
    #expect(result.anchor == "a")
}

@Test func arrowsMoveByOneAcrossAndByARowDown() {
    // 3 columns: a b c / d e f / g
    #expect(GridSelection.move(.right, order: order, columns: 3, anchor: "b").selection == ["c"])
    #expect(GridSelection.move(.left, order: order, columns: 3, anchor: "b").selection == ["a"])
    #expect(GridSelection.move(.down, order: order, columns: 3, anchor: "b").selection == ["e"])
    #expect(GridSelection.move(.up, order: order, columns: 3, anchor: "e").anchor == "b")
}

@Test func arrowsAtTheGridEdgesStayInBounds() {
    #expect(GridSelection.move(.left, order: order, columns: 3, anchor: "a").selection == ["a"])
    #expect(GridSelection.move(.up, order: order, columns: 3, anchor: "c").selection == ["c"])
    #expect(GridSelection.move(.right, order: order, columns: 3, anchor: "g").selection == ["g"])
    #expect(GridSelection.move(.down, order: order, columns: 3, anchor: "f").selection == ["f"])
    #expect(GridSelection.move(.down, order: order, columns: 0, anchor: "a").selection == ["b"])
}

@Test func arrowWithNoAnchorPicksTheFirstItemAndAnEmptyGridPicksNothing() {
    #expect(GridSelection.move(.down, order: order, columns: 3, anchor: nil).selection == ["a"])
    let empty = GridSelection.move(.down, order: [String](), columns: 3, anchor: nil)
    #expect(empty.selection.isEmpty)
    #expect(empty.anchor == nil)
}

@Test func columnsFitAdaptiveCellsAndNeverDropBelowOne() {
    #expect(GridSelection.columns(width: 500, minimum: 120, spacing: 12) == 3)
    #expect(GridSelection.columns(width: 516, minimum: 120, spacing: 12) == 4)
    #expect(GridSelection.columns(width: 50, minimum: 120, spacing: 12) == 1)
    #expect(GridSelection.columns(width: 500, minimum: 0, spacing: 0) == 1)
    #expect(GridSelection.columns(width: .infinity, minimum: 120, spacing: 12) == 1)
    #expect(GridSelection.columns(width: 1e300, minimum: 1, spacing: 0) == 10_000)
}
