// PhotoDocumentFileTests.swift: the workspace side of documents (PV-1, D-3):
// which kind an opened file is, what File > Save does with it, the save
// status, and a document's round trip through a DocumentArchiving (FakeArchive,
// lossless). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import PhotoModel
import Testing

@Suite struct PhotoDocumentFileTests {
    /// A 4 x 3 white PNG through RawCodec, opened as `name`.
    private func openedImage(_ name: String = "a.png") throws -> PhotoWorkspace {
        let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.openImage(try RawCodec().encode(white, as: .png, quality: 1), name: name, codec: RawCodec())
        return workspace
    }

    /// `workspace` saved as a document and opened again in a new workspace.
    private func reopened(_ workspace: PhotoWorkspace) throws -> PhotoWorkspace {
        let archive = FakeArchive()
        let package = try workspace.documentPackage(archive: archive, codec: RawCodec())
        var opened = PhotoWorkspace(services: .fake)
        try opened.openDocument(package, name: "a.ora", archive: archive, codec: RawCodec())
        return opened
    }

    @Test func fileKindFollowsTheName() {
        #expect(PhotoWorkspace.fileKind(forName: "a.ora") == .document)
        #expect(PhotoWorkspace.fileKind(forName: "a.ORA") == .document)
        #expect(PhotoWorkspace.fileKind(forName: "a.PNG") == .image(.png))
        #expect(PhotoWorkspace.fileKind(forName: "a.jpeg") == .image(.jpeg))
        #expect(PhotoWorkspace.fileKind(forName: "a.heic") == .readOnly)
        #expect(PhotoWorkspace.fileKind(forName: "ora") == .readOnly)
    }

    @Test func openImageKnowsItsKindAndIsClean() throws {
        let workspace = try openedImage()
        #expect(workspace.fileKind == .image(.png))
        #expect(workspace.documentName == "a.png")
        #expect(!workspace.isDirty)
        #expect(try openedImage("a.heic").fileKind == .readOnly)
    }

    @Test func saveRoutesByKindAndLayers() throws {
        var workspace = try openedImage()
        #expect(!workspace.needsDocument)
        #expect(workspace.saveAction == .writeImage(.png))
        workspace.addLayer()
        #expect(workspace.needsDocument)
        #expect(workspace.saveAction == .askKeepLayers(.png))
        #expect(try openedImage("a.heic").saveAction == .saveAs)
        #expect(try whiteImage().saveAction == .saveAs)
        workspace.didSave(as: "a.ora", kind: .document)
        #expect(workspace.saveAction == .writeDocument)
        #expect(workspace.documentName == "a.ora")
    }

    @Test func aMaskOrAnAdjustmentLayerNeedsADocument() throws {
        #expect(try PhotoWorkspace.fixture(.layered).needsDocument)
        #expect(!(try PhotoWorkspace.fixture(.sample).needsDocument))
        #expect(!PhotoWorkspace().needsDocument)
    }

    @Test func didSaveCleansAndUndoDirties() throws {
        var workspace = try openedImage()
        workspace.addLayer()
        #expect(workspace.isDirty)
        workspace.didSave(as: "a.ora", kind: .document)
        #expect(!workspace.isDirty)
        workspace.undo()
        #expect(workspace.isDirty)
        workspace.redo()
        #expect(!workspace.isDirty)
    }

    @Test func statusFollowsEdits() throws {
        #expect(PhotoWorkspace().saveStatus(autosaved: false, saveFailed: false) == nil)
        var workspace = try openedImage()
        #expect(workspace.saveStatus(autosaved: false, saveFailed: false) == .saved)
        workspace.addLayer()
        #expect(workspace.saveStatus(autosaved: false, saveFailed: false) == .edited)
        #expect(workspace.saveStatus(autosaved: true, saveFailed: false) == .editedAutosaved)
        #expect(workspace.saveStatus(autosaved: true, saveFailed: true) == .notSaved)
        workspace.didSave(as: "a.ora", kind: .document)
        #expect(workspace.saveStatus(autosaved: false, saveFailed: false) == .saved)
        #expect(PhotoSaveStatus.allCases.map(\.title) == ["Saved", "Edited", "Edited, autosaved", "Not saved"])
    }

    @Test func openHasNoUndo() throws {
        var source = try PhotoWorkspace.fixture(.layered)
        source.addLayer()
        let opened = try reopened(source)
        #expect(!opened.canUndo && !opened.canRedo)
        #expect(!opened.isDirty)
        #expect(opened.historySteps == ["Open"])
        #expect(opened.fileKind == .document)
        #expect(opened.documentName == "a.ora")
        #expect(opened.saveAction == .writeDocument)
    }

    @Test func reopeningKeepsLayersMasksKindsAndAdjustments() throws {
        var source = try PhotoWorkspace.fixture(.layered)
        source.adjust(.exposure(0.5))
        let opened = try reopened(source)
        #expect(opened.layers == source.layers)
        #expect(opened.selectedLayerID == source.selectedLayerID)
        #expect(opened.adjustments == source.adjustments)
        #expect(Set(opened.masks.keys) == Set(source.masks.keys))
        #expect(Set(opened.pixels.keys) == Set(source.pixels.keys))
        #expect(opened.canvas == source.canvas)
    }

    @Test func aNewLayerAfterOpeningTakesTheNextID() throws {
        let image = DecodedImage(rgba8: [UInt8](repeating: 255, count: 2 * 2 * 4), width: 2, height: 2)
        let top = PhotoLayer(id: "layer-40", name: "Top"), bottom = PhotoLayer(id: "layer-7", name: "Background")
        let snapshot = PhotoDocumentSnapshot(
            canvas: CanvasSize(width: 2, height: 2), layers: [top, bottom],
            pixels: [top.id: image, bottom.id: image], selectedLayerID: top.id)
        let archive = FakeArchive()
        let package = try archive.encode(snapshot, codec: RawCodec())
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.openDocument(package, name: "a.ora", archive: archive, codec: RawCodec())
        #expect(workspace.layers.map(\.id) == ["layer-40", "layer-7"])
        workspace.addLayer()
        #expect(workspace.selectedLayerID == "layer-41")
    }

    @Test func aDamagedSnapshotLeavesTheWorkspaceAsItWas() throws {
        let layer = PhotoLayer(id: "layer-1", name: "Background")
        let snapshot = PhotoDocumentSnapshot(canvas: CanvasSize(width: 2, height: 2), layers: [layer], pixels: [:])
        let archive = FakeArchive()
        let package = try archive.encode(snapshot, codec: RawCodec())
        var workspace = try openedImage()
        let before = workspace
        #expect(throws: ArchiveError.self) {
            try workspace.openDocument(package, name: "b.ora", archive: archive, codec: RawCodec())
        }
        #expect(workspace == before)
    }

    @Test func compositeSurvives() throws {
        var source = try PhotoWorkspace.fixture(.layered)
        source.adjust(.exposure(0.25))
        let before = try source.composite().rgba8()
        let after = try reopened(source).composite().rgba8()
        #expect(before.count == after.count)
        let drift = zip(before, after).map { abs(Int($0) - Int($1)) }.max() ?? 0
        #expect(drift <= 1, "the composite drifted by \(drift)/255")
    }
}
