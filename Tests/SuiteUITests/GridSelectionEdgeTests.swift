// GridSelectionEdgeTests.swift: edge cases and a seeded fuzz for the
// selection math behind ThumbnailGrid: ragged last rows, a stale anchor,
// columns wider than the grid, odd geometry, and the invariants every click
// and arrow move keeps. No SwiftUI. macOS only.
import SuiteUI
import Testing

private let order = ["a", "b", "c", "d", "e", "f", "g"]  // 3 columns: a b c / d e f / g

@Test func downFromAColumnTheRaggedLastRowLacksStaysPut() {
    #expect(GridSelection.move(.down, order: order, columns: 3, anchor: "e").selection == ["e"])
    #expect(GridSelection.move(.down, order: order, columns: 3, anchor: "d").selection == ["g"])
    #expect(GridSelection.move(.up, order: order, columns: 3, anchor: "g").selection == ["d"])
}

@Test func moreColumnsThanItemsMakesUpAndDownNoOps() {
    for direction in [GridSelection.Direction.up, .down] {
        #expect(GridSelection.move(direction, order: order, columns: 50, anchor: "c").selection == ["c"])
    }
    #expect(GridSelection.move(.right, order: order, columns: 50, anchor: "c").selection == ["d"])
}

@Test func negativeColumnsCountAsOne() {
    #expect(GridSelection.move(.down, order: order, columns: -4, anchor: "c").selection == ["d"])
    #expect(GridSelection.move(.up, order: order, columns: .min, anchor: "c").selection == ["b"])
}

@Test func aStaleAnchorFallsBackToTheFirstItem() {
    let moved = GridSelection.move(.right, order: order, columns: 3, anchor: "gone")
    #expect(moved.selection == ["a"] && moved.anchor == "a")
    let extended = GridSelection.click("c", .extend, order: order, selection: ["gone"], anchor: "gone")
    #expect(extended.selection == ["c"] && extended.anchor == "c")
}

@Test func shiftClickOnTheAnchorSelectsJustTheAnchor() {
    let result = GridSelection.click("d", .extend, order: order, selection: ["a", "d"], anchor: "d")
    #expect(result.selection == ["d"] && result.anchor == "d")
}

@Test func aSingleItemGridKeepsEveryArrowOnIt() {
    for direction in [GridSelection.Direction.left, .right, .up, .down] {
        #expect(GridSelection.move(direction, order: ["only"], columns: 1, anchor: "only").selection == ["only"])
    }
}

@Test func columnsSurviveNonFiniteAndNegativeGeometry() {
    #expect(GridSelection.columns(width: .nan, minimum: 120, spacing: 12) == 1)
    #expect(GridSelection.columns(width: -500, minimum: 120, spacing: 12) == 1)
    #expect(GridSelection.columns(width: 500, minimum: .nan, spacing: 12) == 1)
    #expect(GridSelection.columns(width: 500, minimum: .infinity, spacing: 12) == 1)
    #expect(GridSelection.columns(width: 500, minimum: 120, spacing: -120) == 1)
    #expect(GridSelection.columns(width: 500, minimum: 120, spacing: -200) == 1)
    #expect(GridSelection.columns(width: 0, minimum: 120, spacing: 12) == 1)
}

@Test(arguments: [500.0, 516, 800, 1440, 2000])
func widerGridsNeverFitFewerColumns(width: Double) {
    let narrower = GridSelection.columns(width: width - 1, minimum: 208, spacing: 12)
    #expect(GridSelection.columns(width: width, minimum: 208, spacing: 12) >= narrower)
}

/// A tiny deterministic generator so a failing case reproduces.
private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return state
    }
}

@Test func fuzzedMovesAndClicksStayInsideTheGrid() {
    var rng = SeededGenerator(state: 0x9E37_79B9)
    let directions: [GridSelection.Direction] = [.left, .right, .up, .down]
    for _ in 0..<5_000 {
        let items = (0..<Int.random(in: 0...12, using: &rng)).map { "i\($0)" }
        let pool = items + ["x", "y"]
        let selection = Set(pool.filter { _ in Bool.random(using: &rng) })
        let anchor = Bool.random(using: &rng) ? pool.randomElement(using: &rng) : nil
        let columns = Int.random(in: -3...15, using: &rng)
        let direction = directions.randomElement(using: &rng) ?? .left

        let moved = GridSelection.move(direction, order: items, columns: columns, anchor: anchor)
        #expect(moved.selection.count == (items.isEmpty ? 0 : 1))
        #expect(moved.selection.isSubset(of: items))
        #expect(moved.anchor.map(items.contains) ?? items.isEmpty)

        guard let id = items.randomElement(using: &rng) else { continue }
        let plain = GridSelection.click(id, .plain, order: items, selection: selection, anchor: anchor)
        #expect(plain.selection == [id] && plain.anchor == id)
        let range = GridSelection.click(id, .extend, order: items, selection: selection, anchor: anchor)
        #expect(range.selection.contains(id) && range.selection.isSubset(of: items))
        // The range is contiguous in display order.
        let picked = items.indices.filter { range.selection.contains(items[$0]) }
        #expect(picked.count == (picked.last ?? 0) - (picked.first ?? 0) + 1)
        let toggled = GridSelection.click(id, .toggle, order: items, selection: selection, anchor: anchor)
        #expect(toggled.selection.contains(id) != selection.contains(id) && toggled.anchor == id)
    }
}
