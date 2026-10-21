// FlareRecoveryKernelTests.swift (adopt-kernel-autosave AK-3 written, AK-4 turned on; journey MJ-AK-flare): Flare's
// hooks on the suite's autosave. An edit, a schedule ticket, a write under `<support>/Flare/Recovery/` and a launch
// that restores the same document; a clean workspace has no encoder; a restore is one undo step; an old
// `Recovery.flare` moves under the root once and never over a newer copy. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import FlareCore
@testable import FlareModel
import SuiteKernel
import SuiteModel
import Testing

@Suite struct FlareRecoveryKernelTests {
    /// A fresh home folder per test (tests run in parallel) and the launch arguments that point the root into it.
    static func home() -> (home: String, arguments: [String]) {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent("FlareRecoveryKernelTests-\(UUID().uuidString)").path
        return (home, [SuiteLocations.supportDirFlag, home + "/support"])
    }

    /// Flare's recovery folder under the root, as the window builds it.
    static func folder(arguments: [String], home: String) -> RecoveryFolder {
        let store = FileStore(folder: SuiteLocations.appFolder("Flare", arguments: arguments, home: home))
        return RecoveryFolder(store: store, ext: FlareWorkspace.recoveryExtension)
    }

    /// A new document with one layer added: dirty, one step past the new document.
    static func edited() -> FlareWorkspace {
        var workspace = FlareWorkspace(services: .fake())
        workspace.newDocument()
        workspace.addLayer()
        return workspace
    }

    @Test func editTicketWriteThenLaunchRestores() throws {
        let (home, arguments) = Self.home()
        let workspace = Self.edited()
        #expect(workspace.isDirty)
        var schedule = AutosaveSchedule(delay: FlareWorkspace.autosaveDelay)
        schedule.noteEdit(at: 100)
        #expect(schedule.begin(now: 129, dirty: workspace.isDirty) == nil)
        let begun = schedule.begin(now: 130, dirty: workspace.isDirty)
        let ticket = try #require(begun)
        let made = workspace.recoveryEncoder()
        let encode = try #require(made)
        let folder = Self.folder(arguments: arguments, home: home)
        try folder.write(try encode(), window: workspace.recoveryWindow, name: nil, at: 130)
        #expect(schedule.finish(ticket, wrote: true) == .keep)
        let raw = home + "/support/Flare/Recovery/\(workspace.recoveryWindow).flare"
        #expect(FileManager.default.fileExists(atPath: raw))

        var relaunched = FlareWorkspace(services: .fake())
        let items = try folder.leftBehind()
        #expect(items.map(\.window) == [workspace.recoveryWindow])
        let item = try #require(items.first)
        try relaunched.restoreRecovery(item.data)
        #expect(relaunched.document == workspace.document)
        #expect(relaunched.isDirty)
        #expect(relaunched.fileName == nil)
    }

    @Test func cleanWritesNothing() throws {
        #expect(FlareWorkspace(services: .fake()).recoveryEncoder() == nil)
        var opened = FlareWorkspace(services: .fake())
        try opened.open(FlareFormat.encode(FlareFixtures.bounce), named: "Bounce.flare")
        #expect(opened.recoveryEncoder() == nil)
        var undone = Self.edited()
        #expect(undone.recoveryEncoder() != nil)
        undone.undo()
        #expect(undone.isDirty == false)
        #expect(undone.recoveryEncoder() == nil)
    }

    @Test func theEncoderCopiesTheDocumentWhenMade() throws {
        var workspace = Self.edited()
        let copied = workspace.document
        let made = workspace.recoveryEncoder()
        let encode = try #require(made)
        workspace.addLayer()
        #expect(try FlareFormat.decode(encode()) == copied)
    }

    @Test func restoreIsOneStep() throws {
        let made = Self.edited().recoveryEncoder()
        let encode = try #require(made)
        let data = try encode()
        var workspace = FlareWorkspace(services: .fake())
        try workspace.open(FlareFormat.encode(FlareFixtures.bounce), named: "Bounce.flare")
        let before = workspace.document
        try workspace.restoreRecovery(data)
        #expect(try workspace.document == FlareFormat.decode(data))
        #expect(workspace.isDirty && workspace.fileName == nil)
        #expect(workspace.undoActionName == "Undo Restore Autosaved Copy")
        #expect(workspace.canUndo)
        workspace.undo()
        #expect(workspace.document == before)
        #expect(workspace.canUndo == false)
    }

    @Test func damagedBytesThrowAndLeaveTheDocument() {
        var workspace = Self.edited()
        let before = workspace.document
        #expect(throws: (any Error).self) { try workspace.restoreRecovery(Data("not a flare file".utf8)) }
        #expect(workspace.document == before)
    }

    @Test func theWindowIdIsAFileName() {
        let window = FlareWorkspace(services: .fake()).recoveryWindow
        #expect(!window.isEmpty)
        #expect(!window.contains("/") && !window.hasPrefix("."))
        #expect(Self.edited().recoveryWindow == window)
    }

    @Test func anOldRecoveryFlareIsOfferedOnce() throws {
        let (home, arguments) = Self.home()
        let window = FlareWorkspace(services: .fake()).recoveryWindow
        let old = SuiteLocations.legacyFolder(FlareWorkspace.legacyRecovery, home: home)
        let new = SuiteLocations.appFolder("Flare", arguments: arguments, home: home)
            + "/Recovery/\(window).\(FlareWorkspace.recoveryExtension)"
        #expect(old == home + "/Library/Application Support/Flare/Recovery.flare")
        let exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }
        #expect(LegacySupport.plan(old: old, new: new, exists: exists) == .nothing)

        let bytes = try FlareFormat.encode(FlareFixtures.bounce)
        try FileManager.default.createDirectory(atPath: home + "/Library/Application Support/Flare",
                                                withIntermediateDirectories: true)
        #expect(FileManager.default.createFile(atPath: old, contents: bytes))
        #expect(LegacySupport.plan(old: old, new: new, exists: exists) == .move(from: old, to: new))
        let folder = Self.folder(arguments: arguments, home: home)
        try folder.write(bytes, window: window, name: nil, at: 1)
        try FileManager.default.removeItem(atPath: old)
        #expect(LegacySupport.plan(old: old, new: new, exists: exists) == .nothing)

        var relaunched = FlareWorkspace(services: .fake())
        let item = try #require(try folder.leftBehind().first)
        try relaunched.restoreRecovery(item.data)
        #expect(relaunched.document == FlareFixtures.bounce)

        #expect(FileManager.default.createFile(atPath: old, contents: Data("older".utf8)))
        #expect(LegacySupport.plan(old: old, new: new, exists: exists) == .keepBoth(old: old))
    }

    @Test func theWindowsFolderIsUnderTheRootAndOffWhenStateIsIgnored() throws {
        let (home, arguments) = Self.home()
        #expect(FlareWorkspace.recoveryFolder(arguments: [], home: home, ignoresState: true) == nil)
        #expect(FlareWorkspace.recoveryFolder(arguments: [SuiteLocations.supportDirFlag, ""], home: home,
                                              ignoresState: true) == nil)
        #expect(FlareWorkspace.recoveryFolder(arguments: arguments, home: home, ignoresState: true) != nil)
        let made = FlareWorkspace.recoveryFolder(arguments: arguments, home: home, ignoresState: false)
        let folder = try #require(made)
        try folder.write(Data("bytes".utf8), window: FlareWorkspace.mainWindow, name: "Bounce.flare", at: 5)
        #expect(FileManager.default.fileExists(atPath: home + "/support/Flare/Recovery/flare.main.flare"))
        #expect(try Self.folder(arguments: arguments, home: home).leftBehind().map(\.name) == ["Bounce.flare"])
    }

    @Test func theLegacyMoveRunsOnceAndNeverOverANewerCopy() throws {
        let (home, arguments) = Self.home()
        let folder = Self.folder(arguments: arguments, home: home)
        let move = { FlareWorkspace.moveLegacyRecovery(into: folder, arguments: arguments, home: home) }
        #expect(move() == .nothing)
        let old = SuiteLocations.legacyFolder(FlareWorkspace.legacyRecovery, home: home)
        try FileManager.default.createDirectory(atPath: home + "/Library/Application Support/Flare",
                                                withIntermediateDirectories: true)
        let bytes = try FlareFormat.encode(FlareFixtures.bounce)
        #expect(FileManager.default.createFile(atPath: old, contents: bytes))
        let step = move()
        guard case .move = step else { Issue.record("expected a move, got \(step)"); return }
        #expect(!FileManager.default.fileExists(atPath: old))
        let items = try folder.leftBehind()
        #expect(items.map(\.window) == [FlareWorkspace.mainWindow])
        #expect(items.map(\.data) == [bytes])
        #expect(items.allSatisfy { $0.savedAt > 0 })
        #expect(move() == .nothing)

        #expect(FileManager.default.createFile(atPath: old, contents: Data("older".utf8)))
        #expect(move() == .keepBoth(old: old))
        #expect(FileManager.default.fileExists(atPath: old))
        #expect(try folder.leftBehind().map(\.data) == [bytes])
    }

    @Test func anUnreadableOldCopyStaysAndIsNotAMove() throws {
        let (home, arguments) = Self.home()
        let old = SuiteLocations.legacyFolder(FlareWorkspace.legacyRecovery, home: home)
        try FileManager.default.createDirectory(atPath: old, withIntermediateDirectories: true)
        let folder = Self.folder(arguments: arguments, home: home)
        #expect(FlareWorkspace.moveLegacyRecovery(into: folder, arguments: arguments, home: home)
            == .keepBoth(old: old))
        #expect(FileManager.default.fileExists(atPath: old))
        #expect(try folder.leftBehind().isEmpty)
    }

    @Test func aLaunchWithRecoveryOffLeavesTheOldCopy() throws {
        let (home, arguments) = Self.home()
        let old = SuiteLocations.legacyFolder(FlareWorkspace.legacyRecovery, home: home)
        try FileManager.default.createDirectory(atPath: home + "/Library/Application Support/Flare",
                                                withIntermediateDirectories: true)
        #expect(FileManager.default.createFile(atPath: old, contents: try FlareFormat.encode(FlareFixtures.bounce)))
        #expect(FlareWorkspace.launchRecoveryFolder(arguments: [], home: home, ignoresState: true) == nil)
        #expect(FileManager.default.fileExists(atPath: old))
        #expect(FlareWorkspace.launchRecoveryFolder(arguments: arguments, home: home, ignoresState: true) != nil)
        #expect(try FileManager.default.fileExists(atPath: old) && Self.folder(arguments: arguments, home: home).leftBehind().isEmpty)
        #expect(FlareWorkspace.launchRecoveryFolder(arguments: arguments, home: home, ignoresState: false) != nil)
        #expect(!FileManager.default.fileExists(atPath: old))
    }

    @Test func aDirtyQuitWritesTheDocumentAndACleanOneNothing() throws {
        let (home, arguments) = Self.home()
        let folder = Self.folder(arguments: arguments, home: home)
        var clean = FlareWorkspace(services: .fake())
        try clean.open(FlareFormat.encode(FlareFixtures.bounce), named: "Bounce.flare")
        #expect(clean.writeRecoveryOnQuit(to: folder, at: 7) == false)
        #expect(try folder.leftBehind().isEmpty)

        let dirty = Self.edited()
        #expect(dirty.writeRecoveryOnQuit(to: folder, at: 9))
        #expect(FileManager.default.fileExists(atPath: home + "/support/Flare/Recovery/flare.main.flare"))
        #expect(FileManager.default.fileExists(atPath: home + "/support/Flare/Recovery/flare.main.json"))
        let items = try folder.leftBehind()
        #expect(items.map(\.window) == [FlareWorkspace.mainWindow])
        let item = try #require(items.first)
        #expect(item.savedAt == 9)
        var relaunched = FlareWorkspace(services: .fake())
        try relaunched.restoreRecovery(item.data)
        #expect(relaunched.document == dirty.document)
    }
}
