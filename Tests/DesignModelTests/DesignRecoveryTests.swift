// DesignRecoveryTests.swift: the Model walk of design/autosave-history (MJ-DA). The adapter in
// DesignRecovery+Kernel.swift puts the workspace on SuiteKernel's HistoryJumping: the listing
// starts at "Open" or "New Design", a jump lands on its step and records nothing, recovery bytes
// are the document as DesignFile writes it, and the recovered workspace is dirty and never saved.
// Runs on Linux and macOS.
import DesignModel
import SuiteKernel
import Testing

#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif

/// A new file with `count` rectangles added, one step each.
private func edited(_ count: Int) throws -> DesignWorkspace {
    var workspace = openDesign()
    for index in 0..<count {
        try workspace.addNode(.rectangle, frame: rc(Double(index) * 20, 0, 10, 10), in: "node-1")
    }
    return workspace
}

@Suite
struct DesignRecoveryTests {
    @Test func aNewFileListsNewDesign() throws {
        let listing = try edited(2).historyListing
        #expect(listing.base == "New Design")
        #expect(listing.steps.count == 2 && listing.index == 2)
    }

    @Test func jumpLandsOnIndex() throws {
        var workspace = try edited(12)
        let atTwo = try edited(2).pages
        try workspace.jumpHistory(to: 2)
        #expect(workspace.pages == atTwo)
        #expect(workspace.historyListing.index == 2)
    }

    @Test func jumpRecordsNothing() throws {
        var workspace = try edited(12)
        try workspace.jumpHistory(to: 2)
        #expect(workspace.historyListing.steps.count == 12)
        try workspace.jumpHistory(to: 12)
        #expect(workspace.pages == (try edited(12)).pages)
    }

    @Test func jumpOutOfRangeThrows() throws {
        var workspace = try edited(3)
        #expect(throws: (any Error).self) { try workspace.jumpHistory(to: 4) }
        #expect(throws: (any Error).self) { try workspace.jumpHistory(to: -1) }
    }

    @Test func recoveredIsDirty() throws {
        let workspace = try edited(3)
        let restored = try DesignWorkspace.recovered(from: workspace.recoveryBytes(), name: "card.design")
        #expect(restored.pages == workspace.pages)
        #expect(restored.isDirty)
        #expect(restored.documentURL == nil)
    }

    @Test func damagedBytesThrow() {
        #expect(throws: (any Error).self) { try DesignWorkspace.recovered(from: Data([0, 1, 2]), name: nil) }
    }

    @Test func restoreRecoveredPutsItInPlace() throws {
        let saved = try edited(2)
        var window = DesignWorkspace()
        try window.restoreRecovered(from: saved.recoveryBytes(), name: "card.design")
        #expect(window.pages == saved.pages)
        #expect(window.isDirty && window.documentURL == nil)
        #expect(throws: (any Error).self) { try window.restoreRecovered(from: Data([0, 1, 2]), name: nil) }
        #expect(window.pages == saved.pages)
    }

    @Test func nothingOpenHasNoBytes() {
        #expect(throws: (any Error).self) { try DesignWorkspace().recoveryBytes() }
    }
}
