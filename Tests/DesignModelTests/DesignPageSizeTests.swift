// DesignPageSizeTests.swift: the page's size (canvas-basics CB-8). setPageSize
// is one "Change Page Size" step that clamps each side to 1...100,000 and
// leaves the layers where they are; a non-finite or unchanged size records
// nothing. contentBounds is the union of the visible layers' frames, and
// isPastEdge says whether a layer reaches past the page. Runs on Linux and macOS.
import DesignModel
import Testing

private func cardsPage(_ workspace: DesignWorkspace = DesignFixtures.cards) -> DesignPage? {
    workspace.selectedPage
}

/// The cards page with Desktop's children lifted to the top level, so a hidden or nested
/// layer can reach past the others.
private func liftedCards(_ change: (inout [DesignNode]) -> Void) -> DesignPage {
    var nodes = cardsPage()?.nodes.first?.children ?? []
    change(&nodes)
    return DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: nodes)
}

@Test func aNewSizeIsOneStepAndTheLayersStayPut() {
    var workspace = DesignFixtures.cards
    let desktop = workspace.frame("node-1")
    workspace.setPageSize(width: 800, height: 1024)
    #expect(cardsPage(workspace)?.sizeText == "800 × 1024 pt")
    #expect(workspace.undoActionName == "Undo Change Page Size")
    #expect(workspace.frame("node-1") == desktop)
    #expect(workspace.frame("node-1") == rc(0, 0, 1440, 1024))
    workspace.undo()
    #expect(cardsPage(workspace)?.sizeText == "1440 × 1024 pt")
    #expect(!workspace.canUndo)
}

@Test func eachSideClampsToOneThroughAHundredThousand() {
    var workspace = DesignFixtures.cards
    workspace.setPageSize(width: 0, height: -5)
    #expect(cardsPage(workspace)?.frameWidth == 1)
    #expect(cardsPage(workspace)?.frameHeight == 1)
    workspace.setPageSize(width: 200_000, height: 300)
    #expect(cardsPage(workspace)?.frameWidth == 100_000)
    #expect(cardsPage(workspace)?.frameHeight == 300)
}

@Test func aNonFiniteOrUnchangedSizeRecordsNothing() {
    var workspace = DesignFixtures.cards
    workspace.setPageSize(width: .nan, height: 500)
    workspace.setPageSize(width: 500, height: .infinity)
    workspace.setPageSize(width: 1440, height: 1024)
    #expect(cardsPage(workspace)?.sizeText == "1440 × 1024 pt")
    #expect(!workspace.canUndo)
    #expect(workspace == DesignFixtures.cards)
}

@Test func anUnchangedSizeLeavesAnOpenTextEditOpen() throws {
    var workspace = DesignFixtures.cards
    try workspace.beginTextEdit("node-5")
    workspace.setTextDraft("Heading")
    workspace.setPageSize(width: 1440, height: 1024)
    #expect(workspace.editingTextID == "node-5")
    #expect(workspace.textDraft == "Heading")
    #expect(workspace.undoActionName == "Undo")
    workspace.setPageSize(width: 1000, height: 1024)
    #expect(workspace.editingTextID == nil)
    #expect(workspace.undoActionName == "Undo Change Page Size")
}

@Test func withNoFileNothingHappens() {
    var workspace = DesignWorkspace()
    workspace.setPageSize(width: 800, height: 600)
    #expect(workspace == DesignWorkspace())
}

@Test func contentBoundsIsTheVisibleLayersUnion() {
    #expect(cardsPage()?.contentBounds == rc(0, 0, 1440, 1024))
    #expect(DesignPage(id: "page-9", name: "Empty", frameWidth: 10, frameHeight: 10).contentBounds == nil)
    // Hidden (node-10) moved far out must not count; Locked does.
    let hiddenOut = liftedCards { nodes in
        for index in nodes.indices where nodes[index].id == "node-10" { nodes[index].frame = rc(3000, 3000, 10, 10) }
    }
    #expect(hiddenOut.contentBounds == rc(100, 40, 1100, 660))
    // Pair's child E2 (node-8) moved past Pair's own frame counts.
    let childOut = liftedCards { nodes in
        for index in nodes.indices where nodes[index].id == "node-6" {
            for child in nodes[index].children.indices where nodes[index].children[child].id == "node-8" {
                nodes[index].children[child].frame = rc(1300, 400, 100, 900)
            }
        }
    }
    #expect(childOut.contentBounds == rc(100, 40, 1300, 1260))
    let onlyHidden = DesignPage(
        id: "page-9", name: "Hidden", frameWidth: 10, frameHeight: 10,
        nodes: [DesignNode(id: "node-1", name: "H", kind: .rectangle, frame: rc(0, 0, 5, 5), isHidden: true)])
    #expect(onlyHidden.contentBounds == nil)
}

@Test func aLayerPastTheEdgeIsFlagged() throws {
    var workspace = DesignFixtures.cards
    let page = try #require(cardsPage(workspace))
    let outside = DesignNode(id: "node-99", name: "Out", kind: .rectangle, frame: rc(-264, -594, 100, 100))
    #expect(page.isPastEdge(outside))
    let a = try #require(workspace.treeNode("node-2"))
    #expect(!page.isPastEdge(a))
    let desktop = try #require(workspace.treeNode("node-1"))
    #expect(!page.isPastEdge(desktop))
    workspace.setPageSize(width: 800, height: 1024)
    let narrow = try #require(cardsPage(workspace))
    #expect(narrow.isPastEdge(desktop))
    #expect(!narrow.isPastEdge(a))
}

/// contentBounds is DesignRect.union of the visible frames (#3341): nested visible layers count,
/// a hidden group's children don't, and the union takes the true min and max on each side.
@Test func contentBoundsIsTheCanonicalUnion() {
    let nested = DesignNode(
        id: "node-1", name: "F", kind: .frame, frame: rc(10, 20, 100, 100),
        children: [DesignNode(id: "node-2", name: "In", kind: .ellipse, frame: rc(-30, 50, 20, 200))])
    let hidden = DesignNode(
        id: "node-3", name: "G", kind: .group, frame: rc(500, 500, 10, 10),
        children: [DesignNode(id: "node-4", name: "Far", kind: .rectangle, frame: rc(-900, -900, 5, 5))],
        isHidden: true)
    let tail = DesignNode(id: "node-5", name: "R", kind: .rectangle, frame: rc(200, -40, 60, 30))
    let page = DesignPage(id: "page-9", name: "P", frameWidth: 100, frameHeight: 100, nodes: [nested, hidden, tail])
    let visible = [rc(10, 20, 100, 100), rc(-30, 50, 20, 200), rc(200, -40, 60, 30)]
    #expect(page.contentBounds == DesignRect.union(visible))
    #expect(page.contentBounds == rc(-30, -40, 290, 290))
    #expect(DesignRect.union([]) == nil)
}
