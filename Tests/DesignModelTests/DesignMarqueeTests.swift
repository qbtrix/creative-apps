// DesignMarqueeTests.swift: LiveMarquee on a `cards`-shaped tree built here with
// DesignPage's memberwise init: the marquee picks the touched layers of one level
// in paint order, never a hidden or locked layer or one inside them, and touching
// is closed intervals. Runs on Linux and macOS.
@testable import DesignModel
import Testing

@Suite struct DesignMarqueeTests {
    let marquee = LiveMarquee()

    /// Blueprint 4's `cards`: one page holding only Desktop, its children back to front.
    static func cards(_ change: (inout [DesignNode]) -> Void = { _ in }) -> DesignPage {
        func node(_ id: String, _ kind: DesignNodeKind, _ frame: DesignRect, children: [DesignNode] = [],
                  hidden: Bool = false, locked: Bool = false) -> DesignNode {
            DesignNode(id: id, name: id, kind: kind, frame: frame, children: children, isHidden: hidden, isLocked: locked)
        }
        let pair = node("Pair", .group, rc(900, 400, 300, 100), children: [
            node("E1", .ellipse, rc(900, 400, 100, 100)), node("E2", .ellipse, rc(1100, 400, 100, 100)),
        ])
        var nodes = [
            node("Desktop", .frame, rc(0, 0, 1440, 1024), children: [
                node("A", .rectangle, rc(100, 100, 100, 80)), node("B", .rectangle, rc(300, 140, 200, 80)),
                node("C", .rectangle, rc(700, 100, 100, 120)), node("Title", .text, rc(100, 40, 200, 32)), pair,
                node("Locked", .rectangle, rc(400, 600, 100, 100), locked: true),
                node("Hidden", .rectangle, rc(600, 600, 100, 100), hidden: true),
            ])
        ]
        change(&nodes)
        return DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: nodes)
    }

    func pick(_ from: DesignPoint, _ to: DesignPoint, in parentID: String?, on page: DesignPage = cards()) -> [String] {
        marquee.layers(touching: DesignRect(from: from, to: to), in: parentID, on: page)
    }

    @Test func insideDesktopPicksAAndBInPaintOrder() {
        // Title ends at y 72, above the marquee; C starts at x 700, right of it.
        #expect(pick(pt(80, 80), pt(520, 240), in: "Desktop") == ["A", "B"])
        #expect(pick(pt(520, 240), pt(80, 80), in: "Desktop") == ["A", "B"])
    }

    @Test func overOnlyLockedAndHiddenPicksNothing() {
        #expect(pick(pt(380, 580), pt(720, 720), in: "Desktop") == [])
    }

    @Test func theTopLevelPicksOnlyDesktop() {
        #expect(pick(pt(880, 380), pt(1220, 520), in: nil) == ["Desktop"])
    }

    @Test func insidePairPicksBothEllipses() {
        #expect(pick(pt(880, 380), pt(1220, 520), in: "Pair") == ["E1", "E2"])
    }

    @Test func aHiddenOrLockedParentPicksNothing() {
        let hidden = Self.cards { _ = $0.update("Pair") { $0.isHidden = true } }
        let locked = Self.cards { _ = $0.update("Pair") { $0.isLocked = true } }
        #expect(pick(pt(880, 380), pt(1220, 520), in: "Pair", on: hidden) == [])
        #expect(pick(pt(880, 380), pt(1220, 520), in: "Pair", on: locked) == [])
    }

    @Test func aParentInsideALockedOrHiddenLayerPicksNothing() {
        let locked = Self.cards { _ = $0.update("Desktop") { $0.isLocked = true } }
        let hidden = Self.cards { _ = $0.update("Desktop") { $0.isHidden = true } }
        #expect(pick(pt(880, 380), pt(1220, 520), in: "Pair", on: locked) == [])
        #expect(pick(pt(880, 380), pt(1220, 520), in: "Pair", on: hidden) == [])
    }

    @Test func aHiddenChildIsSkippedAndItsSiblingPicked() {
        let page = Self.cards { _ = $0.update("E1") { $0.isHidden = true } }
        #expect(pick(pt(880, 380), pt(1220, 520), in: "Pair", on: page) == ["E2"])
    }

    @Test func aZeroSizeRectOnAnEdgeTouches() {
        #expect(pick(pt(200, 140), pt(200, 140), in: "Desktop") == ["A"])
        #expect(pick(pt(500, 220), pt(500, 220), in: "Desktop") == ["B"])
        #expect(pick(pt(201, 140), pt(201, 140), in: "Desktop") == [])
    }

    @Test func anUnknownParentPicksNothing() {
        #expect(pick(pt(0, 0), pt(1440, 1024), in: "node-404") == [])
    }
}
