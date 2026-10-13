// GridSelectionToggleTests.swift: every click mode returns only ids the grid
// shows (issue #99). Command-click used to keep selected ids that had left
// `order`. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let order = ["a", "b", "c", "d"]

@Test func commandClickAddDropsSelectedIdsTheGridNoLongerShows() {
    let result = GridSelection.click("b", .toggle, order: order, selection: ["a", "gone"], anchor: "a")
    #expect(result.selection == ["a", "b"] && result.anchor == "b")
}

@Test func commandClickRemoveDropsSelectedIdsTheGridNoLongerShows() {
    let result = GridSelection.click("a", .toggle, order: order, selection: ["a", "c", "gone"], anchor: "a")
    #expect(result.selection == ["c"] && result.anchor == "a")
}

@Test func clickingAnIdTheGridDoesNotShowDropsStaleIds() {
    let result = GridSelection.click("z", .toggle, order: order, selection: ["b", "gone"], anchor: "b")
    #expect(result.selection == ["b"] && result.anchor == "b")
}

@Test func everyClickModeOnlyReturnsIdsInOrder() {
    let modes: [GridSelection.Click] = [.plain, .toggle, .extend]
    for kind in modes {
        for id in order + ["z"] {
            let result = GridSelection.click(id, kind, order: order, selection: ["a", "c", "gone"], anchor: "a")
            #expect(result.selection.isSubset(of: order))
        }
    }
}
