// DesignSelectCommandTests.swift: edit.select takes its whole id list in one
// change (DesignWorkspace.select) and a refusal reaches the CLI and MCP as the
// help's plain words, naming the bad id, never a Swift case name like
// `unknownID("nope")` (#5838). A refused list changes nothing. Linux-safe.
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignSelectCommandTests {
    private static func select(_ ids: [String], on workspace: inout DesignWorkspace) throws {
        _ = try DesignWorkspace.catalog.run("edit.select", params: .object(["ids": .array(ids.map(JSONValue.string))]), on: &workspace)
    }

    @Test func anUnknownIDRefusesInPlainWords() {
        var workspace = DesignFixtures.cards
        workspace.selectItem("node-2")
        #expect(throws: CatalogError.failed(id: "edit.select", message: "nope isn't on this page.")) {
            try Self.select(["nope"], on: &workspace)
        }
        #expect(throws: CatalogError.failed(id: "edit.select", message: "nope isn't on this page.")) {
            try Self.select(["node-3", "nope"], on: &workspace)
        }
        #expect(workspace.selectedNodeIDs == ["node-2"])
    }

    @Test func aLockedHiddenOrRepeatedIDRefusesAndNamesIt() {
        var workspace = DesignFixtures.cards
        #expect(throws: CatalogError.failed(id: "edit.select", message: "Unlock Locked to change it.")) {
            try Self.select(["node-2", "node-9"], on: &workspace)
        }
        #expect(throws: CatalogError.failed(id: "edit.select", message: "Show Hidden to change it.")) {
            try Self.select(["node-2", "node-10"], on: &workspace)
        }
        #expect(throws: CatalogError.failed(id: "edit.select", message: "node-2 is listed twice.")) {
            try Self.select(["node-2", "node-3", "node-2"], on: &workspace)
        }
        #expect(workspace.selectedNodeIDs.isEmpty)
    }

    @Test func aListSelectsInOrderTheLastPrimaryAndShowsItsRows() throws {
        var workspace = DesignFixtures.cards
        try Self.select(["node-7", "node-2", "node-3"], on: &workspace)
        #expect(workspace.selectedNodeIDs == ["node-7", "node-2", "node-3"])
        #expect(workspace.selectedNodeID == "node-3")
        #expect(workspace.isExpanded("node-6"))
        // A lone locked layer is picked as a click picks it.
        try Self.select(["node-9"], on: &workspace)
        #expect(workspace.selectedNodeIDs == ["node-9"])
    }
}
