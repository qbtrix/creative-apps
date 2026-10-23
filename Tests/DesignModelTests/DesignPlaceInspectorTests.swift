// DesignPlaceInspectorTests.swift (placed-images PD-u, PD-4): what Place…, a drop, the Picture section and a pan
// decide: fill only a fillable selection, plain reasons never ids, a pan landing once. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import Testing

/// A 1200 × 800 picture, 3:2.
private let asset = PlacedAsset(
    id: "asset-1", name: "photo.png", format: .png, natural: Size(width: 1200, height: 800), data: Data([1, 2, 3]))

/// A page holding node-1 (a `kind` at (100, 100), `size`, showing `asset` when `picture`), selected unless `select` is off.
private func page(_ kind: DesignNodeKind = .frame, picture: Bool = false, size: (Double, Double) = (400, 400),
                  locked: Bool = false, select: Bool = true) throws -> DesignWorkspace {
    var node = DesignNode(id: "node-1", name: "Frame", kind: kind, frame: rc(100, 100, size.0, size.1),
                          placedAsset: picture ? asset : nil)
    node.isLocked = locked
    let page = DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: [node])
    var workspace = DesignWorkspace()
    try workspace.open(LiveFiling().encode(DesignDocument(pages: [page])))
    workspace.useServices(.live)
    if select { workspace.selectItem("node-1") }
    return workspace
}

@Suite struct DesignPlaceInspectorTests {
    @Test func fillFillsOnlyASelectedUnlockedFrameOrRectangle() throws {
        #expect(try page().placeFills(fill: true))
        #expect(try page(.rectangle).placeFills(fill: true))
        #expect(try !page().placeFills(fill: false))
        #expect(try !page(select: false).placeFills(fill: true), "nothing selected: a new layer, not a refusal")
        #expect(try !page(.ellipse).placeFills(fill: true))
        #expect(try !page(locked: true).placeFills(fill: true))
    }

    @Test func onlyTheFirstFileFillsTheFrame() {
        let files = [(name: "a.png", data: Data([1])), (name: "b.png", data: Data([2])), (name: "c.png", data: Data([3]))]
        let at = Point(x: 10, y: 20)
        let filled = DesignWorkspace.placeSteps(files, fills: true, at: at)
        #expect(filled.map(\.fill) == [true, false, false])
        #expect(filled.map(\.intent) == [.place(name: "a.png", data: Data([1]), at: nil),
                                         .place(name: "b.png", data: Data([2]), at: at), .place(name: "c.png", data: Data([3]), at: at)])
        let added = DesignWorkspace.placeSteps(files, fills: false, at: nil)
        #expect(added.map(\.fill) == [false, false, false])
        #expect(added.first?.intent == .place(name: "a.png", data: Data([1]), at: nil))
    }

    @Test func resetSizeIsOffOnAPictureOfItsOwnShape() throws {
        #expect(try page(picture: true, size: (300, 200)).resetSizeHelp == DesignWorkspace.naturalShape)
        #expect(try page(picture: true).resetSizeHelp == DesignWorkspace.placeNotBuilt)
    }

    @Test func theNoteNamesEachReasonOnce() throws {
        #expect(try page().placeNote == DesignWorkspace.placeNotBuilt)
        #expect(try page(picture: true).placeNote == DesignWorkspace.placeNotBuilt)
        #expect(try page(picture: true, size: (300, 200)).placeNote
                == "\(DesignWorkspace.placeNotBuilt) Reset Size: \(DesignWorkspace.naturalShape)")
        #expect(DesignWorkspace().placeNote == "Open or create a file to place a picture.")
    }

    @Test func thePlaceMenuHelpIsThePlainReason() throws {
        let state = DesignMenuState(workspace: try page(), hasWindow: true)
        for id in ["place.image", "place.replace", "place.reset-size"] {
            let why = DesignMenuState.spec(id).availability(state).why
            #expect(why == state.workspace.placeActionHelp(id))
            #expect(why?.contains(id) == false)
        }
        #expect(DesignMenuState.spec("place.image").title == "Place…")
    }

    @Test func aPanShowsOnTheCopyAndLandsOnce() throws {
        var model = try page(picture: true)
        let before = model
        var live = DesignLiveEdit()
        live.begin(from: model)
        live.preview(.focus(Point(x: 0.2, y: 0.5), drag: "pan-1"))
        #expect(live.workspace != nil && model == before)
        #expect(live.end(into: &model) == .notYet(DesignWorkspace.placeNotBuilt))
        #expect(live.workspace == nil)
    }
}
