// DesignFrameLabelTests.swift: which frames the canvas names and where the name
// sits (#1387, #266). Visible top-level frames only, back to front; the name's
// bottom sits the gap above the frame's top, even above the page's top edge.
// Runs on Linux and macOS.
import DesignModel
import Testing

/// A page holding `nodes` at the top level.
private func page(_ nodes: [DesignNode]) -> DesignPage {
    DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: nodes)
}

private func frame(_ name: String, children: [DesignNode] = [], hidden: Bool = false) -> DesignNode {
    DesignNode(id: name, name: name, kind: .frame, frame: rc(0, 0, 400, 300), children: children, isHidden: hidden)
}

@Suite struct DesignFrameLabelTests {
    @Test func cardsNamesOnlyDesktop() throws {
        let cards = try #require(DesignFixtures.cards.selectedPage)
        #expect(DesignFrameLabel.labelled(on: cards).map(\.name) == ["Desktop"])
    }

    @Test func aFrameNestedInDesktopGetsNoName() {
        let card = frame("Card")
        let labelled = DesignFrameLabel.labelled(on: page([frame("Desktop", children: [card])]))
        #expect(labelled.map(\.name) == ["Desktop"])
    }

    @Test func aHiddenTopLevelFrameGetsNoName() {
        let labelled = DesignFrameLabel.labelled(on: page([frame("Desktop"), frame("Spare", hidden: true)]))
        #expect(labelled.map(\.name) == ["Desktop"])
    }

    @Test func aTopLevelShapeGetsNoNameAndFramesKeepTheirOrder() {
        let shape = DesignNode(id: "Box", name: "Box", kind: .rectangle, frame: rc(0, 0, 10, 10))
        let labelled = DesignFrameLabel.labelled(on: page([frame("Back"), shape, frame("Front")]))
        #expect(labelled.map(\.name) == ["Back", "Front"])
    }

    @Test func aFrameAtThePageTopKeepsItsNameAbove() {
        #expect(DesignFrameLabel.bottom(frameTop: 0, gap: 4) == -4)
        #expect(DesignFrameLabel.bottom(frameTop: 320, gap: 2) == 318)
    }
}
