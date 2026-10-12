// LibraryCellSizeFuzzTests.swift: adversarial and seeded fuzz tests for
// LibraryCatalog.stepCellSize(by:) (#154). Step counts at and around the Int
// overflow edges, and long random walks checked against a wide reference.
// Runs on Linux and macOS.
import LibraryModel
import Testing

/// A small deterministic generator (SplitMix64) so a failing walk replays.
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

/// The expected size after one step, computed in Double so no step count can overflow.
private func reference(_ size: Int, _ steps: Int) -> Int {
    let raw = Double(size) + Double(steps) * Double(LibraryCatalog.cellSizeStep)
    return Int(min(max(raw, 80), 320))
}

private func expectInvariants(_ catalog: LibraryCatalog) {
    #expect((80...320).contains(catalog.cellSize))
    #expect((catalog.cellSize - 80) % LibraryCatalog.cellSizeStep == 0)
    #expect(catalog.canShowLargerThumbnails == (catalog.cellSize < 320))
    #expect(catalog.canShowSmallerThumbnails == (catalog.cellSize > 80))
}

/// Step counts where `steps * 40` or `cellSize + steps * 40` would overflow, and their neighbours.
private let edgeSteps: [Int] = [
    Int.max, Int.max - 1, Int.min, Int.min + 1,
    Int.max / 40, Int.max / 40 + 1, Int.min / 40, Int.min / 40 - 1,
    Int.max / 2, Int.min / 2, 7, -7, 6, -6, 5, -5, 1, -1, 0,
]

@Test(arguments: [80, 120, 160, 200, 240, 280, 320])
func everyEdgeStepFromEverySizeStaysInRange(start: Int) {
    for steps in edgeSteps {
        var catalog = LibraryCatalog()
        catalog.stepCellSize(by: (start - catalog.cellSize) / LibraryCatalog.cellSizeStep)
        #expect(catalog.cellSize == start)
        catalog.stepCellSize(by: steps)
        #expect(catalog.cellSize == reference(start, steps), "start \(start), steps \(steps)")
        expectInvariants(catalog)
    }
}

@Test func zeroStepsLeavesTheCatalogUnchanged() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.select(["IMG_0001"])
    let before = catalog
    catalog.stepCellSize(by: 0)
    #expect(catalog == before)
}

@Test func steppingOnlyChangesTheCellSize() {
    var catalog = LibraryCatalog()
    catalog.loadSamples()
    catalog.selectCollection("favorites")
    catalog.setSort(.rating)
    let shown = catalog.sortedItems.map(\.id)
    catalog.select(Set(shown.prefix(2)))
    if let first = shown.first { catalog.open(first) }
    let before = catalog
    catalog.stepCellSize(by: Int.min)
    catalog.stepCellSize(by: Int.max)
    #expect(catalog.cellSize == 320)
    #expect(catalog.items == before.items && catalog.collections == before.collections)
    #expect(catalog.selection == before.selection && catalog.sort == before.sort)
    #expect(catalog.mode == before.mode && catalog.focusedItemID == before.focusedItemID)
    #expect(catalog.selectedCollectionID == before.selectedCollectionID)
}

@Test func oneLargeStepEqualsThatManySingleSteps() {
    for steps in -10...10 {
        var once = LibraryCatalog()
        once.stepCellSize(by: steps)
        var single = LibraryCatalog()
        for _ in 0..<steps.magnitude { single.stepCellSize(by: steps.signum()) }
        #expect(once.cellSize == single.cellSize, "steps \(steps)")
    }
}

@Test(arguments: [UInt64(1), 7, 154, 0xDEAD_BEEF])
func seededRandomWalkMatchesTheWideReference(seed: UInt64) {
    var rng = SeededGenerator(state: seed)
    var catalog = LibraryCatalog()
    var expected = catalog.cellSize
    for _ in 0..<2_000 {
        let steps: Int
        switch rng.next() % 4 {
        case 0: steps = Int.random(in: -3...3, using: &rng)
        case 1: steps = edgeSteps.randomElement(using: &rng) ?? 0
        default: steps = Int(truncatingIfNeeded: rng.next())
        }
        catalog.stepCellSize(by: steps)
        expected = reference(expected, steps)
        #expect(catalog.cellSize == expected, "seed \(seed), steps \(steps)")
        expectInvariants(catalog)
    }
}
