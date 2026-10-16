// DesignSeveralTransformTests.swift: LiveTransforming, the live Move, Resize,
// Nudge and Delete for a selection, on blueprint 4's `cards` (the fixture
// DesignMarqueeTests builds). Several layers move with their subtrees as one
// coalescing step, resize scales each one inside the selection's box (a box of
// no width never divides by zero), and a locked or hidden-in-tree layer refuses
// every write by the selected layer's name. Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignSeveralTransformTests {
    let live = LiveTransforming()
    let cards = DesignMarqueeTests.cards()

    func frame(_ id: String, _ edit: DesignEdit) -> DesignRect? { edit.nodes.node(id)?.frame }

    func page(_ edit: DesignEdit) -> DesignPage {
        var page = cards
        page.nodes = edit.nodes
        return page
    }

    @Test func aAndBMoveAsOneRun() throws {
        let edit = try live.move(["A", "B"], by: pt(40, 0), on: cards)
        #expect(frame("A", edit) == rc(140, 100, 100, 80))
        #expect(frame("B", edit) == rc(340, 140, 200, 80))
        #expect(frame("C", edit) == rc(700, 100, 100, 120))
        #expect(edit.name == "Move")
        #expect(edit.coalescingKey == DesignEdit.runKey("move", ["A", "B"]))
        #expect(edit.selection == ["A", "B"])
        #expect(live.transformHelp(["A", "B"], on: cards) == nil)
    }

    @Test func aGroupMovesWithItsChildrenAndASelectedChildMovesOnce() throws {
        let edit = try live.move(["Pair", "E1"], by: pt(0, 10), on: cards)
        #expect(frame("Pair", edit) == rc(900, 410, 300, 100))
        #expect(frame("E1", edit) == rc(900, 410, 100, 100))
        #expect(frame("E2", edit) == rc(1100, 410, 100, 100))
    }

    @Test func theBottomRightHandleScalesInTheBox() throws {
        // The box is (100, 100)–(500, 220); B's offset 200 scales by 420/400 to 210.
        let edit = try live.resize(["A", "B"], handle: .bottomRight, by: pt(20, 0), modifiers: [], on: cards)
        #expect(frame("A", edit) == rc(100, 100, 105, 80))
        #expect(frame("B", edit) == rc(310, 140, 210, 80))
        #expect(edit.name == "Resize")
        #expect(edit.coalescingKey == DesignEdit.runKey("resize", ["A", "B"]))
    }

    @Test func shiftKeepsTheBoxRatio() throws {
        let edit = try live.resize(["A", "B"], handle: .bottomRight, by: pt(20, 0), modifiers: .shift, on: cards)
        let a = try #require(frame("A", edit))
        let b = try #require(frame("B", edit))
        #expect(b == rc(310, 142, 210, 84))
        let (width, height) = (b.maxX - a.x, Swift.max(a.maxY, b.maxY) - a.y)
        #expect(abs(width / height - 400.0 / 120.0) <= 1e-9)
    }

    @Test func aBoxOfNoWidthNeverDividesByZero() throws {
        let flat = DesignMarqueeTests.cards { nodes in
            _ = nodes.update("A") { $0.frame = rc(100, 100, 0, 80) }
            _ = nodes.update("B") { $0.frame = rc(100, 140, 0, 80) }
        }
        for modifiers: DesignModifiers in [[], .shift, .option] {
            let edit = try live.resize(["A", "B"], handle: .bottomRight, by: pt(20, 0), modifiers: modifiers, on: flat)
            for id in ["A", "B"] {
                let moved = try #require(frame(id, edit))
                let finite = [moved.x, moved.y, moved.width, moved.height].allSatisfy(\.isFinite)
                #expect(finite)
                #expect(moved.width >= 1)
            }
        }
        let edit = try live.resize(["A", "B"], handle: .right, by: pt(20, 0), modifiers: [], on: flat)
        #expect(frame("A", edit) == rc(100, 100, 20, 80))
        #expect(frame("B", edit) == rc(100, 140, 20, 80))
    }

    @Test func nudgeMovesOneOrTenPoints() throws {
        let small = try live.nudge(["A", "B"], .right, large: false, on: cards)
        #expect(frame("A", small) == rc(101, 100, 100, 80))
        #expect(frame("B", small) == rc(301, 140, 200, 80))
        #expect(small.name == "Nudge")
        #expect(small.coalescingKey == DesignEdit.runKey("nudge", ["A", "B"]))
        let large = try live.nudge(["A", "B"], .up, large: true, on: cards)
        #expect(frame("A", large) == rc(100, 90, 100, 80))
        #expect(frame("B", large) == rc(300, 130, 200, 80))
    }

    @Test func deletingAAndBIsOneStep() throws {
        let edit = try live.delete(["A", "B"], on: cards)
        #expect(edit.nodes.node("A") == nil)
        #expect(edit.nodes.node("B") == nil)
        #expect(edit.nodes.node("C") != nil)
        #expect(edit.name == "Delete")
        #expect(edit.coalescingKey == nil)
        #expect(edit.selection.isEmpty)
        #expect(try live.delete(["A"], on: cards).name == "Delete Rectangle")
    }

    /// Every write on `ids` throws `refusal` and the help reads its sentence.
    func expectRefused(_ ids: [String], _ refusal: DesignRefusal, on page: DesignPage) {
        #expect(throws: refusal) { try live.move(ids, by: pt(40, 0), on: page) }
        #expect(throws: refusal) { try live.resize(ids, handle: .bottomRight, by: pt(20, 0), modifiers: [], on: page) }
        #expect(throws: refusal) { try live.nudge(ids, .left, large: false, on: page) }
        #expect(throws: refusal) { try live.delete(ids, on: page) }
        #expect(live.transformHelp(ids, on: page) == refusal.help)
    }

    @Test func aLockedLayerRefusesTheSelection() {
        expectRefused(["A", "Locked"], .locked("Locked"), on: cards)
        #expect(live.transformHelp(["A", "Locked"], on: cards) == "Unlock Locked to change it.")
    }

    @Test func aHiddenAncestorRefusesByTheSelectedLayersName() {
        let hidden = DesignMarqueeTests.cards { _ = $0.update("Pair") { $0.isHidden = true } }
        expectRefused(["E1"], .hidden("E1"), on: hidden)
        expectRefused(["A", "Hidden"], .hidden("Hidden"), on: cards)
    }

    @Test func nothingSelectedOrNothingMovedRefuses() {
        expectRefused([], .nothingSelected, on: cards)
        #expect(throws: DesignRefusal.unchanged) { try live.move(["A", "B"], by: pt(0, 0), on: cards) }
    }

    @Test func aDragOnAnAlreadyMovedSelectionKeepsWorking() throws {
        let first = try live.move(["A", "B"], by: pt(40, 0), on: cards)
        let again = try live.move(["A", "B"], by: pt(10, 5), on: page(first))
        #expect(frame("A", again) == rc(150, 105, 100, 80))
        #expect(frame("B", again) == rc(350, 145, 200, 80))
        #expect(again.coalescingKey == first.coalescingKey)
        let resized = try live.resize(["B", "A"], handle: .bottomRight, by: pt(20, 0), modifiers: [], on: page(first))
        #expect(frame("B", resized) == rc(350, 140, 210, 80))
        #expect(resized.coalescingKey == DesignEdit.runKey("resize", ["A", "B"]))
    }
}
