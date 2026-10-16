// DesignFixturesTests.swift: the named fixtures (DesignFixtures) match the
// blueprint's Fixtures table (docs/blueprints/design.md section 4) layer for
// layer: name, kind, frame, parent, back-to-front order, Locked locked and
// Hidden hidden; `crowd` holds exactly 2,000 layers with unique ids; and every
// fixture saves to the same bytes after a reopen (QD-V1). Runs on Linux and macOS.
import DesignModel
import Testing

/// One layer as the table lists it: name, kind, frame, parent name ("" at the top), flags.
private struct Layer: Equatable {
    var name: String, kind: DesignNodeKind, frame: DesignRect, parent: String
    var locked = false, hidden = false
}

/// Every layer of `page` depth first, children back to front.
private func layers(_ page: DesignPage) -> [Layer] {
    func walk(_ nodes: [DesignNode], _ parent: String) -> [Layer] {
        nodes.flatMap { node in
            [Layer(name: node.name, kind: node.kind, frame: node.frame, parent: parent,
                   locked: node.isLocked, hidden: node.isHidden)] + walk(node.children, node.name)
        }
    }
    return walk(page.nodes, "")
}

private func allIDs(_ workspace: DesignWorkspace) -> [String] {
    func walk(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + walk($0.children) } }
    return workspace.pages.flatMap { [$0.id] + walk($0.nodes) }
}

private let cardsTable: [Layer] = [
    Layer(name: "Desktop", kind: .frame, frame: rc(0, 0, 1440, 1024), parent: ""),
    Layer(name: "A", kind: .rectangle, frame: rc(100, 100, 100, 80), parent: "Desktop"),
    Layer(name: "B", kind: .rectangle, frame: rc(300, 140, 200, 80), parent: "Desktop"),
    Layer(name: "C", kind: .rectangle, frame: rc(700, 100, 100, 120), parent: "Desktop"),
    Layer(name: "Title", kind: .text, frame: rc(100, 40, 200, 32), parent: "Desktop"),
    Layer(name: "Pair", kind: .group, frame: rc(900, 400, 300, 100), parent: "Desktop"),
    Layer(name: "E1", kind: .ellipse, frame: rc(900, 400, 100, 100), parent: "Pair"),
    Layer(name: "E2", kind: .ellipse, frame: rc(1100, 400, 100, 100), parent: "Pair"),
    Layer(name: "Locked", kind: .rectangle, frame: rc(400, 600, 100, 100), parent: "Desktop", locked: true),
    Layer(name: "Hidden", kind: .rectangle, frame: rc(600, 600, 100, 100), parent: "Desktop", hidden: true),
]

@Suite struct DesignFixturesTests {
    @Test func emptyIsNewFile() {
        let fixture = DesignFixtures.empty
        #expect(fixture.pages == openDesign().pages)
        #expect(fixture.pages.count == 1)
        #expect(fixture.pages.first.map(layers) == [
            Layer(name: "Desktop", kind: .frame, frame: rc(0, 0, 1440, 1024), parent: "")
        ])
    }

    @Test func cardsMatchesTheTable() throws {
        let fixture = DesignFixtures.cards
        #expect(fixture.pages.count == 1)
        let page = try #require(fixture.pages.first)
        #expect((page.frameWidth, page.frameHeight) == (1440, 1024))
        #expect(layers(page) == cardsTable)
        #expect(fixture.selectedPageID == page.id)
        #expect(fixture.documentURL == nil)
        #expect(!fixture.canUndo)
    }

    @Test func twoPagesIsCardsPlusMobile() throws {
        let fixture = DesignFixtures.twoPages
        #expect(fixture.pages.count == 2)
        #expect(fixture.pages.first.map(layers) == cardsTable)
        let mobile = try #require(fixture.pages.last)
        #expect(mobile.name == "Mobile")
        #expect((mobile.frameWidth, mobile.frameHeight) == (390, 844))
        #expect(layers(mobile) == [Layer(name: "Phone", kind: .frame, frame: rc(0, 0, 390, 844), parent: "")])
    }

    @Test func crowdHoldsTwoThousandLayers() throws {
        let fixture = DesignFixtures.crowd
        let page = try #require(fixture.pages.first)
        #expect(fixture.pages.count == 1)
        #expect(layers(page).count == 2_000)
        #expect(page.nodes.count == 40)
        for frame in page.nodes {
            #expect(frame.kind == .frame)
            #expect(frame.children.filter { $0.kind == .rectangle }.count == 48)
            #expect(frame.children.filter { $0.kind == .text }.count == 1)
            #expect(frame.children.count == 49)
            #expect(frame.children.allSatisfy { $0.children.isEmpty })
        }
        let ids = allIDs(fixture)
        #expect(Set(ids).count == ids.count)
    }

    @Test func idsAreUniqueAndMintPastThem() throws {
        for name in DesignFixtures.names {
            var fixture = try #require(DesignFixtures.named(name))
            let ids = allIDs(fixture)
            #expect(Set(ids).count == ids.count, "\(name)")
            fixture.addPage()
            let added = allIDs(fixture).filter { !ids.contains($0) }
            #expect(added.count == 2, "\(name): addPage mints a page and its Desktop frame")
        }
    }

    @Test func namedFindsEachFixture() {
        #expect(DesignFixtures.names == ["empty", "cards", "two-pages", "crowd"])
        #expect(DesignFixtures.named("cards")?.pages == DesignFixtures.cards.pages)
        #expect(DesignFixtures.named("two-pages")?.pages == DesignFixtures.twoPages.pages)
        #expect(DesignFixtures.named("crowd")?.pages == DesignFixtures.crowd.pages)
        #expect(DesignFixtures.named("empty")?.pages == DesignFixtures.empty.pages)
        #expect(DesignFixtures.named("twoPages") == nil)
    }

    /// QD-V1: encode(decode(encode(f))) == encode(f), byte for byte.
    @Test func roundTripIsStable() throws {
        for name in DesignFixtures.names {
            let fixture = try #require(DesignFixtures.named(name))
            let saved = try fixture.fileData()
            var reopened = DesignWorkspace()
            try reopened.open(saved)
            #expect(reopened.pages == fixture.pages, "\(name)")
            #expect(try reopened.fileData() == saved, "\(name)")
        }
    }
}
