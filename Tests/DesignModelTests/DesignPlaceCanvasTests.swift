// DesignPlaceCanvasTests.swift (placed-images PD-u, PD-3 and PD-4): what the canvas, the File menu and the Picture
// section ask the Model: a node's picture is its frame's box; a place refusal says why and changes nothing, before
// and after PD-5; a Move-tool ⌥-drag pans an overflowing picture; a drop's page point and fill. Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import Testing

/// A 1200 × 800 picture: in a 400 × 400 box it draws 600 × 400, 200 wider than the box and as tall.
private let asset = PlacedAsset(
    id: "asset-1", name: "photo.png", format: .png, natural: Size(width: 1200, height: 800), data: Data([1, 2, 3]))

/// A page holding node-1, a 400 × 400 frame at (100, 100) (showing `asset` unless `picture` is off), selected.
private func opened(picture: Bool = true, locked: Bool = false, size: (Double, Double) = (400, 400),
                    turn: (degrees: Double, flipX: Bool) = (0, false)) throws -> DesignWorkspace {
    var frame = DesignNode(id: "node-1", name: "Frame", kind: .frame, frame: rc(100, 100, size.0, size.1),
                           placedAsset: picture ? asset : nil)
    (frame.isLocked, frame.rotation, frame.flipX) = (locked, turn.degrees, turn.flipX)
    let page = DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: [frame])
    var workspace = DesignWorkspace()
    try workspace.open(LiveFiling().encode(DesignDocument(pages: [page])))
    workspace.useServices(.live)
    workspace.selectItem("node-1")
    return workspace
}

extension JSONValue {
    /// The object field `key`; nil when this isn't an object or has no such field.
    fileprivate func field(_ key: String) -> JSONValue? { if case .object(let fields) = self { fields[key] } else { nil } }
}

@Suite struct DesignPlaceCanvasTests {
    @Test func aNodesPictureIsItsFrame() throws {
        let node = try #require(try opened().selectedNode)
        let image = try #require(node.placedImage)
        #expect(image.assetID == "asset-1" && image.focus == Point(x: 0.5, y: 0.5))
        #expect(image.box == Rect(minX: 100, minY: 100, maxX: 500, maxY: 500))
        #expect(try opened(picture: false).selectedNode?.placedImage == nil)
    }

    @Test func aFillPlaceAsksToFillTheFrame() {
        let place = PlaceIntent.place(name: "a.png", data: Data([1]), at: nil)
        #expect(DesignWorkspace.placeCommand(place, fill: true).params.field("fill") == .bool(true))
        #expect(DesignWorkspace.placeCommand(place, fill: false).params.field("fill") == nil)
        #expect(DesignWorkspace.placeCommand(.resetSize, fill: true).params == .object([:]))
        #expect(DesignWorkspace.placeCommand(.resetSize, fill: true).id == "place.reset-size")
    }

    @Test func aRefusedPlaceSaysWhyAndChangesNothing() throws {
        var empty = DesignWorkspace()
        #expect(empty.runPlace(.place(name: "a.png", data: Data([1]), at: nil)) == DesignWorkspace.noPlacePage)
        #expect(empty.placeActionHelp() == DesignWorkspace.noPlacePage)
        var workspace = try opened()
        let before = workspace.pages
        let why = workspace.runPlace(.place(name: "a.png", data: Data([1, 2]), at: nil))
        #expect(why?.isEmpty == false)
        #expect(workspace.pages == before)
    }

    @Test func anOptionDragInsideThePicturePansIt() throws {
        let workspace = try opened()
        let pan = try #require(workspace.beginPicturePan(at: pt(300, 300), option: true, token: "t"))
        #expect(pan.focus == Point(x: 0.5, y: 0.5) && pan.token == "t")
        #expect(workspace.panIntent(pan, to: pt(340, 330)) == .focus(Point(x: 0.3, y: 0.5), drag: "t"))
        #expect(workspace.panIntent(pan, to: pt(-1000, 300)) == .focus(Point(x: 1, y: 0.5), drag: "t"))
    }

    @Test func aPanNeedsOptionAPictureUnderThePointerAndNoLock() throws {
        #expect(try opened().beginPicturePan(at: pt(300, 300), option: false) == nil)
        #expect(try opened().beginPicturePan(at: pt(600, 300), option: true) == nil)
        #expect(try opened(picture: false).beginPicturePan(at: pt(300, 300), option: true) == nil)
        #expect(try opened(locked: true).beginPicturePan(at: pt(300, 300), option: true) == nil)
    }

    @Test func onlyTheMoveToolPansOffTheHandles() throws {
        var drawing = try opened()
        drawing.selectTool(.rectangle)
        #expect(drawing.beginPicturePan(at: pt(300, 300), option: true) == nil)
        #expect(try opened().beginPicturePan(at: pt(100, 100), option: true) == nil)
        #expect(try opened().beginPicturePan(at: pt(500, 300), option: true) == nil)
    }

    @Test func aFittedPictureDoesNotPanSoOptionDuplicates() throws {
        var fitted = try opened(size: (600, 400))
        #expect(fitted.beginPicturePan(at: pt(300, 300), option: true) == nil)
        fitted.drag(from: pt(300, 300), to: pt(350, 300), modifiers: .option)
        fitted.endDrag()
        #expect(fitted.selectedPage?.nodes.count == 2)
    }

    @Test func aPanFollowsThePointerOnATurnedOrMirroredNode() throws {
        let turned = try opened(turn: (90, false))
        let pan = try #require(turned.beginPicturePan(at: pt(300, 300), option: true, token: "t"))
        #expect(turned.panIntent(pan, to: pt(300, 340)) == .focus(Point(x: 0.3, y: 0.5), drag: "t"))
        let mirrored = try opened(turn: (0, true))
        let flipped = try #require(mirrored.beginPicturePan(at: pt(300, 300), option: true, token: "t"))
        #expect(mirrored.panIntent(flipped, to: pt(340, 300)) == .focus(Point(x: 0.7, y: 0.5), drag: "t"))
    }

    @Test func aDropFillsOnlyTheSelectedFrameUnderIt() throws {
        let workspace = try opened(picture: false)
        #expect(workspace.dropFills(at: pt(200, 200), fill: true))
        #expect(!workspace.dropFills(at: pt(200, 200), fill: false))
        #expect(!workspace.dropFills(at: pt(700, 200), fill: true))
        #expect(!(try opened(locked: true)).dropFills(at: pt(200, 200), fill: true))
    }

    @Test func aDropPointIsInPagePoints() {
        #expect(DesignWorkspace.dropPoint(x: 300, y: 100, zoom: 2) == pt(150, 50))
        #expect(DesignWorkspace.dropPoint(x: 300, y: 100, zoom: 0) == nil)
        #expect(DesignWorkspace.dropPoint(x: 300, y: 100, zoom: .nan) == nil)
    }
}
