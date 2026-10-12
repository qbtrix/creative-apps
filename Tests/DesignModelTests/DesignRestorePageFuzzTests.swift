// DesignRestorePageFuzzTests.swift: adversarial and seeded-fuzz checks on
// deletePage and restorePage, driven the way the window's undo stack drives
// them: undo restores the newest delete, redo deletes the same page again, and
// a new delete drops the redo stack. Runs on Linux and macOS.
import DesignModel
import Testing

/// A seeded linear congruential generator, so a failing seed replays.
private struct Lcg {
    var state: UInt64

    mutating func below(_ bound: Int) -> Int {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        return Int((state >> 33) % UInt64(bound))
    }
}

/// Every node id on every page, nested ones included.
private func nodeIDs(_ workspace: DesignWorkspace) -> [String] {
    func walk(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + walk($0.children) } }
    return workspace.pages.flatMap { walk($0.nodes) }
}

/// The workspace invariants: a page is open and selected, ids are unique, and a selected node is on the selected page.
private func checkInvariants(_ workspace: DesignWorkspace) {
    #expect(workspace.isOpen)
    #expect(workspace.selectedPage != nil)
    #expect(Set(workspace.pages.map(\.id)).count == workspace.pages.count)
    let ids = nodeIDs(workspace)
    #expect(Set(ids).count == ids.count)
    if workspace.selectedNodeID != nil { #expect(workspace.selectedNode != nil) }
}

/// Five pages, each holding a frame with a rectangle inside.
private func fivePages() throws -> DesignWorkspace {
    var workspace = DesignWorkspace()
    workspace.newFile()
    for _ in 0..<4 {
        workspace.addPage()
        let frame = try workspace.addNode(.frame, frame: DesignRect(x: 0, y: 0, width: 10, height: 10))
        try workspace.addNode(.rectangle, frame: DesignRect(x: 1, y: 1, width: 2, height: 2), in: frame)
    }
    return workspace
}

@Test func deletingEveryPageButOneThenUndoingAllGivesBackTheFile() throws {
    let start = try fivePages()
    var workspace = start
    var undo: [DeletedPage] = []
    while workspace.canDeletePage, let id = workspace.selectedPageID {
        undo.append(try workspace.deletePage(id))
    }
    #expect(workspace.pages.count == 1)
    while let deleted = undo.popLast() { try workspace.restorePage(deleted) }
    #expect(workspace == start)
}

@Test func restoringTheFirstPageAfterDeletingItPutsItFirst() throws {
    var workspace = try fivePages()
    workspace.selectPage("page-1")
    let before = workspace
    let deleted = try workspace.deletePage("page-1")
    #expect(workspace.selectedPageID == "page-2")
    try workspace.restorePage(deleted)
    #expect(workspace == before)
    #expect(workspace.pages.first?.id == "page-1")
}

@Test func restoringAfterAddingPagesKeepsTheDeletedIndex() throws {
    var workspace = try fivePages()
    workspace.selectPage("page-2")
    let deleted = try workspace.deletePage("page-2")
    workspace.addPage()
    workspace.addPage()
    try workspace.restorePage(deleted)
    #expect(workspace.pages.map(\.id) == ["page-1", "page-2", "page-3", "page-4", "page-5", "page-6", "page-7"])
    #expect(workspace.selectedPageID == "page-2")
    checkInvariants(workspace)
}

@Test func restoringWithNoFileOpenIsRefused() throws {
    var source = try fivePages()
    let deleted = try source.deletePage("page-3")
    var empty = DesignWorkspace()
    #expect(throws: DesignTreeError.unknownID("page-3")) { try empty.restorePage(deleted) }
    #expect(empty == DesignWorkspace())
}

@Test func seededUndoRedoOfDeletesReplaysExactly() throws {
    for seed in UInt64(1)...200 {
        var rng = Lcg(state: seed)
        var workspace = try fivePages()
        // Each undo entry keeps the state before the delete; each redo entry the state after it.
        var undo: [(deleted: DeletedPage, before: DesignWorkspace)] = []
        var redo: [(id: String, after: DesignWorkspace)] = []
        for _ in 0..<40 {
            switch rng.below(4) {
            case 0 where workspace.canDeletePage:
                guard let id = workspace.selectedPageID else { continue }
                let before = workspace
                undo.append((try workspace.deletePage(id), before))
                redo.removeAll()
            case 1:
                guard let entry = undo.popLast() else { continue }
                let after = workspace
                try workspace.restorePage(entry.deleted)
                #expect(workspace == entry.before, "seed \(seed)")
                redo.append((entry.deleted.page.id, after))
            case 2:
                guard let entry = redo.popLast() else { continue }
                let before = workspace
                undo.append((try workspace.deletePage(entry.id), before))
                // A selection made since the undo stays, so only the pages must match.
                #expect(workspace.pages == entry.after.pages, "seed \(seed)")
            default:
                workspace.selectPage(workspace.pages[rng.below(workspace.pages.count)].id)
            }
            checkInvariants(workspace)
        }
    }
}

@Test func seededDeletesMixedWithEditsAlwaysRestore() throws {
    for seed in UInt64(1)...200 {
        var rng = Lcg(state: seed)
        var workspace = try fivePages()
        var undo: [DeletedPage] = []
        for _ in 0..<60 {
            switch rng.below(5) {
            case 0 where workspace.canDeletePage:
                guard let id = workspace.selectedPageID else { continue }
                undo.append(try workspace.deletePage(id))
            case 1:
                guard let deleted = undo.popLast() else { continue }
                try workspace.restorePage(deleted)
                #expect(workspace.pages.contains { $0.id == deleted.page.id }, "seed \(seed)")
            case 2:
                workspace.addPage()
            case 3:
                try workspace.addNode(.text, frame: DesignRect(x: 0, y: 0, width: 1, height: 1))
            default:
                let ids = workspace.pages.map(\.id) + nodeIDs(workspace)
                if !ids.isEmpty { workspace.selectItem(ids[rng.below(ids.count)]) }
            }
            checkInvariants(workspace)
        }
        while let deleted = undo.popLast() { try workspace.restorePage(deleted) }
        checkInvariants(workspace)
    }
}
