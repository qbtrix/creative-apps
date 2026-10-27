// DesignPlaceTests.swift (placed-images PD-1 written, PD-5 turns on): MJ-PD, the Model walk of a picture
// in a rectangle or frame. A node keeps the kernel's `PlacedAsset` and a focus point; its frame is the
// picture's box. The schema tests, the adapter's reads and the place commands' walk (PD-5's bodies of
// DesignPlace+Kernel, through the catalog as the panel and the CLI run them). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import Testing

/// Tests/RealJobs/design: the jobs' saved files, and RJ-D12's 1200 × 800 PNG and rounded frame.
private let jobs = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    .appendingPathComponent("RealJobs/design")

private func fixture(_ path: String) throws -> Data { try Data(contentsOf: jobs.appendingPathComponent(path)) }

/// A 1200 × 800 PNG asset (the bytes are a stand-in; nothing here decodes them).
private let asset = PlacedAsset(
    id: "asset-1", name: "photo.png", format: .png, natural: Size(width: 1200, height: 800), data: Data([1, 2, 3]))

private let centre = Point(x: 0.5, y: 0.5), left = Point(x: 0.2, y: 0.5)
private let box = Rect(minX: 100, minY: 100, maxX: 500, maxY: 500)

/// A page holding `nodes`, opened from its file on the live services, node-1 selected.
private func opened(_ nodes: [DesignNode]) throws -> DesignWorkspace {
    let page = DesignPage(id: "page-1", name: "Page 1", frameWidth: 1440, frameHeight: 1024, nodes: nodes)
    var workspace = DesignWorkspace()
    try workspace.open(LiveFiling().encode(DesignDocument(pages: [page])))
    workspace.useServices(.live)
    workspace.selectItem("node-1")
    return workspace
}

/// A 400 × 400 frame (node-1) of `kind`, its picture `picture` with the focus left of centre.
private func node(_ kind: DesignNodeKind = .frame, picture: PlacedAsset? = asset) -> DesignNode {
    DesignNode(id: "node-1", name: "Frame", kind: kind, frame: rc(100, 100, 400, 400), cornerRadius: 24,
               placedAsset: picture, placedFocus: picture == nil ? nil : left)
}

@Suite struct DesignPlaceTests {
    @Test func anOldNodeHasNoPicture() throws {
        let file = try LiveFiling().decode(fixture("place-in-frame/input/rounded-frame.design"))
        let frame = try #require(file.pages.first?.nodes.first)
        #expect(frame.placedAsset == nil)
        #expect(frame.placedFocus == centre)
    }

    @Test(arguments: ["align-and-save/input/three-cards.design", "export-frames-svg/input/loose-front.design",
                      "place-in-frame/input/rounded-frame.design"])
    func aSavedFileReencodesByteEqual(_ path: String) throws {
        let data = try fixture(path)
        let again = try LiveFiling().encode(LiveFiling().decode(data))
        #expect(again == data)
        #expect(!String(decoding: again, as: UTF8.self).contains("placed"))
    }

    @Test func aPictureSavesOpensAndCopies() throws {
        let saved = try #require(try opened([node()]).treeNode("node-1"))
        #expect(saved.placedAsset == asset && saved.placedFocus == left)
        let copy = DesignNode(id: "node-9", copying: saved)
        #expect(copy.placedAsset == asset && copy.placedFocus == left)
    }

    @Test func aPastedOrDuplicatedFrameKeepsItsPicture() throws {
        var pasting = try opened([node()]), duplicating = try opened([node()])
        try pasting.paste(try pasting.copySelection())
        try duplicating.run(.duplicate)
        for workspace in [pasting, duplicating] {
            let id = try #require(workspace.selectedNodeIDs.last)
            #expect(id != "node-1")
            let copy = try #require(workspace.treeNode(id))
            #expect(copy.placedAsset == asset && copy.placedFocus == left)
        }
    }

    @Test func onlyAMovedFocusIsWritten() throws {
        var moved = DesignNode(id: "node-2", name: "A", kind: .rectangle, frame: rc(0, 0, 10, 10), placedAsset: asset)
        let json = String(decoding: try JSONEncoder().encode(moved), as: UTF8.self)
        #expect(json.contains("placedAsset") && !json.contains("placedFocus"))
        moved.placedFocus = left
        let back = try JSONDecoder().decode(DesignNode.self, from: JSONEncoder().encode(moved))
        #expect(back.placedFocus == left && back == moved)
    }

    @Test(arguments: DesignNodeKind.allCases)
    func onlyRectanglesAndFramesHoldAPicture(_ kind: DesignNodeKind) {
        #expect((node(kind).placedAsset != nil) == (kind == .rectangle || kind == .frame))
    }

    @Test func theSelectionsBoxIsItsFrame() throws {
        let selection = try #require(try opened([node()]).placedSelection)
        #expect(selection.id == "node-1" && selection.asset == asset)
        #expect(selection.image == PlacedImage(assetID: "asset-1", box: box, focus: left))
        #expect(try opened([node(picture: nil)]).placedSelection == nil)
    }

    @Test func aPNGsSizeComesFromItsHeader() throws {
        let workspace = openDesign()
        #expect(try workspace.rasterSize(fixture("place-in-frame/input/photo.png"), format: .png) == Size(width: 1200, height: 800))
        #expect(throws: (any Error).self) { try workspace.rasterSize(Data("<svg/>".utf8), format: .svg) }
        #expect(throws: (any Error).self) { try workspace.rasterSize(Data([0, 1, 2]), format: .png) }
    }

    @Test func itTakesAllThreeFormatsOnThePage() {
        let workspace = openDesign()
        #expect(workspace.placeFormats == [.png, .jpeg, .svg])
        #expect(workspace.placeCanvas == Rect(minX: 0, minY: 0, maxX: 1440, maxY: 1024))
    }

    // MJ-PD: the place commands' walk, through the catalog as the panel and the CLI run them.

    @Test
    func landsInSelectedFrame() throws {
        var workspace = try opened([node(picture: nil)])
        let id = try workspace.insertPlaced(asset, PlacedImage(assetID: "asset-1", box: Rect(minX: 0, minY: 0, maxX: 90, maxY: 60)), name: "Place")
        #expect(workspace.selectedPage?.nodes.first?.children.map(\.id) == [id])
        #expect(workspace.treeNode(id)?.name == "photo")
    }

    @Test
    func fillTakesTheFrame() throws {
        var workspace = try opened([node(picture: nil)])
        #expect(workspace.placeFillBox == box)
        try workspace.setPlaced(PlacedImage(assetID: "asset-1", box: box), asset: asset, name: "Place", drag: nil)
        #expect(workspace.treeNode("node-1")?.frame == rc(100, 100, 400, 400))
        #expect(workspace.treeNode("node-1")?.placedAsset == asset)
        #expect(workspace.selectedPage?.nodes.count == 1)
    }

    @Test(arguments: [DesignNodeKind.ellipse, .text])
    func fillRefusesOtherKinds(_ kind: DesignNodeKind) throws {
        #expect(try opened([node(kind, picture: nil)]).placeFillBox == nil)
    }

    @Test
    func lockedFrameRefuses() throws {
        var workspace = try opened([node()])
        try workspace.setNodeLocked("node-1", true)
        #expect(throws: (any Error).self) {
            try workspace.setPlaced(PlacedImage(assetID: "asset-1", box: box, focus: centre), asset: nil, name: "Focus", drag: nil)
        }
    }

    @Test
    func focusDragIsOneStep() throws {
        var workspace = try opened([node()])
        for x in stride(from: 0.2, through: 0.8, by: 0.1) {
            try workspace.setPlaced(PlacedImage(assetID: "asset-1", box: box, focus: Point(x: x, y: 0.5)), asset: nil, name: "Focus", drag: "pan")
        }
        workspace.undo()
        #expect(workspace.treeNode("node-1")?.placedFocus == left)
    }

    @Test
    func resetSizeRestoresThreeTwo() throws {
        var workspace = try opened([node()])
        let selection = try #require(workspace.placedSelection)
        let reset = PlaceRules.resetBox(selection.image, natural: selection.asset.natural)
        try workspace.setPlaced(PlacedImage(assetID: "asset-1", box: reset, focus: left), asset: nil, name: "Reset Size", drag: nil)
        let frame = try #require(workspace.treeNode("node-1")?.frame)
        #expect(abs(frame.width * 2 - frame.height * 3) < 1e-9)
    }

    @Test func aJPEGsSizeComesFromItsHeader() throws {
        // SOI, then a baseline SOF0 of 300 x 200 with three components, then EOI.
        let jpeg = Data([0xFF, 0xD8, 0xFF, 0xC0, 0x00, 0x11, 0x08, 0x00, 0xC8, 0x01, 0x2C, 0x03,
                         0x01, 0x11, 0x00, 0x02, 0x11, 0x01, 0x03, 0x11, 0x01, 0xFF, 0xD9])
        #expect(try openDesign().rasterSize(jpeg, format: .jpeg) == Size(width: 300, height: 200))
    }

    @Test func itCanPlaceWithAPageOpen() throws {
        let workspace = try opened([node(picture: nil)])
        #expect(workspace.placeHelp == nil)
        #expect(workspace.placeCanvas == box)
        #expect(DesignWorkspace().placeHelp != nil)
    }

    @Test func thePlaceCommandsAreInTheCatalog() {
        let ids = Set(DesignWorkspace.commands.map(\.id))
        #expect(["place.read", "place.image", "place.replace", "place.reset-size", "place.focus"].allSatisfy(ids.contains))
    }

    @Test func placeImageFillsTheSelectedFrameThroughTheCatalog() throws {
        var workspace = try opened([node(picture: nil)])
        let png = try fixture("place-in-frame/input/photo.png").base64EncodedString()
        let params: JSONValue = .object(["name": .string("photo.png"), "base64": .string(png), "fill": .bool(true)])
        _ = try DesignWorkspace.catalog.run("place.image", params: params, on: &workspace)
        #expect(workspace.treeNode("node-1")?.placedAsset?.natural == Size(width: 1200, height: 800))
        #expect(workspace.selectedPage?.nodes.count == 1)
        workspace.undo()
        #expect(workspace.treeNode("node-1")?.placedAsset == nil)
    }

    @Test(arguments: [DesignNodeKind.ellipse, .text])
    func fillRefusesOtherKindsWithItsReason(_ kind: DesignNodeKind) throws {
        var workspace = try opened([node(kind, picture: nil)])
        let params: JSONValue = .object(["name": .string("logo.svg"), "base64": .string(svgLogo), "fill": .bool(true)])
        #expect(throws: CatalogError.unavailable(id: "place.image", why: "Select a frame to fill.")) {
            try DesignWorkspace.catalog.run("place.image", params: params, on: &workspace)
        }
    }

    @Test func aPlaceWithNothingSelectedLandsOnThePageFitted() throws {
        var workspace = try opened([node(picture: nil)])
        workspace.deselect()
        let params: JSONValue = .object(["name": .string("logo.svg"), "base64": .string(svgLogo), "fill": .bool(false)])
        _ = try DesignWorkspace.catalog.run("place.image", params: params, on: &workspace)
        let placed = try #require(workspace.selectedPage?.nodes.last)
        #expect(placed.kind == .rectangle && placed.name == "logo" && placed.frame == rc(600, 472, 240, 80))
        workspace.undo()
        #expect(workspace.selectedPage?.nodes.count == 1)
    }

    @Test func aPlaceLandsInTheFrameItsCentreFallsIn() throws {
        // A 100 × 100 frame under the box's corner but not its centre: the logo lands on the page, whole.
        var corner = try opened([DesignNode(id: "node-1", name: "F", kind: .frame, frame: rc(600, 472, 100, 100))])
        corner.deselect()
        try placeLogo(&corner)
        #expect(corner.selectedPage?.nodes.map(\.name) == ["F", "logo"])
        // Dropped on a 200 × 200 frame's centre, the box's corner outside it: the logo lands in that frame.
        var dropped = try opened([DesignNode(id: "node-1", name: "F", kind: .frame, frame: rc(500, 500, 200, 200))])
        dropped.deselect()
        try placeLogo(&dropped, at: Point(x: 600, y: 600))
        #expect(dropped.selectedPage?.nodes.first?.children.map(\.name) == ["logo"])
        // It is fitted to that frame, not the page, so the frame's clip cuts none of it: 200 × 66.7 at the drop.
        let logo = try #require(dropped.selectedPage?.nodes.first?.children.first?.frame)
        #expect(within(logo, rc(500, 500, 200, 200)) && logo.width == 200 && abs(logo.y + logo.height / 2 - 600) < 1e-9)
    }

    @Test func aPlaceWithNoPointFitsTheFrameUnderThePageCentre() throws {
        // File > Place with nothing selected: a 400 × 400 frame on the page's centre takes the 1200 × 800 photo whole.
        var workspace = try opened([DesignNode(id: "node-1", name: "F", kind: .frame, frame: rc(520, 312, 400, 400))])
        workspace.deselect()
        let photo = Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="1200" height="800"/>"#.utf8).base64EncodedString()
        let params: [String: JSONValue] = ["name": .string("photo.svg"), "base64": .string(photo), "fill": .bool(false)]
        _ = try DesignWorkspace.catalog.run("place.image", params: .object(params), on: &workspace)
        let box = try #require(workspace.selectedPage?.nodes.first?.children.first?.frame)
        #expect(within(box, rc(520, 312, 400, 400)) && box.width == 400 && abs(box.height - 800.0 / 3) < 1e-9)
    }

    @Test func aLockedRectangleRefusesFillWithTheLock() throws {
        var workspace = try opened([node(.rectangle, picture: nil)])
        try workspace.setNodeLocked("node-1", true)
        #expect(throws: CatalogError.unavailable(id: "place", why: "Unlock the layer to edit it.")) { try placeLogo(&workspace, fill: true) }
        #expect(workspace.treeNode("node-1")?.placedAsset == nil)
    }

    @Test func aLockedPictureLetsAPlaceLandOnThePage() throws {
        var workspace = try opened([node(.rectangle)])
        try workspace.setNodeLocked("node-1", true)
        #expect(workspace.placeHelp == nil)
        try placeLogo(&workspace)
        #expect(workspace.selectedPage?.nodes.map(\.name) == ["Frame", "logo"])
    }

    @Test func aLockedFrameRefusesAPlaceWithItsLock() throws {
        var workspace = try opened([node(picture: nil)])
        try workspace.setNodeLocked("node-1", true)
        let page = workspace.selectedPage
        #expect(workspace.placeHelp == "Unlock the layer to edit it.")
        #expect(throws: CatalogError.unavailable(id: "place.image", why: "Unlock the layer to edit it.")) { try placeLogo(&workspace) }
        #expect(workspace.selectedPage == page)
    }

    @Test func aPlaceWaitsForTheTextEdit() throws {
        let text = DesignNode(id: "node-2", name: "T", kind: .text, frame: rc(0, 0, 100, 20), text: "Hi")
        var workspace = try opened([node(picture: nil), text])
        try workspace.beginTextEdit("node-2")
        let page = workspace.selectedPage
        #expect(workspace.placeHelp == "Finish editing the text first.")
        #expect(throws: CatalogError.unavailable(id: "place.image", why: "Finish editing the text first.")) { try placeLogo(&workspace) }
        #expect(workspace.selectedPage == page)
    }
}

/// Runs `place.image` with the 240 × 80 logo through the catalog, with `fill`, its centre at `at` when given.
private func placeLogo(_ workspace: inout DesignWorkspace, fill: Bool = false, at: Point? = nil) throws {
    var params: [String: JSONValue] = ["name": .string("logo.svg"), "base64": .string(svgLogo), "fill": .bool(fill)]
    if let at { (params["x"], params["y"]) = (.number(at.x), .number(at.y)) }
    _ = try DesignWorkspace.catalog.run("place.image", params: .object(params), on: &workspace)
}

/// Whether `inner` lies within `outer`, to a few ulps.
private func within(_ inner: DesignRect, _ outer: DesignRect) -> Bool {
    inner.x >= outer.x - 1e-9 && inner.y >= outer.y - 1e-9 && inner.maxX <= outer.maxX + 1e-9 && inner.maxY <= outer.maxY + 1e-9
}

/// A 240 x 80 SVG, base64.
private let svgLogo = Data(#"<svg xmlns="http://www.w3.org/2000/svg" width="240" height="80"/>"#.utf8).base64EncodedString()
