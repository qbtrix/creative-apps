// GridSelectionOverflowTests.swift: arrow moves with a column count near
// Int.max must not trap; a step past the grid's ends stays put. macOS only.
import SuiteUI
import Testing

private let order = ["a", "b", "c", "d", "e", "f", "g"]

@Test(arguments: [Int.max, Int.max - 1, Int.max - 6, Int.max / 2 + 1])
func hugeColumnCountsKeepUpAndDownOnTheAnchor(columns: Int) {
    for anchor in order {
        for direction in [GridSelection.Direction.up, .down] {
            let moved = GridSelection.move(direction, order: order, columns: columns, anchor: anchor)
            #expect(moved.selection == [anchor] && moved.anchor == anchor)
        }
    }
}

@Test func hugeColumnCountsStillMoveLeftAndRight() {
    #expect(GridSelection.move(.right, order: order, columns: .max, anchor: "c").selection == ["d"])
    #expect(GridSelection.move(.left, order: order, columns: .max, anchor: "c").selection == ["b"])
    #expect(GridSelection.move(.left, order: order, columns: .max, anchor: "a").selection == ["a"])
    #expect(GridSelection.move(.right, order: order, columns: .max, anchor: "g").selection == ["g"])
}
