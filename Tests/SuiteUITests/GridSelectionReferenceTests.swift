// GridSelectionReferenceTests.swift: QB-S28, the grid's selection rules
// against a written reference (lists-and-layers LL-3). Each row of the table
// is one sequence of clicks and arrow keys, from an empty selection, on items
// 1 to 12 in a 4-column grid:
//    1  2  3  4
//    5  6  7  8
//    9 10 11 12
// and the selection and anchor the live SuiteGridSelecting must end on.
// Steps: c<n> click, s<n> ⇧-click, t<n> ⌘-click, L R U D an arrow, SL SR SU
// SD a ⇧-arrow. Row 3 is SJ18's sequence (`3`, `3,4,5,6`, `3,5,6`). No
// SwiftUI. macOS only, like the rest of SuiteUI.
import SuiteUI
import Testing

private let order = Array(1...12)
private let columns = 4

/// Steps, then the expected selection and anchor.
private let reference: [(steps: String, selection: Set<Int>, anchor: Int?)] = [
    ("c3", [3], 3),
    ("c3 s6", [3, 4, 5, 6], 3),
    ("c3 s6 t4", [3, 5, 6], 4),
    ("c3 s6 t4 R", [5], 5),
    ("c3 s1", [1, 2, 3], 3),
    ("c3 s6 s1", [1, 2, 3], 3),
    ("c3 t7", [3, 7], 7),
    ("c3 t7 t3", [7], 3),
    ("c3 t3", [], 3),
    ("c2 s4 t10 s12", [2, 3, 4, 10, 11, 12], 10),
    ("s5", [5], 5),
    ("R", [1], 1),
    ("c1 L", [1], 1),
    ("c4 R", [5], 5),
    ("c12 R", [12], 12),
    ("c2 D", [6], 6),
    ("c10 D", [10], 10),
    ("c7 U", [3], 3),
    ("c2 U", [2], 2),
    ("c6 D D", [10], 10),
    ("c1 R R R", [4], 4),
    ("c5 SR", [5, 6], 6),
    ("c5 SR SR", [5, 6, 7], 7),
    ("c5 SD", [5, 6, 7, 8, 9], 9),
    ("c6 SL SU", [1, 2, 3, 4, 5, 6], 1),
    ("c1 SL", [1], 1),
    ("SR", [1], 1),
    ("c3 s6 R", [4], 4),
    ("c3 s6 SR", [3, 4, 5, 6], 4),
    ("c99", [], nil),
    ("c3 c99", [3], 3),
    ("c3 t99", [3], 3),
    ("c3 s99", [3], 3),
    ("c8 s5", [5, 6, 7, 8], 8),
    ("c8 s5 s11", [8, 9, 10, 11], 8),
    ("c1 t3 t5 s7", [1, 3, 5, 6, 7], 5),
    ("c2 t2 R", [3], 3),
    ("c9 U U U", [1], 1),
    ("c11 SR SR", [11, 12], 12),
    ("c4 t8 SD", [4, 8, 9, 10, 11, 12], 12),
]

/// Runs one row's steps through `rule`; nil when a step is not in the grammar.
private func play(_ steps: String, _ rule: some GridSelecting) -> GridPick<Int>? {
    var pick = GridPick<Int>()
    for step in steps.split(separator: " ") {
        let arrows: [Character: GridArrow] = ["L": .left, "R": .right, "U": .up, "D": .down]
        if let arrow = step.last.flatMap({ arrows[$0] }), step.count <= 2 {
            let extend = step.count == 2
            guard !extend || step.first == "S" else { return nil }
            pick = rule.move(arrow, extend: extend, current: pick, order: order, columns: columns)
            continue
        }
        let kinds: [Character: ClickKind] = ["c": .plain, "s": .extend, "t": .toggle]
        guard let first = step.first, let kind = kinds[first], let id = Int(step.dropFirst()) else { return nil }
        pick = rule.click(id, kind, current: pick, order: order)
    }
    return pick
}

@Test func theReferenceTableHasFortySequences() {
    #expect(reference.count == 40)
    #expect(Set(reference.map(\.steps)).count == 40, "each sequence is written once")
}

@Test func everySequenceEndsOnTheTablesSelectionAndAnchor() {
    for row in reference {
        let pick = play(row.steps, SuiteGridSelecting())
        #expect(pick != nil, "\(row.steps): a step outside the grammar")
        #expect(pick?.selection == row.selection, "\(row.steps): selection")
        #expect(pick?.anchor == row.anchor, "\(row.steps): anchor")
    }
}

@Test func theLiveRuleClicksAndCountsColumnsExactlyAsGridSelectionDoes() {
    let rule = SuiteGridSelecting()
    let current = GridPick<Int>(selection: [2, 3], anchor: 2)
    let pairs: [(ClickKind, GridSelection.Click)] = [(.plain, .plain), (.extend, .extend), (.toggle, .toggle)]
    for (kind, click) in pairs {
        for id in [1, 3, 7, 12, 99] {
            let live = rule.click(id, kind, current: current, order: order)
            let math = GridSelection.click(id, click, order: order, selection: current.selection, anchor: current.anchor)
            #expect(live.selection == math.selection && live.anchor == math.anchor, "\(kind) \(id)")
        }
    }
    for width in [-10.0, 0, 120, 500, 516, .infinity, .nan] {
        #expect(rule.columns(width: width, minimum: 120, spacing: 12)
            == GridSelection.columns(width: width, minimum: 120, spacing: 12))
    }
}

@Test func theFakeKeepsItsGapOnTheReference() {
    // The Fake never extends, so row 2 (`c3 s6`) differs from the table.
    let pick = play("c3 s6", FakeGridSelecting())
    #expect(pick?.selection == [6])
}
