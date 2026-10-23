// LibraryKernelSelectionAdapterTests.swift: the catalog's grid selection is
// SuiteKernel's `Selection<String>` (adopt-kernel-selection AS-library). A
// click is the kernel's `pick` through the display order, an arrow its `move`
// in a grid of columns; a photo the collection doesn't show is refused and
// changes nothing; a change to the picked set ends the edit run, so one drag
// never spans two selections, and a refused or empty change keeps it.
// Plan: Tests/mutations/LibraryModel.KernelSelectionAdapter.json. Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreColor
@testable import LibraryModel
import SuiteKernel
import Testing

@Suite struct LibraryKernelSelectionAdapterTests {
    /// P1...P6 in name order; P2 and P5 are flagged, so Favorites shows only them.
    static func six() -> LibraryCatalog {
        var catalog = LibraryCatalog()
        catalog.load((1...6).map {
            PhotoItem(
                name: "P\($0)", captureDate: Date(timeIntervalSince1970: Double($0) * 60), color: Color3(0, 0, 0),
                isFlagged: $0 == 2 || $0 == 5)
        })
        catalog.setSort(.name)
        return catalog
    }

    /// A keyed edit to P1, as one sample of a slider drag.
    static func dragSample(_ catalog: inout LibraryCatalog, _ stars: Int) {
        catalog.recordEdit("Set Rating", coalesceKey: "stars", ids: ["P1"]) { $0.rating = stars }
    }

    @Test func theSelectionIsTheKernelsInPickOrder() {
        var catalog = Self.six()
        let pick1 = catalog.pick("P4", .replace)
        #expect(pick1)
        let pick2 = catalog.pick("P2", .toggle)
        #expect(pick2)
        #expect(catalog.picks.ordered == ["P4", "P2"])
        #expect(catalog.picks.primary == "P2")
        #expect(catalog.selection == ["P2", "P4"])
        #expect(catalog.cullTargets == ["P2", "P4"])
        let pick3 = catalog.pick("P4", .toggle)
        #expect(pick3)
        #expect(catalog.selection == ["P2"])
    }

    @Test func shiftClickExtendsFromTheAnchorThroughTheOrder() {
        var catalog = Self.six()
        catalog.pick("P2", .replace)
        catalog.pick("P5", .extend)
        #expect(catalog.selection == ["P2", "P3", "P4", "P5"])
        catalog.pick("P3", .extend)
        #expect(catalog.selection == ["P2", "P3"])
    }

    @Test func aPhotoTheCollectionHidesIsRefusedAndChangesNothing() {
        var catalog = Self.six()
        catalog.selectCollection("favorites")
        catalog.pick("P2", .replace)
        let before = catalog
        let pick4 = catalog.pick("P3", .replace)
        #expect(!pick4)
        let pick5 = catalog.pick("P3", .toggle)
        #expect(!pick5)
        let pick6 = catalog.pick("missing", .extend)
        #expect(!pick6)
        #expect(catalog.selection == ["P2"])
        #expect(catalog == before && catalog.picks == before.picks)
        catalog.pick("P5", .extend)
        #expect(catalog.selection == ["P2", "P5"])
    }

    @Test func aRefusedOrEmptyPickKeepsTheRun() {
        var catalog = Self.six()
        catalog.pick("P1", .replace)
        Self.dragSample(&catalog, 3)
        let pick7 = catalog.pick("missing", .replace)
        #expect(!pick7)
        let pick8 = catalog.pick("P1", .replace)
        #expect(!pick8)
        catalog.select(["P1"])
        Self.dragSample(&catalog, 4)
        #expect(catalog.history.undo.count == 1 && catalog.history.open)
    }

    @Test func aPickThatChangesTheSelectionEndsTheRun() {
        var catalog = Self.six()
        catalog.pick("P1", .replace)
        Self.dragSample(&catalog, 3)
        let pick9 = catalog.pick("P3", .toggle)
        #expect(pick9)
        #expect(!catalog.history.open)
        Self.dragSample(&catalog, 4)
        #expect(catalog.history.undo.count == 2)
        catalog.select(["P3"])
        Self.dragSample(&catalog, 5)
        #expect(catalog.history.undo.count == 3)
    }

    @Test func arrowsMoveOnePhotoThroughTheGrid() {
        var catalog = Self.six()
        catalog.pick("P1", .replace)
        let path: [(Direction, String)] = [
            (.right, "P2"), (.down, "P5"), (.down, "P5"), (.left, "P4"), (.up, "P1"), (.up, "P1"), (.left, "P1"),
        ]
        for (direction, landed) in path {
            catalog.move(direction, columns: 3)
            #expect(catalog.selection == [landed])
        }
        catalog.pick("P6", .extend)
        catalog.move(.right, columns: 3)
        #expect(catalog.selection == ["P6"])
    }

    @Test func anArrowWithNothingSelectedPicksTheFirstPhoto() {
        var catalog = Self.six()
        catalog.move(.down, columns: 3)
        #expect(catalog.selection == ["P1"])
        var empty = LibraryCatalog()
        empty.move(.down, columns: 3)
        #expect(empty.selection.isEmpty)
    }

    @Test func hugeOrDegenerateColumnsStayInsideTheGrid() {
        var catalog = Self.six()
        catalog.pick("P3", .replace)
        catalog.move(.down, columns: Int.max)
        #expect(catalog.selection == ["P3"])
        catalog.move(.up, columns: Int.min)
        #expect(catalog.selection == ["P2"])
        catalog.move(.down, columns: 0)
        #expect(catalog.selection == ["P3"])
    }

    @Test func anArrowEndsTheRunOnlyWhenItMoves() {
        var catalog = Self.six()
        catalog.pick("P1", .replace)
        Self.dragSample(&catalog, 3)
        catalog.move(.left, columns: 3)
        Self.dragSample(&catalog, 4)
        #expect(catalog.history.undo.count == 1)
        catalog.move(.right, columns: 3)
        Self.dragSample(&catalog, 5)
        #expect(catalog.history.undo.count == 2)
    }
}
