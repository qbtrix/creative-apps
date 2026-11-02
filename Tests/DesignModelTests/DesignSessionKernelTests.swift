// DesignSessionKernelTests.swift: Design's session adapter onto SuiteKernel
// (DesignSession+Kernel.swift): the workspace's dirty state is the kernel
// session's through edit, save, undo and redo; a save sets the saved token and
// ends the edit run; and the file's version is read through the kernel's probe,
// a file with no version refused as unreadable. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import Testing

@Suite struct DesignSessionKernelTests {
    private let savedURL = URL(fileURLWithPath: "/tmp/Session.design")

    /// The workspace and its kernel session agree on dirty.
    private func agree(_ workspace: DesignWorkspace) {
        #expect(workspace.isDirty == workspace.documentSession.isDirty)
    }

    @Test func nothingOpenIsACleanSession() {
        let session = DesignWorkspace().documentSession
        #expect(!session.isDirty)
        #expect(session.status == .unsaved)
    }

    @Test func dirtyFollowsTheSessionThroughEditSaveUndoAndRedo() throws {
        var workspace = openDesign()
        agree(workspace)
        try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
        #expect(workspace.documentSession.isDirty)
        agree(workspace)
        workspace.didSave(to: savedURL)
        #expect(!workspace.documentSession.isDirty)
        #expect(workspace.documentSession.status == .saved)
        agree(workspace)
        workspace.undo()
        #expect(workspace.documentSession.isDirty)
        agree(workspace)
        workspace.redo()
        #expect(!workspace.documentSession.isDirty)
        agree(workspace)
    }

    @Test func aSaveSetsTheSavedTokenToTheCurrentStep() throws {
        var workspace = openDesign()
        try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
        let current = workspace.documentSession.currentToken
        #expect(workspace.documentSession.savedToken != current)
        workspace.didSave(to: savedURL)
        #expect(workspace.documentSession.savedToken == current)
        #expect(workspace.documentURL == savedURL)
    }

    @Test func aSaveEndsTheRunSoUndoLandsOnTheSavedDocument() throws {
        var workspace = openDesign()
        let id = try workspace.addNode(.rectangle, frame: rc(0, 0, 10, 10), in: "node-1")
        workspace.selectItem(id)
        workspace.nudge(.right, shift: false)
        workspace.didSave(to: savedURL)
        workspace.nudge(.right, shift: false)
        #expect(workspace.documentSession.isDirty)
        workspace.undo()
        #expect(workspace.frame(id) == rc(1, 0, 10, 10))
        #expect(!workspace.documentSession.isDirty)
    }

    /// The bytes of a valid file with its `"version"` entry replaced by `version`.
    private func file(version: String) throws -> Data {
        let data = try LiveFiling().encode(DesignDocument(pages: openDesign().pages))
        let text = String(decoding: data, as: UTF8.self)
        #expect(text.hasSuffix(",\"version\":1}"))
        return Data((String(text.dropLast(",\"version\":1}".count)) + version + "}").utf8)
    }

    @Test func aFileWithNoVersionIsUnreadable() throws {
        #expect(throws: DesignFileError.unreadable) { try LiveFiling().decode(try file(version: "")) }
        #expect(throws: DesignFileError.unreadable) { try LiveFiling().decode(try file(version: ",\"version\":\"1\"")) }
    }

    @Test func aNewerFileIsRefusedWithItsVersion() throws {
        #expect(throws: DesignFileError.unsupportedVersion(3)) {
            try LiveFiling().decode(try file(version: ",\"version\":3"))
        }
        #expect(throws: DesignFileError.unreadable) { try LiveFiling.probeVersion(Data("[]".utf8)) }
        #expect(try LiveFiling.probeVersion(try file(version: ",\"version\":1")) == 1)
        #expect(try LiveFiling().decode(try file(version: ",\"version\":1")).pages == openDesign().pages)
    }
}
