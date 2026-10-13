// DesignIDCrossKindTests.swift: page and node ids share one namespace in a file, so
// a minted page id never repeats a node's and a minted node id never repeats a
// page's, and Save still works after Add Page or Add Node (#303). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import Testing

/// New File's "page-1" holding "node-1", saved with `old` renamed to `new` and reopened.
private func openRenamed(_ old: String, to new: String) throws -> DesignWorkspace {
    var source = DesignWorkspace()
    source.newFile()
    let json = String(decoding: try source.fileData(), as: UTF8.self)
        .replacingOccurrences(of: "\"\(old)\"", with: "\"\(new)\"")
    var workspace = DesignWorkspace()
    try workspace.open(Data(json.utf8))
    return workspace
}

@Test func addNodeSkipsAnIDAPageHolds() throws {
    var workspace = try openRenamed("page-1", to: "node-2")
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10))
    #expect(id == "node-3")
    workspace.addPage()
    #expect(workspace.pages.map(\.id) == ["node-2", "page-1"])
    #expect(workspace.pages.last?.nodes.map(\.id) == ["node-4"])
    _ = try workspace.fileData()
}

@Test func addPageSkipsANodeIDAPageWouldTake() throws {
    var workspace = try openRenamed("page-1", to: "node-2")
    workspace.addPage()
    #expect(workspace.pages.last?.nodes.map(\.id) == ["node-3"])
    _ = try workspace.fileData()
}

@Test func addPageSkipsAnIDANodeHolds() throws {
    var workspace = try openRenamed("node-1", to: "page-2")
    workspace.addPage()
    #expect(workspace.pages.map(\.id) == ["page-1", "page-3"])
    let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10))
    #expect(id != "page-2" && id != "page-3")
    _ = try workspace.fileData()
}
