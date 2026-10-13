// GridSelectionToggleFuzzTests.swift: seeded fuzz over the click rules
// (issue #99). Random grids, selections with ids the grid isn't showing, and
// stale anchors: every click mode returns only shown ids, and Command-click is
// exactly "flip this one shown id". No SwiftUI. macOS only.
import SuiteUI
import Testing

private struct SeededGenerator: RandomNumberGenerator {
    var state: UInt64

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}

/// One random grid state. Ids -3..<0 and n..<n+3 are never shown.
private struct Case {
    let order: [Int]
    let selection: Set<Int>
    let anchor: Int?
    let id: Int

    init(_ rng: inout SeededGenerator) {
        let count = Int.random(in: 0...8, using: &rng)
        order = Array(0..<count).shuffled(using: &rng)
        let universe = Array(-3..<(count + 3))
        selection = Set(universe.filter { _ in Bool.random(using: &rng) })
        anchor = Bool.random(using: &rng) ? universe.randomElement(using: &rng) : nil
        id = universe.randomElement(using: &rng) ?? 0
    }
}

@Test(arguments: [UInt64(1), 99, 260])
func everyClickModeOnlyReturnsShownIdsUnderFuzz(seed: UInt64) {
    var rng = SeededGenerator(state: seed)
    for _ in 0..<2_000 {
        let c = Case(&rng)
        for kind in [GridSelection.Click.plain, .toggle, .extend] {
            let result = GridSelection.click(c.id, kind, order: c.order, selection: c.selection, anchor: c.anchor)
            #expect(result.selection.isSubset(of: c.order))
            if c.order.contains(c.id) {
                #expect(result.anchor.map(c.order.contains) == true)
            }
        }
    }
}

@Test(arguments: [UInt64(2), 3, 4])
func commandClickFlipsOnlyTheClickedShownIdUnderFuzz(seed: UInt64) {
    var rng = SeededGenerator(state: seed)
    for _ in 0..<2_000 {
        let c = Case(&rng)
        guard c.order.contains(c.id) else { continue }
        let once = GridSelection.click(c.id, .toggle, order: c.order, selection: c.selection, anchor: c.anchor)
        let shown = c.selection.intersection(c.order)
        #expect(once.selection == shown.symmetricDifference([c.id]) && once.anchor == c.id)
        let twice = GridSelection.click(c.id, .toggle, order: c.order, selection: once.selection, anchor: once.anchor)
        #expect(twice.selection == shown)
    }
}
