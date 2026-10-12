// DesignDeletePageEdgeTests.swift: adversarial and seeded-fuzz checks on
// canDeletePage, the query behind Page > Delete Page. Whenever it holds,
// deleting the selected page succeeds; whenever it does not, the delete is
// refused and changes nothing. Runs on Linux and macOS.
import DesignModel
import Testing

private let box = DesignRect(x: 0, y: 0, width: 10, height: 10)

/// Tries the menu's delete on the selected page; returns whether it was accepted.
private func deleteSelected(_ workspace: inout DesignWorkspace) -> Bool {
    guard let id = workspace.selectedPageID else { return false }
    do {
        try workspace.deletePage(id)
        return true
    } catch {
        return false
    }
}

@Test func canDeletePageMatchesWhetherTheDeleteIsAccepted() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    for _ in 0..<4 { workspace.addPage() }
    while workspace.canDeletePage {
        let count = workspace.pages.count
        #expect(deleteSelected(&workspace))
        #expect(workspace.pages.count == count - 1)
    }
    let before = workspace
    #expect(workspace.pages.count == 1)
    #expect(!deleteSelected(&workspace))
    #expect(workspace == before)
}

@Test func deletingAnotherPageDownToOneDisablesDelete() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    workspace.selectPage("page-1")
    #expect(workspace.canDeletePage)
    try workspace.deletePage("page-2")
    #expect(workspace.selectedPageID == "page-1")
    #expect(!workspace.canDeletePage)
}

@Test func aSelectedLayerStillAllowsDeletingItsPage() throws {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    let node = try workspace.addNode(.rectangle, frame: box)
    #expect(workspace.selectedNodeID == node)
    #expect(workspace.canDeletePage)
    #expect(deleteSelected(&workspace))
    #expect(workspace.selectedPageID == "page-1")
    #expect(workspace.selectedNodeID == nil)
    #expect(!workspace.canDeletePage)
}

@Test func selectingALayerOnAnotherPageKeepsDeleteAvailable() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    workspace.addPage()
    workspace.selectItem("node-1")
    #expect(workspace.selectedPageID == "page-1")
    #expect(workspace.canDeletePage)
}

@Test func aNewFileResetsDeleteToUnavailable() {
    var workspace = DesignWorkspace()
    workspace.newFile()
    for _ in 0..<3 { workspace.addPage() }
    #expect(workspace.canDeletePage)
    workspace.newFile()
    #expect(workspace.pages.count == 1)
    #expect(!workspace.canDeletePage)
}

@Test(arguments: [1, 7, 42, 2026, 9001] as [UInt64])
func seededPageEditsKeepCanDeletePageHonest(seed: UInt64) {
    var state = seed
    func roll(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
    var workspace = DesignWorkspace()
    for _ in 0..<300 {
        switch roll(5) {
        case 0: workspace.newFile()
        case 1, 2: workspace.addPage()
        case 3:
            if let page = workspace.pages[safe: roll(Swift.max(workspace.pages.count, 1))] {
                workspace.selectPage(page.id)
            }
        default:
            let allowed = workspace.canDeletePage
            let before = workspace
            #expect(deleteSelected(&workspace) == allowed)
            if !allowed { #expect(workspace == before) }
        }
        #expect(workspace.canDeletePage == (workspace.selectedPage != nil && workspace.pages.count > 1))
        #expect(workspace.isOpen == (workspace.selectedPage != nil))
    }
}

extension Array {
    fileprivate subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
