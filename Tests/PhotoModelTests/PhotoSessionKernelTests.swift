// PhotoSessionKernelTests.swift: Photo's session adapter onto SuiteKernel
// (PhotoRecovery+Kernel.swift): the session's tokens follow the history, a
// restored autosave is never saved, the save status and the recovery offer
// map onto the kernel's, and a newer document format stays refused. Runs on
// Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoSessionKernelTests {
    private func blank() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.newCanvas(width: 4, height: 3)
        return workspace
    }

    @Test func theSessionFollowsTheHistory() throws {
        var workspace = try blank()
        #expect(!workspace.documentSession.isDirty)
        workspace.addLayer()
        #expect(workspace.documentSession.isDirty)
        #expect(workspace.documentSession.currentToken == workspace.currentStepID)
        workspace.undo()
        #expect(!workspace.documentSession.isDirty)
        #expect(!PhotoWorkspace().documentSession.isDirty)
    }

    @Test func aRestoredAutosaveIsNeverSaved() throws {
        let archive = FakeArchive()
        var edited = try blank()
        edited.addLayer()
        let entry = try #require(try edited.recoveryEntry(now: 1, archive: archive, codec: RawCodec()))
        var restored = PhotoWorkspace(services: .fake)
        try restored.restore(entry, archive: archive, codec: RawCodec())
        #expect(restored.documentSession.isDirty)
        #expect(restored.autosaveDue(lastEdit: 100, lastAutosave: nil, now: 105))
    }

    @Test func theStatusMapsOntoTheKernels() {
        #expect(PhotoSaveStatus.saved.kernelStatus == .saved)
        #expect(PhotoSaveStatus.edited.kernelStatus == .unsaved)
        #expect(PhotoSaveStatus.editedAutosaved.kernelStatus == .unsaved)
        #expect(PhotoSaveStatus.notSaved.kernelStatus == .failed(PhotoSaveStatus.notSaved.help(fileName: nil)))
    }

    @Test func theOfferMapsOntoTheKernels() {
        let named = RecoveryOffer(
            entry: RecoveryEntry(documentName: "beach.png", savedAt: 42, package: PhotoPackage(files: [:]))) { _ in "" }
        #expect(named.kernelOffer == SuiteKernel.RecoveryOffer(name: "beach.png", savedAt: Date(timeIntervalSince1970: 42)))
        let untitled = RecoveryOffer(
            entry: RecoveryEntry(documentName: nil, savedAt: 1, package: PhotoPackage(files: [:]))) { _ in "" }
        #expect(untitled.kernelOffer.name == "Untitled")
    }

    @Test func theProbeMapsTheKernelsRefusals() throws {
        let unreadable = ArchiveError.damaged("unreadable")
        #expect(try LiveArchive.probeFormat(Data(#"{"format":1}"#.utf8), supported: 1, unreadable: unreadable) == 1)
        #expect(throws: ArchiveError.newerVersion(2)) {
            try LiveArchive.probeFormat(Data(#"{"format":2}"#.utf8), supported: 1, unreadable: unreadable)
        }
        #expect(throws: unreadable) {
            try LiveArchive.probeFormat(Data(#"{"version":1}"#.utf8), supported: 1, unreadable: unreadable)
        }
        #expect(throws: unreadable) { try LiveArchive.probeFormat(Data("[1]".utf8), supported: 1, unreadable: unreadable) }
    }
}
