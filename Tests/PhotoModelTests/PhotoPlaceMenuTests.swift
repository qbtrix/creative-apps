// PhotoPlaceMenuTests.swift (place-image PP-3): what File > Place… and the canvas drop read and run. The menu
// item is built from `place.image`'s spec and takes its reason; a drop's point comes in at the canvas zoom; a place that
// can't run leaves its reason in the status line and adds nothing. These hold on the PP-1 stubs and after PP-5.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import PhotoModel
import SuiteKernel
import Testing

@Suite struct PhotoPlaceMenuTests {
    private func opened() throws -> PhotoWorkspace {
        var workspace = PhotoWorkspace()
        try workspace.newCanvas(width: 800, height: 600)
        return workspace
    }

    @Test func theMenuIsBuiltFromPlaceImage() {
        #expect(PhotoWorkspace.placeMenuSpec.id == "place.image")
        #expect(PhotoWorkspace.placeMenuSpec(in: .empty(app: "photo")).id == "place.image")
    }

    @Test func noImageTurnsPlaceOff() {
        let none = "Open or make an image to place into."
        #expect(PhotoWorkspace.placeMenuSpec.availability(PhotoWorkspace()).why == none)
        #expect(PhotoWorkspace.placeMenuSpec(in: .empty(app: "photo")).availability(PhotoWorkspace()).why == none)
    }

    /// With an image open the item follows `placeHelp`: off saying placing isn't built on the PP-1 stubs, on after PP-5.
    @Test func anOpenImageTurnsPlaceOnOnceItIsBuilt() throws {
        let workspace = try opened()
        #expect(PhotoWorkspace.placeMenuSpec.availability(workspace).why == workspace.placeHelp)
        #expect(PhotoWorkspace.placeMenuSpec.availability(workspace).why != "Open or make an image to place into.")
    }

    @Test func aDropPointIsInDocumentPixels() {
        #expect(PhotoWorkspace.placePoint(x: 400, y: 300, zoom: 2) == Point(x: 200, y: 150))
        #expect(PhotoWorkspace.placePoint(x: 30, y: 20, zoom: 0.5) == Point(x: 60, y: 40))
        #expect(PhotoWorkspace.placePoint(x: 30, y: 20, zoom: 0) == Point(x: 30, y: 20))
    }

    @Test func noImageRefusesWithItsReason() {
        var workspace = PhotoWorkspace()
        workspace.place([(name: "logo.png", data: Data([0x89, 0x50, 0x4E, 0x47]))], at: nil)
        #expect(workspace.statusMessage == "Open or make an image to place into.")
        #expect(workspace.canvas == nil)
    }

    @Test func anSVGAddsNothingAndSaysWhy() throws {
        var workspace = try opened()
        let svg = Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="240" height="80"/>"#.utf8)
        workspace.place([(name: "logo.svg", data: svg)], at: Point(x: 10, y: 10))
        #expect(workspace.statusMessage?.isEmpty == false)
        #expect(workspace.layers.count == 1)
        #expect(!workspace.canUndo)
    }

    @Test func noFilesChangesNothing() throws {
        var workspace = try opened()
        workspace.place([], at: nil)
        #expect(workspace.statusMessage == nil)
        #expect(workspace.layers.count == 1)
    }
}
