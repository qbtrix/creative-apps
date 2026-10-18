// ListFakeTests.swift: the list Fakes (UC9 GridSelecting, UC10 ListEditing)
// give the contracts' main.swift results and keep the gap each one has on
// purpose: the grid Fake selects one item only and never extends or toggles;
// the list Fake never refuses and never trims. The live tests (LL-2, LL-3)
// rely on these gaps. No SwiftUI. macOS only.
import SuiteUI
import Testing

@Test func fakeGridClickGivesMainSwiftsSelection() {
    let pick = FakeGridSelecting().click(3, .plain, current: GridPick<Int>(), order: [1, 2, 3])
    #expect(pick.selection == [3])
    #expect(pick.anchor == 3)
}

@Test func fakeGridClickKeepsOneItemForEveryKind() {
    let g = FakeGridSelecting()
    let current = GridPick<Int>(selection: [1, 2], anchor: 1)
    #expect(g.click(3, .extend, current: current, order: [1, 2, 3, 4]) == GridPick(selection: [3], anchor: 3))
    #expect(g.click(3, .toggle, current: current, order: [1, 2, 3, 4]) == GridPick(selection: [3], anchor: 3))
    #expect(g.click(2, .toggle, current: current, order: [1, 2, 3, 4]) == GridPick(selection: [2], anchor: 2))
    #expect(g.click(9, .plain, current: current, order: [1, 2, 3, 4]) == current)
}

@Test func fakeGridMovesOneItemAndNeverExtends() {
    let g = FakeGridSelecting()
    let order = Array(0..<6)
    let at1 = GridPick<Int>(selection: [1], anchor: 1)
    #expect(g.move(.right, extend: true, current: at1, order: order, columns: 3) == GridPick(selection: [2], anchor: 2))
    #expect(g.move(.left, extend: false, current: at1, order: order, columns: 3) == GridPick(selection: [0], anchor: 0))
    #expect(g.move(.down, extend: true, current: at1, order: order, columns: 3) == GridPick(selection: [4], anchor: 4))
    #expect(g.move(.up, extend: false, current: at1, order: order, columns: 3) == at1)
    #expect(g.move(.down, extend: false, current: GridPick<Int>(), order: order, columns: 3) == GridPick<Int>())
    #expect(g.move(.down, extend: false, current: at1, order: order, columns: 0) == GridPick(selection: [2], anchor: 2))
}

@Test func fakeGridColumnsAreAtLeastOne() {
    let g = FakeGridSelecting()
    #expect(g.columns(width: 340, minimum: 100, spacing: 20) == 3)
    #expect(g.columns(width: 10, minimum: 100, spacing: 20) == 1)
    #expect(g.columns(width: 340, minimum: 0, spacing: 20) == 1)
    #expect(g.columns(width: .infinity, minimum: 100, spacing: 20) == 1)
    #expect(g.columns(width: .nan, minimum: 100, spacing: 20) == 1)
}

@Test func fakeListReorderGivesMainSwiftsOrder() {
    let l = FakeListEditing()
    #expect(l.reordered(["a", "b", "c"], moving: "c", to: 0) == ["c", "a", "b"])
    #expect(l.reordered(["a", "b", "c"], moving: "a", to: 99) == ["b", "c", "a"])
    #expect(l.reordered(["a", "b", "c"], moving: "b", to: -4) == ["b", "a", "c"])
    #expect(l.reordered(["a", "b", "c"], moving: "z", to: 0) == ["a", "b", "c"])
}

@Test func fakeListRenameGivesMainSwiftsOutcome() {
    let l = FakeListEditing()
    #expect(l.commitRename("Hero", original: "Ball", validate: { _ in nil }) == .renamed("Hero"))
    #expect(l.commitRename("Ball", original: "Ball", validate: { _ in nil }) == .unchanged)
    #expect(l.cancelRename("Hero", original: "Ball") == .cancelled)
}

@Test func fakeListRenameNeverRefusesAndNeverTrims() {
    let l = FakeListEditing()
    #expect(l.commitRename("Hero", original: "Ball", validate: { _ in "Name taken" }) == .renamed("Hero"))
    #expect(l.commitRename("  Hero  ", original: "Ball", validate: { _ in nil }) == .renamed("  Hero  "))
    #expect(l.commitRename("   ", original: "Ball", validate: { _ in nil }) == .renamed("   "))
}

@Test func fakeListDropIndexRoundsAndClamps() {
    let l = FakeListEditing()
    #expect(l.dropIndex(atY: 52, rowHeight: 24, count: 5) == 2)
    #expect(l.dropIndex(atY: -30, rowHeight: 24, count: 5) == 0)
    #expect(l.dropIndex(atY: 1_000, rowHeight: 24, count: 5) == 5)
    #expect(l.dropIndex(atY: 52, rowHeight: 0, count: 5) == 0)
    #expect(l.dropIndex(atY: .nan, rowHeight: 24, count: 5) == 0)
}
