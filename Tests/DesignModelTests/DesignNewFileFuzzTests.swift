// DesignNewFileFuzzTests.swift: adversarial and seeded-fuzz checks on
// newFile(), which File > New File (⌘N) calls on the focused window. Whatever
// was edited before, New File leaves exactly the document a first New File
// makes, and pressing it again changes nothing in that document. Runs on
// Linux and macOS.
import DesignModel
import Testing

private let box = DesignRect(x: 0, y: 0, width: 10, height: 10)

/// The document part of a workspace: what New File must reset.
private struct Document: Equatable {
    let pages: [DesignPage]
    let selectedPageID: String?
    let selectedNodeID: String?
    let expandedNodeIDs: Set<String>
    let layerRows: [DesignRow]

    init(_ workspace: DesignWorkspace) {
        pages = workspace.pages
        selectedPageID = workspace.selectedPageID
        selectedNodeID = workspace.selectedNodeID
        expandedNodeIDs = workspace.expandedNodeIDs
        layerRows = workspace.layerRows
    }
}

private func freshDocument() -> Document {
    var workspace = DesignWorkspace()
    workspace.newFile()
    return Document(workspace)
}

@Test func newFileFromNoFileOpensOneDesktopPage() {
    var workspace = DesignWorkspace()
    #expect(!workspace.isOpen)
    workspace.newFile()
    #expect(workspace.isOpen)
    #expect(workspace.pages.map(\.id) == ["page-1"])
    #expect(workspace.selectedPage?.nodes.map(\.name) == ["Desktop"])
    #expect(!workspace.canDeletePage)
}

@Test func pressingNewFileRepeatedlyKeepsTheSameDocument() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    let first = Document(workspace)
    for _ in 0..<20 {
        workspace.newFile()
        #expect(Document(workspace) == first)
    }
}

@Test func newFileRestartsIDsSoTheNextAddsMatchAFreshFile() throws {
    var edited = DesignWorkspace()
    edited.newFile()
    for _ in 0..<5 { edited.addPage() }
    for _ in 0..<5 { try edited.addNode(.rectangle, frame: box) }
    edited.newFile()
    edited.addPage()
    let node = try edited.addNode(.text, frame: box)

    var fresh = DesignWorkspace()
    fresh.newFile()
    fresh.addPage()
    #expect(try fresh.addNode(.text, frame: box) == node)
    #expect(Document(edited) == Document(fresh))
}

@Test func aPageDeletedBeforeNewFileCannotBeRestoredIntoTheNewFile() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    let deleted = try workspace.deletePage("page-2")
    workspace.newFile()
    workspace.addPage()
    // The new file has its own page-2; the old one must not come back next to it.
    let before = workspace
    #expect(throws: DesignTreeError.self) { try workspace.restorePage(deleted) }
    #expect(workspace == before)
}

@Test(arguments: [3, 17, 99, 512, 2026] as [UInt64])
func seededEditsThenNewFileGiveAFreshDocument(seed: UInt64) {
    var state = seed
    func roll(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(Swift.max(bound, 1)))
    }
    let fresh = freshDocument()
    var workspace = DesignWorkspace()
    workspace.newFile()
    for _ in 0..<400 {
        let ids = workspace.pages.flatMap { page in [page.id] + page.nodes.map(\.id) }
        let id = ids.isEmpty ? "node-1" : ids[roll(ids.count)]
        switch roll(9) {
        case 0: workspace.addPage()
        case 1: _ = try? workspace.addNode(DesignNodeKind.allCases[roll(DesignNodeKind.allCases.count)], frame: box)
        case 2: workspace.selectItem(id)
        case 3: _ = try? workspace.toggleExpanded(id)
        case 4: _ = try? workspace.setNodeHidden(id, roll(2) == 0)
        case 5: _ = try? workspace.renamePage(id, to: "Renamed")
        case 6: if let page = workspace.selectedPageID { _ = try? workspace.deletePage(page) }
        case 7: workspace.selectTool(DesignTool.allCases[roll(DesignTool.allCases.count)])
        default:
            workspace.newFile()
            #expect(Document(workspace) == fresh)
        }
        #expect(workspace.isOpen)
    }
    workspace.newFile()
    #expect(Document(workspace) == fresh)
}
