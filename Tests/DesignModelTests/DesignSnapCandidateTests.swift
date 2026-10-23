// DesignSnapCandidateTests.swift: the snap contract on Design (snapping SN-1 and
// SN-12, journey MJ12 `walkSnapContract`) on the `cards` fixture. The guide types
// are the kernel's; `snapCandidates` names what a drag can line up with through
// `Snapping.candidates` over the page's layer tree; `.noSnap` comes from ⌘ or
// Snap to Layers off; `snapGuides` is the live set of the drag under way and nil
// otherwise (SN-9, live since SN-4); the kernel's line engine
// snaps to A's candidates (SN-2) and its gap engine names A's gaps (SN-3).
// Runs on Linux and macOS.
import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignSnapCandidateTests {
    /// cards' ids: Desktop holds A, B, C, Title, Pair (E1, E2), Locked and Hidden.
    static let (desktop, a, b, c, title, pair, e1, e2, locked, hidden) =
        ("node-1", "node-2", "node-3", "node-4", "node-5", "node-6", "node-7", "node-8", "node-9", "node-10")

    /// The page, 1440 × 1024.
    static let page = Rect(minX: 0, minY: 0, maxX: 1440, maxY: 1024)

    func ids(_ list: [DesignSnapCandidate]) -> Set<String> { Set(list.compactMap(\.id)) }

    func candidates(_ moving: [String], into parent: String? = nil) -> [DesignSnapCandidate] {
        DesignFixtures.cards.snapCandidates(moving: moving, drawingInto: parent)
    }

    // MARK: Candidates

    @Test func listsASiblingsDesktopAndThePage() {
        let found = candidates([Self.a])
        #expect(ids(found) == [Self.b, Self.c, Self.title, Self.pair, Self.locked, Self.desktop])
        #expect(found.last == DesignSnapCandidate(id: nil, frame: Self.page))
        #expect(found.count == 7)
    }

    @Test func framesAreTheNodesFrames() {
        let found = candidates([Self.a])
        #expect(found.contains(DesignSnapCandidate(id: Self.b, frame: Rect(minX: 300, minY: 140, maxX: 500, maxY: 220))))
        #expect(found.contains(DesignSnapCandidate(id: Self.pair, frame: Rect(minX: 900, minY: 400, maxX: 1200, maxY: 500))))
        #expect(found.contains(DesignSnapCandidate(id: Self.desktop, frame: Self.page)))
    }

    @Test func skipsHidden() {
        #expect(!ids(candidates([Self.a])).contains(Self.hidden))
        #expect(!ids(candidates([], into: Self.desktop)).contains(Self.hidden))
    }

    @Test func keepsLocked() {
        #expect(ids(candidates([Self.a])).contains(Self.locked))
    }

    @Test func leavesOutTheMovingLayersAndWhatIsInsideThem() {
        let pair = ids(candidates([Self.pair]))
        #expect(!pair.contains(Self.pair) && !pair.contains(Self.e1) && !pair.contains(Self.e2))
        let two = ids(candidates([Self.a, Self.b]))
        #expect(!two.contains(Self.a) && !two.contains(Self.b))
        #expect(two.isSuperset(of: [Self.c, Self.title, Self.pair, Self.locked, Self.desktop]))
        // E1 moving with its group: E2 sits inside a moving layer, so it is no candidate.
        let nested = ids(candidates([Self.pair, Self.e1]))
        #expect(!nested.contains(Self.e2))
        #expect(nested == [Self.a, Self.b, Self.c, Self.title, Self.locked, Self.desktop])
    }

    @Test func aDrawGetsTheFramesVisibleChildrenTheFrameAndThePage() {
        let found = candidates([], into: Self.desktop)
        #expect(ids(found) == [Self.a, Self.b, Self.c, Self.title, Self.pair, Self.locked, Self.desktop])
        #expect(found.last == DesignSnapCandidate(id: nil, frame: Self.page))
    }

    @Test func noPageNoCandidates() {
        #expect(DesignWorkspace().snapCandidates(moving: [], drawingInto: nil).isEmpty)
    }

    // MARK: Modifiers and settings

    @Test func commandOrSnapToLayersOffTurnsSnappingOff() {
        #expect(DesignModifiers(shift: false, option: false, command: true, snapToLayers: true).contains(.noSnap))
        #expect(DesignModifiers(shift: false, option: false, command: false, snapToLayers: false).contains(.noSnap))
        #expect(!DesignModifiers(shift: false, option: false, command: false, snapToLayers: true).contains(.noSnap))
        #expect(DesignModifiers(shift: true, option: true, command: false, snapToLayers: true) == [.shift, .option])
        #expect(DesignModifiers.noSnap.rawValue == 4)
        #expect(DesignSnapSettings.defaultsKey == "design.snapToLayers")
    }

    // MARK: Guides

    @Test func summaryIsTheKernels() {
        #expect(DesignSnapGuides().summary == "")
        let full = DesignSnapGuides(
            lines: [DesignSnapLine(axis: .x, at: 300, from: 100, to: 220)],
            gaps: [DesignSnapGap(axis: .x, from: 200, to: 300, across: 140, isSpacing: false),
                   DesignSnapGap(axis: .x, from: 500, to: 600, across: 160, isSpacing: true)])
        #expect(full.summary == "x 300, gap x 100, spacing x 100")
    }

    @Test func snapGuidesAreTheLiveSetOnlyWhileADragRuns() {
        var workspace = DesignFixtures.cards
        #expect(workspace.snapGuides == nil)
        workspace.selectItem(Self.a)
        // A at (110, 100): its top, centre and bottom on C's and B's lines, 90 to B, 28 below Title.
        workspace.drag(from: DesignPoint(x: 150, y: 140), to: DesignPoint(x: 160, y: 140), modifiers: [])
        #expect(workspace.snapGuides?.summary == "y 100, y 140, y 180, gap x 90, gap y 28")
        workspace.drag(from: DesignPoint(x: 150, y: 140), to: DesignPoint(x: 160, y: 140), modifiers: .noSnap)
        #expect(workspace.snapGuides == DesignSnapGuides.empty)
        workspace.endDrag()
        #expect(workspace.snapGuides == nil)
    }

    @Test func emptyAndTheInitDefaultHaveNoLinesAndNoGaps() {
        #expect(DesignSnapGuides.empty.lines.isEmpty && DesignSnapGuides.empty.gaps.isEmpty)
        #expect(DesignSnapGuides() == DesignSnapGuides.empty)
        #expect(DesignSnapGuides.empty.summary == "")
        #expect(DesignSnapGuides.fake != DesignSnapGuides.empty)
    }

    @Test func theLineAndGapEnginesWorkOnACandidates() {
        let found = candidates([Self.a])
        let box = Rect(minX: 297.4, minY: 100.4, maxX: 397.4, maxY: 180.4)
        let offset = SnapLines(found).offset(.x, for: [297.4, 347.4, 397.4], tolerance: 4)
        #expect(offset.map { abs($0 - 2.6) < 1e-9 } == true)
        #expect(SnapLines(found).lines(on: box).isEmpty)
        // B overlaps the box, so C is its right neighbour (302.6) and Title sits 28.4 above; no equal gap is near.
        #expect(SnapGaps(found).spacingOffset(.x, for: box, tolerance: 4) == nil)
        #expect(DesignSnapGuides(gaps: SnapGaps(found).gaps(around: box)).summary == "gap x 303, gap y 28")
    }

    // MARK: MJ12

    /// MJ12 as far as SN-1 and SN-9 cover it: A's candidates, the modifier mapping, the empty and
    /// full summaries, the live guides only while a drag runs, a line engine that finds A already
    /// aligned, and a gap engine that finds A's gaps to B and Title and no equal spacing.
    @Test func walkSnapContract() {
        var workspace = DesignFixtures.cards
        let found = workspace.snapCandidates(moving: [Self.a], drawingInto: nil)
        #expect(ids(found) == [Self.b, Self.c, Self.title, Self.pair, Self.locked, Self.desktop])
        #expect(found.filter { $0.id == nil }.count == 1)

        let held = DesignModifiers(shift: false, option: false, command: true, snapToLayers: true)
        let off = DesignModifiers(shift: false, option: false, command: false, snapToLayers: false)
        #expect(held.contains(.noSnap) && off.contains(.noSnap))

        #expect(DesignSnapGuides.empty.summary == "")
        #expect(DesignSnapGuides.empty.lines.isEmpty && DesignSnapGuides.empty.gaps.isEmpty)
        #expect(DesignSnapGuides.fake.summary == "x 300, gap x 100, spacing x 100")

        #expect(workspace.snapGuides == nil)
        workspace.selectItem(Self.a)
        workspace.drag(from: DesignPoint(x: 150, y: 140), to: DesignPoint(x: 160, y: 140), modifiers: [])
        #expect(workspace.snapGuides?.summary == "y 100, y 140, y 180, gap x 90, gap y 28")
        workspace.endDrag()
        #expect(workspace.snapGuides == nil)

        let box = Rect(minX: 100, minY: 100, maxX: 200, maxY: 180)
        #expect(SnapLines(found).offset(.y, for: [100, 140, 180], tolerance: 4) == 0)
        #expect(DesignSnapGuides(gaps: SnapGaps(found).gaps(around: box)).summary == "gap x 100, gap y 28")
        #expect(SnapGaps(found).spacingOffset(.y, for: box, tolerance: 4) == nil)
    }
}
