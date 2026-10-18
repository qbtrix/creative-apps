// SnapCandidateTests.swift: the snap contract's checks (editor-kernel EK-17,
// slice EK-snap, KJ5). Given a tree and the moving ids, `Snapping.candidates`
// names the frames a drag can snap to: the siblings of each moving id (or
// the children of the frame drawn into), their parent frames and the page;
// hidden layers and the moving subtree are skipped, locked ones kept. And
// `Snapping.offset` takes lines, then gaps, then whole points.
//
// The calls go through `candidates(_:moving:drawingInto:)` below, which
// frames each layer by its fixture box.
import Foundation
import Testing
import SuiteKernel

@Suite struct SnapCandidateTests {
    typealias Tree = LayerTree<KernelFixtures.Box>

    /// The page every check snaps on: Desktop's 1440 × 1024.
    static let page = Rect(minX: 0, minY: 0, maxX: 1440, maxY: 1024)

    /// The candidates for a drag of `moving` in `tree` on `page`, each
    /// layer's frame its fixture box.
    func candidates(_ tree: Tree, moving: [String], drawingInto parent: String? = nil) -> [SnapCandidate] {
        Snapping.candidates(in: tree, moving: moving, drawingInto: parent, page: Self.page,
                            frame: { $0.payload.frame })
    }

    /// The layer ids among `list` (the page, whose id is nil, left out).
    func ids(_ list: [SnapCandidate]) -> Set<String> { Set(list.compactMap(\.id)) }

    // MARK: Candidates on `cards`

    @Test func listsSiblingsParentFrameAndPage() {
        let found = candidates(KernelFixtures.cards, moving: ["a"])
        #expect(ids(found) == ["b", "c", "title", "pair", "locked", "desktop"])
        #expect(found.filter { $0.id == nil } == [SnapCandidate(id: nil, frame: Self.page)])
        #expect(found.count == 7)
    }

    @Test func framesComeFromTheFrameClosure() {
        let found = candidates(KernelFixtures.cards, moving: ["a"])
        #expect(found.contains(SnapCandidate(id: "b", frame: Rect(minX: 300, minY: 140, maxX: 500, maxY: 220))))
        #expect(found.contains(SnapCandidate(id: "pair", frame: Rect(minX: 900, minY: 400, maxX: 1200, maxY: 500))))
        #expect(found.contains(SnapCandidate(id: "desktop", frame: Self.page)))
    }

    @Test func skipsHidden() {
        let found = ids(candidates(KernelFixtures.cards, moving: ["a"]))
        #expect(!found.contains("hidden"))
    }

    @Test func keepsLocked() {
        let found = ids(candidates(KernelFixtures.cards, moving: ["a"]))
        #expect(found.contains("locked"))
    }

    @Test func listsParentFrame() {
        let found = candidates(KernelFixtures.cards, moving: ["e1"])
        #expect(ids(found).isSuperset(of: ["e2", "pair"]))
        #expect(found.contains { $0.id == nil })
        // A sibling of the parent is not a sibling of the moving child.
        #expect(!ids(found).contains("a"))
    }

    @Test func skipsTheMovingSubtree() {
        let found = ids(candidates(KernelFixtures.cards, moving: ["pair"]))
        #expect(found.isDisjoint(with: ["pair", "e1", "e2"]))
        #expect(found.isSuperset(of: ["a", "b", "c", "title", "locked", "desktop"]))
    }

    @Test func skipsEveryMovingId() {
        let found = ids(candidates(KernelFixtures.cards, moving: ["a", "b"]))
        #expect(found.isDisjoint(with: ["a", "b"]))
        #expect(found.isSuperset(of: ["c", "title", "pair", "locked", "desktop"]))
    }

    @Test func drawingIntoAFrameListsItsChildren() {
        let found = candidates(KernelFixtures.cards, moving: [], drawingInto: "pair")
        #expect(ids(found).isSuperset(of: ["e1", "e2", "pair"]))
        #expect(ids(found).isDisjoint(with: ["a", "b", "c", "title"]))
        #expect(found.contains(SnapCandidate(id: nil, frame: Self.page)))
    }

    @Test func thePageIsAlwaysACandidate() {
        for moving in [["a"], ["e1"], ["pair"], ["desktop"]] {
            let pages = candidates(KernelFixtures.cards, moving: moving).filter { $0.id == nil }
            #expect(pages == [SnapCandidate(id: nil, frame: Self.page)], "moving \(moving)")
        }
    }

    // MARK: Candidates on `tree200`

    @Test func rootSiblingsSkipHiddenKeepLocked() {
        let found = candidates(KernelFixtures.tree200, moving: ["header"])
        #expect(ids(found) == ["hero", "cards", "gallery", "footer", "background"])
        #expect(found.count == 6)
    }

    @Test func cardSiblingsAndTheirGroup() {
        let found = candidates(KernelFixtures.tree200, moving: ["card-1"])
        let cards = Set((2...30).map { "card-\($0)" })
        #expect(ids(found).isSuperset(of: cards.union(["cards"])))
        #expect(!ids(found).contains("card-1"))
        #expect(found.contains { $0.id == nil })
    }

    @Test func deepSiblingsListTheirColumn() {
        let found = ids(candidates(KernelFixtures.tree200, moving: ["item-2-3-1"]))
        #expect(found.isSuperset(of: Set((2...9).map { "item-2-3-\($0)" }).union(["row-2-col-3"])))
        #expect(found.isDisjoint(with: ["item-2-3-1", "item-1-1-1", "archive", "archive-1"]))
    }

    @Test func hiddenGroupsChildrenAreSkipped() {
        let found = ids(candidates(KernelFixtures.tree200, moving: ["archive-1"]))
        #expect(found.isDisjoint(with: Set((1...21).map { "archive-\($0)" }).union(["archive"])))
    }

    @Test func lockedGroupsChildrenAreKept() {
        let found = ids(candidates(KernelFixtures.tree200, moving: ["footer-1"]))
        #expect(found.isSuperset(of: Set((2...10).map { "footer-\($0)" }).union(["footer"])))
    }

    // MARK: Offset order

    @Test func linesBeforeGaps() {
        #expect(Snapping.offset(lines: 2, gaps: 5, wholePoints: 0.4) == 2)
        #expect(Snapping.offset(lines: 0, gaps: 5, wholePoints: 0.4) == 0)
        #expect(Snapping.offset(lines: -3, gaps: nil, wholePoints: 0.4) == -3)
    }

    @Test func gapsBeforeWholePoints() {
        #expect(Snapping.offset(lines: nil, gaps: 5, wholePoints: 0.4) == 5)
        #expect(Snapping.offset(lines: nil, gaps: 0, wholePoints: 0.4) == 0)
    }

    @Test func wholePointsLast() {
        #expect(Snapping.offset(lines: nil, gaps: nil, wholePoints: 0.4) == 0.4)
        #expect(Snapping.offset(lines: nil, gaps: nil, wholePoints: -1) == -1)
    }
}
