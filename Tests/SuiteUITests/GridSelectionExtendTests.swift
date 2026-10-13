// GridSelectionExtendTests.swift: Shift-click extends the selection (issue
// #100). It replaces only the anchor's own run and keeps the items picked
// with Command-click outside it. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let order = ["a", "b", "c", "d", "e", "f", "g"]

@Test func shiftClickKeepsACommandPickOutsideTheRange() {
    let result = GridSelection.click("c", .extend, order: order, selection: ["a", "g"], anchor: "a")
    #expect(result.selection == ["a", "b", "c", "g"] && result.anchor == "a")
}

@Test func clickCommandClickThenShiftClickKeepsTheCommandPick() {
    let first = GridSelection.click("a", .plain, order: order, selection: [], anchor: nil)
    let picked = GridSelection.click("g", .toggle, order: order, selection: first.selection, anchor: first.anchor)
    #expect(picked.selection == ["a", "g"])
    let range = GridSelection.click("e", .extend, order: order, selection: picked.selection, anchor: "a")
    #expect(range.selection == ["a", "b", "c", "d", "e", "g"])
}

@Test func aSecondShiftClickShrinksTheAnchorRunAndKeepsTheRest() {
    let wide = GridSelection.click("e", .extend, order: order, selection: ["b", "g"], anchor: "b")
    #expect(wide.selection == ["b", "c", "d", "e", "g"])
    let narrow = GridSelection.click("c", .extend, order: order, selection: wide.selection, anchor: wide.anchor)
    #expect(narrow.selection == ["b", "c", "g"] && narrow.anchor == "b")
}

@Test func shiftClickFromACommandPickedAnchorKeepsTheEarlierRun() {
    // a b c picked as a range, then Command-click f moves the anchor to f.
    let toggled = GridSelection.click("f", .toggle, order: order, selection: ["a", "b", "c"], anchor: "a")
    let range = GridSelection.click("g", .extend, order: order, selection: toggled.selection, anchor: toggled.anchor)
    #expect(range.selection == ["a", "b", "c", "f", "g"] && range.anchor == "f")
}

@Test func shiftClickDropsSelectedIdsTheGridNoLongerShows() {
    let result = GridSelection.click("b", .extend, order: order, selection: ["a", "gone"], anchor: "a")
    #expect(result.selection == ["a", "b"])
}
