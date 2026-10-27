// DesignPlaceTests.swift (placed-images PD-1 written, PD-5 turns on): MJ-PD, the Model walk of a picture
// in a rectangle or frame. A node keeps the kernel's `PlacedAsset` and a focus point; its frame is the
// picture's box. The schema tests and the adapter's real reads run now; the place commands' walk is
// disabled by name until PD-5 builds the bodies of DesignPlace+Kernel. Runs on Linux and macOS.
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

    @Test(.disabled("PD-5 builds DesignPlace+Kernel's bodies"))
    func landsInSelectedFrame() throws {
        var workspace = try opened([node(picture: nil)])
        let id = try workspace.insertPlaced(asset, PlacedImage(assetID: "asset-1", box: Rect(minX: 0, minY: 0, maxX: 300, maxY: 200)), name: "Place")
        #expect(workspace.selectedPage?.nodes.first?.children.map(\.id) == [id])
        #expect(workspace.treeNode(id)?.name == "photo")
    }

    @Test(.disabled("PD-5 builds DesignPlace+Kernel's bodies"))
    func fillTakesTheFrame() throws {
        var workspace = try opened([node(picture: nil)])
        #expect(workspace.placeFillBox == box)
        try workspace.setPlaced(PlacedImage(assetID: "asset-1", box: box), asset: asset, name: "Place", drag: nil)
        #expect(workspace.treeNode("node-1")?.frame == rc(100, 100, 400, 400))
        #expect(workspace.treeNode("node-1")?.placedAsset == asset)
        #expect(workspace.selectedPage?.nodes.count == 1)
    }

    @Test(.disabled("PD-5 builds DesignPlace+Kernel's bodies"), arguments: [DesignNodeKind.ellipse, .text])
    func fillRefusesOtherKinds(_ kind: DesignNodeKind) throws {
        #expect(try opened([node(kind, picture: nil)]).placeFillBox == nil)
    }

    @Test(.disabled("PD-5 builds DesignPlace+Kernel's bodies"))
    func lockedFrameRefuses() throws {
        var workspace = try opened([node()])
        try workspace.setNodeLocked("node-1", true)
        #expect(workspace.placeFillBox == nil)
        #expect(throws: (any Error).self) {
            try workspace.setPlaced(PlacedImage(assetID: "asset-1", box: box, focus: centre), asset: nil, name: "Focus", drag: nil)
        }
    }

    @Test(.disabled("PD-5 builds DesignPlace+Kernel's bodies"))
    func focusDragIsOneStep() throws {
        var workspace = try opened([node()])
        for x in stride(from: 0.2, through: 0.8, by: 0.1) {
            try workspace.setPlaced(PlacedImage(assetID: "asset-1", box: box, focus: Point(x: x, y: 0.5)), asset: nil, name: "Focus", drag: "pan")
        }
        workspace.undo()
        #expect(workspace.treeNode("node-1")?.placedFocus == left)
    }

    @Test(.disabled("PD-5 builds DesignPlace+Kernel's bodies"))
    func resetSizeRestoresThreeTwo() throws {
        var workspace = try opened([node()])
        let selection = try #require(workspace.placedSelection)
        let reset = PlaceRules.resetBox(selection.image, natural: selection.asset.natural)
        try workspace.setPlaced(PlacedImage(assetID: "asset-1", box: reset, focus: left), asset: nil, name: "Reset Size", drag: nil)
        let frame = try #require(workspace.treeNode("node-1")?.frame)
        #expect(frame.width * 2 == frame.height * 3)
    }
}
