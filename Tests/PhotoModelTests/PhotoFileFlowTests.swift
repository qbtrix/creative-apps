// PhotoFileFlowTests.swift: MPF, Photo's file-flow Model walk (file-flow
// PF-1 written, PF-3 turns it on). Photo as a FileFlowTarget and a
// SuiteDocumentHost: it names itself "photo", places images into an open
// document as one "Place" step, opens one with no document, hands another
// app's file to that app, and accepts open, new and place hand-offs.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import CoreRaster
import PhotoModel
import SuiteKernel
import SuiteModel
import Testing

/// A 4 x 3 white PNG through RawCodec, opened as `name`.
private func openedImage(_ name: String = "Sunset.png") throws -> PhotoWorkspace {
    let white = DecodedImage(rgba8: [UInt8](repeating: 255, count: 4 * 3 * 4), width: 4, height: 3)
    var workspace = PhotoWorkspace(services: .fake)
    try workspace.openImage(try RawCodec().encode(white, as: .png, quality: 1), name: name, codec: RawCodec())
    return workspace
}

/// A hand-off from Library to Photo for `path`.
private func handOff(_ verb: HandOffVerb, path: String = "/w/Logo.png") -> HandOff {
    let ref = SuiteDocumentRef(path: path, fileID: SuiteDocumentRef.fileID(forPath: path), app: .library,
                               type: .png, displayName: "Logo.png")
    return HandOff(id: HandOff.newID(), from: .library, to: .photo, verb: verb, documents: [ref],
                   createdAt: Date(timeIntervalSince1970: 0))
}

/// The PF-1 stubs, on today: what the adapter answers before PF-3 writes the bodies.
/// PF-3 replaces the refusal and not-built checks with the walk below.
@Suite struct PhotoFileFlowStubTests {
    @Test func photoNamesItselfAndListsWhatItPlaces() {
        let workspace = PhotoWorkspace(services: .fake)
        #expect(workspace.appID == "photo")
        #expect(workspace.placesExtensions == ["png", "jpg", "jpeg", "heic", "tiff", "psd"])
    }

    @Test func hasDocumentFollowsTheCanvas() throws {
        #expect(!PhotoWorkspace(services: .fake).hasDocument)
        #expect(try openedImage().hasDocument)
    }

    @Test func noRecentsAndNoOpenInYet() throws {
        let workspace = try openedImage()
        #expect(workspace.recentFiles.isEmpty)
        #expect(workspace.openInApps.isEmpty)
        #expect(workspace.openInHelp == "Open In isn't built yet.")
        #expect(workspace.readers(ofExtension: "png").isEmpty)
    }

    @Test func everyHandOffIsRefusedWithTheReason() async throws {
        let workspace = try openedImage()
        let reason = SuiteError.notAvailable("Photo can't take files from other apps yet.")
        for verb in [HandOffVerb.open, .new, .place, .edit, .importAnimation] {
            #expect(await workspace.refusal(for: handOff(verb)) == reason)
        }
        await #expect(throws: reason) { _ = try await workspace.accept(handOff(.open)) }
    }

    @Test func eachFileFlowCommandThrowsNotBuilt() throws {
        var workspace = try openedImage()
        let notBuilt = { (id: String) in CatalogError.notBuilt(id: id, feature: "file-flow") }
        #expect(throws: notBuilt("file.open-recent")) { try workspace.openRecent("abc") }
        #expect(throws: notBuilt("file.clear-recent")) { try workspace.clearRecent() }
        #expect(throws: notBuilt("file.open-in")) { try workspace.openIn("library") }
        #expect(throws: notBuilt("file.drop")) { try workspace.perform([.place(path: "/w/Logo.png")]) }
        #expect(workspace.layers.count == 1)
    }
}

/// MPF, the behaviour PF-3 turns on.
@Suite(.disabled("waits on PF-3")) struct PhotoFileFlowTests {

    @Test func photoNamesItselfAndPlacesImages() {
        let workspace = PhotoWorkspace(services: .fake)
        #expect(workspace.appID == "photo")
        #expect(workspace.placesExtensions == ["png", "jpg", "jpeg", "heic", "tiff", "psd"])
        #expect(!workspace.hasDocument)
    }

    @Test func aPNGOnAnOpenImagePlacesOneLayerInOneStep() throws {
        var workspace = try openedImage()
        let before = workspace.layers.count
        try workspace.perform([.place(path: "/w/Logo.png")])
        #expect(workspace.layers.count == before + 1)
        #expect(workspace.undoActionName == "Undo Place")
        workspace.undo()
        #expect(workspace.layers.count == before)
    }

    @Test func dropPlansFollowTheSuiteRule() throws {
        let open = try openedImage()
        let empty = PhotoWorkspace(services: .fake)
        let plan = { (target: PhotoWorkspace, path: String) in
            DropPlan.plan([path], into: target.appID, hasDocument: target.hasDocument,
                          places: target.placesExtensions, readers: { target.readers(ofExtension: $0) })
        }
        #expect(plan(open, "/w/Logo.png") == [.place(path: "/w/Logo.png")])
        #expect(plan(empty, "/w/Logo.png") == [.open(path: "/w/Logo.png")])
        #expect(plan(open, "/w/Intro.halo") == [.handOff(path: "/w/Intro.halo", app: "halo")])
    }

    @Test func openInOffersLibraryForAnImage() throws {
        let workspace = try openedImage()
        #expect(workspace.openInApps.contains("library"))
        #expect(!workspace.openInApps.contains("photo"))
    }

    @Test func hostAcceptsOpenNewAndPlace() async throws {
        let workspace = try openedImage()
        for verb in [HandOffVerb.open, .new, .place] {
            #expect(await workspace.refusal(for: handOff(verb)) == nil)
        }
        #expect(await workspace.refusal(for: handOff(.importAnimation)) != nil)
    }

    @Test func clearRecentEmptiesTheList() throws {
        var workspace = PhotoWorkspace(services: .fake)
        try workspace.clearRecent()
        #expect(workspace.recentFiles.isEmpty)
    }
}
