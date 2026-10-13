// DesignIDCapTests.swift: a file whose ids sit at the 1e9 cap the load counters
// ignore. A minted page or node id never repeats one the document holds, so
// Save still works after an edit (#296). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

private func allNodeIDs(_ workspace: DesignWorkspace) -> [String] {
    func ids(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + ids($0.children) } }
    return workspace.pages.flatMap { ids($0.nodes) }
}

/// A saved file with "node-999999999" and "node-1000000000", reopened.
private func openNearTheCap() throws -> DesignWorkspace {
    var source = DesignWorkspace()
    source.newFile()
    source.addPage()
    let json = String(decoding: try source.fileData(), as: UTF8.self)
        .replacingOccurrences(of: "\"node-1\"", with: "\"node-999999999\"")
        .replacingOccurrences(of: "\"node-2\"", with: "\"node-1000000000\"")
    var workspace = DesignWorkspace()
    try workspace.open(Data(json.utf8))
    return workspace
}

@Test func addPageNearTheCapMintsAnUnusedNodeIDAndSaves() throws {
    var workspace = try openNearTheCap()
    workspace.addPage()
    let ids = allNodeIDs(workspace)
    #expect(ids.count == 3 && Set(ids).count == 3)
    #expect(workspace.pages.last?.nodes.map(\.id) == ["node-1000000001"])
    _ = try workspace.fileData()
}

@Test func addNodeNearTheCapMintsAnUnusedNodeIDAndSaves() throws {
    var workspace = try openNearTheCap()
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10))
    #expect(id == "node-1000000001")
    #expect(Set(allNodeIDs(workspace)).count == 3)
    _ = try workspace.fileData()
}

@Test func addPageSkipsAPageIDPastTheCap() throws {
    var workspace = DesignWorkspace()
    workspace.load([
        DesignPage(id: "page-999999999", name: "A", frameWidth: 800, frameHeight: 600),
        DesignPage(id: "page-1000000000", name: "B", frameWidth: 800, frameHeight: 600),
    ])
    workspace.addPage()
    #expect(workspace.pages.map(\.id) == ["page-999999999", "page-1000000000", "page-1000000001"])
    _ = try workspace.fileData()
}

@Test func newFileOverAnOpenFileStillStartsAtOne() throws {
    var workspace = try openNearTheCap()
    workspace.newFile()
    #expect(workspace.pages.map(\.id) == ["page-1"])
    #expect(allNodeIDs(workspace) == ["node-1"])
}
