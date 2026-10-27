// PhotoPasteAsImageCommandTests.swift (clipboard-interop CB-14): Photo's catalog lists `edit.paste-as-image`, paste a
// vector as pixels by name, with its title, an undoable edit kind and the shared name-and-bytes params. Until Photo's
// pasteboard adapter (CB-13) reads vector art, it is off with a reason in every state, never a dead control.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel
import Testing
@testable import PhotoModel

struct PhotoPasteAsImageCommandTests {
    static let id = "edit.paste-as-image"

    @Test func catalogListsPasteAsImage() throws {
        let spec = try #require(PhotoWorkspace.catalog.spec(Self.id), "Photo's catalog lists \(Self.id)")
        #expect(spec.title == "Paste as Image")
        #expect(spec.kind == .edit && spec.undoable)
        #expect(spec.params.validate(.object(["name": .string("art.svg"), "base64": .string("PHN2Zy8+")])).isEmpty)
        #expect(!spec.params.validate(.object(["name": .string("art.svg")])).isEmpty, "the bytes are required")
        #expect(PhotoWorkspace(services: .fake).menuTitle(Self.id) == "Paste as Image")
    }

    @Test func offWithReasonUntilTheAdapter() throws {
        let none = PhotoWorkspace(services: .fake)
        #expect(PhotoWorkspace.catalog.availability(Self.id, on: none).why == "Open an image first.")
        for (state, ws) in try PhotoCommandCatalogTests.states().dropFirst() {
            #expect(PhotoWorkspace.catalog.availability(Self.id, on: ws).why == PhotoWorkspace.pasteAsImageHelp, "\(state)")
        }
        #expect(PhotoWorkspace.pasteAsImageHelp == "Paste as image arrives with Photo's pasteboard adapter.")
    }

    @Test func runRefusesAndLeavesTheImage() throws {
        var ws = try PhotoCommandCatalogTests.lawsFixture()
        let before = ws.layers.count
        let params = JSONValue.object(["name": .string("art.svg"), "base64": .string("PHN2Zy8+")])
        #expect(throws: CatalogError.self) { _ = try PhotoWorkspace.catalog.run(Self.id, params: params, on: &ws) }
        #expect(ws.layers.count == before)
    }
}
