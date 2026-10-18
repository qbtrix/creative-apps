// SelectionTests.swift: the checks for `Selection<ID>` (editor-kernel EK-9,
// slice EK-sel), written from the packet before the body: replace, toggle and
// extend with and without an order, the primary, `canAdd` refusals, prune and
// the grid move, plus KJ2's selection half. Every test waits on EK-10, which
// writes the body over the EK-2 stub and turns them on (docs/factory/lead.md
// rule 13). The mutation table names extendAppendsOnAStage,
// extendRangeIsClosed and toggleRefusesLocked.
import Testing
import SuiteKernel

@Suite struct SelectionTests {
    /// The order a list or canvas gives: back to front, a to f.
    static let order = ["a", "b", "c", "d", "e", "f"]

    @Test(.disabled("waits on EK-10")) func replaceSetsOneAndTheAnchor() {
        var sel = Selection(["a", "c"])
        let changed1 = sel.pick("b", .replace)
        #expect(changed1)
        #expect(sel.ordered == ["b"])
        #expect(sel.anchor == "b")
        #expect(sel.primary == "b")
        // Replacing with what is already the whole selection changes nothing.
        let changed2 = sel.pick("b", .replace)
        #expect(!changed2)
        #expect(sel.ordered == ["b"])
    }

    @Test(.disabled("waits on EK-10")) func replaceRefusedByCanAdd() {
        var sel = Selection(["a"])
        let changed1 = sel.pick("locked", .replace, canAdd: { $0 != "locked" })
        #expect(!changed1)
        #expect(sel.ordered == ["a"])
    }

    @Test(.disabled("waits on EK-10")) func toggleAppendsAndRemoves() {
        var sel = Selection<String>()
        let changed1 = sel.pick("a", .toggle)
        #expect(changed1)
        let changed2 = sel.pick("c", .toggle)
        #expect(changed2)
        #expect(sel.ordered == ["a", "c"])
        #expect(sel.primary == "c")
        #expect(sel.anchor == "c")
        let changed3 = sel.pick("a", .toggle)
        #expect(changed3)
        #expect(sel.ordered == ["c"])
        #expect(!sel.contains("a"))
    }

    @Test(.disabled("waits on EK-10")) func toggleRefusesLocked() {
        var sel = Selection(["a"])
        let changed1 = sel.pick("locked", .toggle, canAdd: { $0 != "locked" })
        #expect(!changed1)
        #expect(sel.ordered == ["a"])
        #expect(!sel.contains("locked"))
    }

    @Test(.disabled("waits on EK-10")) func extendAppendsOnAStage() {
        // No order (a stage of free shapes): Shift-click adds the item alone.
        var sel = Selection<String>()
        sel.pick("a", .replace)
        let changed1 = sel.pick("d", .extend)
        #expect(changed1)
        #expect(sel.ordered == ["a", "d"])
        #expect(sel.primary == "d")
        let changed2 = sel.pick("locked", .extend, canAdd: { $0 != "locked" })
        #expect(!changed2)
        #expect(sel.ordered == ["a", "d"])
    }

    @Test(.disabled("waits on EK-10")) func extendRangeIsClosed() {
        var sel = Selection<String>()
        sel.pick("b", .replace)
        let changed1 = sel.pick("d", .extend, order: Self.order)
        #expect(changed1)
        // The range runs from the anchor through the clicked item, both ends included.
        #expect(sel.ordered == ["b", "c", "d"])
        #expect(sel.primary == "d")
        // Shift-click keeps the anchor where the last plain or Command click left it.
        #expect(sel.anchor == "b")
    }

    @Test(.disabled("waits on EK-10")) func extendBackwardsCoversTheRange() {
        var sel = Selection<String>()
        sel.pick("e", .replace)
        let changed1 = sel.pick("c", .extend, order: Self.order)
        #expect(changed1)
        #expect(sel.set == ["c", "d", "e"])
        #expect(sel.anchor == "e")
    }

    @Test(.disabled("waits on EK-10")) func extendAgainReplacesTheAnchorsRun() {
        var sel = Selection<String>()
        sel.pick("f", .replace)
        sel.pick("b", .toggle)
        sel.pick("e", .extend, order: Self.order)
        #expect(sel.set == ["f", "b", "c", "d", "e"])
        // A shorter second range shrinks the run; the item toggled in before it stays.
        sel.pick("c", .extend, order: Self.order)
        #expect(sel.set == ["f", "b", "c"])
        #expect(sel.contains("f"))
        #expect(!sel.contains("d") && !sel.contains("e"))
    }

    @Test(.disabled("waits on EK-10")) func extendRangeSkipsWhatCanAddRefuses() {
        var sel = Selection<String>()
        sel.pick("a", .replace)
        sel.pick("d", .extend, order: Self.order, canAdd: { $0 != "c" })
        #expect(sel.set == ["a", "b", "d"])
        #expect(!sel.contains("c"))
    }

    @Test(.disabled("waits on EK-10")) func primaryIsTheLastPicked() {
        var sel = Selection<String>()
        #expect(sel.primary == nil)
        sel.pick("c", .toggle)
        sel.pick("a", .toggle)
        #expect(sel.primary == "a")
        sel.pick("a", .toggle)
        #expect(sel.primary == "c")
    }

    @Test(.disabled("waits on EK-10")) func replaceClearAndSelectAll() {
        var sel = Selection<String>()
        sel.replace(["d", "b"])
        #expect(sel.ordered == ["d", "b"])
        #expect(sel.primary == "b")
        sel.clear()
        #expect(sel.ordered.isEmpty && sel.anchor == nil && sel.primary == nil)
        sel.selectAll(Self.order, canAdd: { $0 != "c" })
        #expect(sel.ordered == ["a", "b", "d", "e", "f"])
        #expect(sel.set.count == 5)
    }

    @Test(.disabled("waits on EK-10")) func pruneDropsDeadIdsInOrder() {
        var sel = Selection<String>()
        sel.pick("a", .toggle)
        sel.pick("c", .toggle)
        sel.pick("e", .toggle)
        sel.prune { $0 != "c" && $0 != "e" }
        #expect(sel.ordered == ["a"])
        #expect(sel.primary == "a")
        // The anchor was "e", which is gone: no anchor points at a dead id.
        #expect(sel.anchor != "e")
    }

    @Test(.disabled("waits on EK-10")) func moveByArrowInAGrid() {
        // Twelve cells, four columns: 0 1 2 3 / 4 5 6 7 / 8 9 10 11.
        let grid = Array(0..<12)
        var sel = Selection([5])
        sel.move(.right, order: grid, columns: 4)
        #expect(sel.ordered == [6])
        sel.move(.down, order: grid, columns: 4)
        #expect(sel.ordered == [10])
        sel.move(.left, order: grid, columns: 4)
        #expect(sel.ordered == [9])
        sel.move(.up, order: grid, columns: 4)
        #expect(sel.ordered == [5])
        #expect(sel.primary == 5)
    }

    @Test(.disabled("waits on EK-10")) func moveStopsAtTheGridEdge() {
        let grid = Array(0..<12)
        var top = Selection([1])
        top.move(.up, order: grid, columns: 4)
        #expect(top.ordered == [1])
        var first = Selection([0])
        first.move(.left, order: grid, columns: 4)
        #expect(first.ordered == [0])
        var last = Selection([11])
        last.move(.right, order: grid, columns: 4)
        last.move(.down, order: grid, columns: 4)
        #expect(last.ordered == [11])
    }

    @Test(.disabled("waits on EK-10")) func moveStartsFromThePrimary() {
        let grid = Array(0..<12)
        var sel = Selection([2, 5])
        sel.move(.right, order: grid, columns: 4)
        #expect(sel.ordered == [6])
    }

    /// KJ2, the selection walk: click, Shift-click, Command-click, prune, arrow.
    @Test(.disabled("waits on EK-10")) func selectionWalk() {
        let cards = (1...8).map { "card-\($0)" }
        var sel = Selection<String>()
        sel.pick("card-1", .replace)
        sel.pick("card-4", .extend, order: cards)
        #expect(sel.ordered.count == 4 && sel.primary == "card-4")
        sel.pick("card-2", .toggle)
        #expect(sel.set == ["card-1", "card-3", "card-4"])
        sel.prune { $0 != "card-3" }
        #expect(sel.set == ["card-1", "card-4"])
        sel.replace(["card-4"])
        sel.move(.right, order: cards, columns: 4)
        #expect(sel.ordered == ["card-5"])
    }
}
