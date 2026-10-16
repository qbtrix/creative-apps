// PhotoRecoveryTests.swift: the Model side of autosave recovery (PV-1, D-4a):
// when an autosave is due, the recovery entry of a dirty image, restoring one
// as an untitled-or-named dirty image, and the restore offer's text. One
// FakeArchive (lossless) encodes and decodes each round trip. Runs on Linux
// and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoRecoveryTests {
    /// A 4 x 3 white PNG through RawCodec, opened as `name`, clean.
    private func openedImage(_ name: String = "beach.png") throws -> PhotoWorkspace {
        let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.openImage(try RawCodec().encode(white, as: .png, quality: 1), name: name, codec: RawCodec())
        return workspace
    }

    /// The opened image with a second layer added: two layers, dirty.
    private func editedImage(_ name: String = "beach.png") throws -> PhotoWorkspace {
        var workspace = try openedImage(name)
        workspace.addLayer()
        return workspace
    }

    @Test func theDelayIsFiveSeconds() {
        #expect(PhotoWorkspace.autosaveDelay == 5)
    }

    @Test func dueAtExactlyTheDelayAfterTheLastEditAndNotBefore() throws {
        let workspace = try editedImage()
        #expect(!workspace.autosaveDue(lastEdit: 100, lastAutosave: nil, now: 104.999))
        #expect(workspace.autosaveDue(lastEdit: 100, lastAutosave: nil, now: 105))
        #expect(workspace.autosaveDue(lastEdit: 100, lastAutosave: nil, now: 200))
        #expect(!workspace.autosaveDue(lastEdit: 100, lastAutosave: nil, now: 101, delay: 2))
        #expect(workspace.autosaveDue(lastEdit: 100, lastAutosave: nil, now: 102, delay: 2))
    }

    @Test func notDueWhenCleanOrAlreadyAutosaved() throws {
        #expect(!(try openedImage()).autosaveDue(lastEdit: 100, lastAutosave: nil, now: 200))
        #expect(!PhotoWorkspace().autosaveDue(lastEdit: 100, lastAutosave: nil, now: 200))
        let workspace = try editedImage()
        #expect(!workspace.autosaveDue(lastEdit: 100, lastAutosave: 105, now: 200))
        #expect(!workspace.autosaveDue(lastEdit: 100, lastAutosave: 100, now: 200))
        #expect(workspace.autosaveDue(lastEdit: 100, lastAutosave: 99, now: 200))
    }

    @Test func notDueWithNaNOrInfiniteInputs() throws {
        let workspace = try editedImage()
        #expect(!workspace.autosaveDue(lastEdit: .nan, lastAutosave: nil, now: 200))
        #expect(!workspace.autosaveDue(lastEdit: 100, lastAutosave: .nan, now: 200))
        #expect(!workspace.autosaveDue(lastEdit: 100, lastAutosave: nil, now: .nan))
        #expect(!workspace.autosaveDue(lastEdit: 100, lastAutosave: nil, now: 200, delay: .nan))
        #expect(!workspace.autosaveDue(lastEdit: 100, lastAutosave: nil, now: .infinity))
        #expect(!workspace.autosaveDue(lastEdit: -.infinity, lastAutosave: nil, now: 200))
        #expect(!workspace.autosaveDue(lastEdit: 100, lastAutosave: -.infinity, now: 200))
        #expect(!workspace.autosaveDue(lastEdit: 100, lastAutosave: nil, now: 200, delay: -.infinity))
    }

    @Test func recoveryEntryIsNilWhenClean() throws {
        let archive = FakeArchive()
        #expect(try openedImage().recoveryEntry(now: 1, archive: archive, codec: RawCodec()) == nil)
        #expect(try PhotoWorkspace().recoveryEntry(now: 1, archive: archive, codec: RawCodec()) == nil)
    }

    @Test func recoveryEntryCarriesTheNameAndTimeWhenDirty() throws {
        let archive = FakeArchive()
        let workspace = try editedImage()
        let entry = try #require(try workspace.recoveryEntry(now: 1_700_000_000, archive: archive, codec: RawCodec()))
        #expect(entry.documentName == "beach.png")
        #expect(entry.savedAt == 1_700_000_000)
        #expect(entry.package == (try workspace.documentPackage(archive: archive, codec: RawCodec())))
        var untitled = PhotoWorkspace(services: .fake)
        try untitled.newCanvas(width: 4, height: 3)
        untitled.addLayer()
        let unnamed = try #require(try untitled.recoveryEntry(now: 2, archive: archive, codec: RawCodec()))
        #expect(unnamed.documentName == nil)
        #expect(unnamed.savedAt == 2)
    }

    @Test func restoreLandsTheLayersDirtyAndStaysDirty() throws {
        let archive = FakeArchive()
        let entry = try #require(try editedImage().recoveryEntry(now: 1, archive: archive, codec: RawCodec()))
        var restored = PhotoWorkspace(services: .fake)
        try restored.restore(entry, archive: archive, codec: RawCodec())
        #expect(restored.layers.count == 2)
        #expect(restored.isDirty)
        #expect(restored.fileKind == nil)
        #expect(restored.documentName == "beach.png")
        #expect(restored.saveAction == .saveAs)
        restored.addLayer()
        #expect(restored.isDirty)
        restored.undo()
        #expect(restored.isDirty)
        restored.redo()
        restored.undo()
        #expect(restored.isDirty)
    }

    @Test func decodedRestoreMatchesThePackageRestore() throws {
        let archive = FakeArchive()
        let entry = try #require(try editedImage().recoveryEntry(now: 1, archive: archive, codec: RawCodec()))
        var fromPackage = PhotoWorkspace(services: .fake)
        try fromPackage.restore(entry, archive: archive, codec: RawCodec())
        var fromSnapshot = PhotoWorkspace(services: .fake)
        try fromSnapshot.restore(entry, decoded: try archive.decode(entry.package, codec: RawCodec()))
        #expect(fromSnapshot.layers.count == 2)
        #expect(fromSnapshot.isDirty)
        #expect(fromSnapshot.fileKind == nil)
        #expect(fromSnapshot.documentName == "beach.png")
        #expect(fromSnapshot.saveAction == .saveAs)
        #expect(fromSnapshot.layers == fromPackage.layers)
        #expect(try fromSnapshot.snapshot() == (try fromPackage.snapshot()))
    }

    @Test func aDamagedDecodedRestoreLeavesTheWorkspaceAsItWas() throws {
        let before = try openedImage("other.png")
        var workspace = before
        let entry = RecoveryEntry(documentName: "beach.png", savedAt: 1, package: PhotoPackage(files: [:]))
        let empty = PhotoDocumentSnapshot(
            canvas: try #require(before.canvas), layers: [], pixels: [:], masks: [:],
            adjustments: before.adjustments, selectedLayerID: nil)
        #expect(throws: ArchiveError.self) { try workspace.restore(entry, decoded: empty) }
        #expect(workspace == before)
    }

    @Test func restoreWithoutANameStaysUntitled() throws {
        let archive = FakeArchive()
        let edited = try editedImage()
        let package = try edited.documentPackage(archive: archive, codec: RawCodec())
        var restored = PhotoWorkspace(services: .fake)
        try restored.restore(RecoveryEntry(documentName: nil, savedAt: 1, package: package), archive: archive, codec: RawCodec())
        #expect(restored.documentName == nil)
        #expect(restored.inspectorHeaderTitle == "Untitled")
        #expect(restored.isDirty)
    }

    @Test func aFailedRestoreLeavesTheWorkspaceAsItWas() throws {
        let before = try openedImage("other.png")
        var workspace = before
        let entry = RecoveryEntry(documentName: "beach.png", savedAt: 1, package: PhotoPackage(files: [:]))
        #expect(throws: ArchiveError.self) { try workspace.restore(entry, archive: FakeArchive(), codec: RawCodec()) }
        #expect(workspace == before)
        #expect(!workspace.isDirty)
    }

    @Test func offerTextNamesTheImageOrSaysUnsaved() {
        let package = PhotoPackage(files: [:])
        let time: (Double) -> String = { _ in "9:41 AM" }
        let named = RecoveryOffer(entry: RecoveryEntry(documentName: "beach.png", savedAt: 1, package: package), time: time)
        #expect(named.message == "Restore beach.png from 9:41 AM?")
        let untitled = RecoveryOffer(entry: RecoveryEntry(documentName: nil, savedAt: 1, package: package), time: time)
        #expect(untitled.message == "Restore the unsaved image from 9:41 AM?")
        #expect(untitled.entry.documentName == nil)
    }

    @Test func offerPassesTheSaveTimeToTheFormatter() {
        let entry = RecoveryEntry(documentName: "a.ora", savedAt: 42, package: PhotoPackage(files: [:]))
        let offer = RecoveryOffer(entry: entry) { "t\(Int($0))" }
        #expect(offer.message == "Restore a.ora from t42?")
        #expect(offer.entry == entry)
    }
}
