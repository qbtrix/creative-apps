// DesignNewDocumentTests.swift (document-setup DS-design): File > New on the kernel's DocumentSetup.
// `file.new` takes the setup schema and makes one page at the chosen size, its Desktop frame filled
// with the chosen background (transparent leaves it unfilled); a size past the limits refuses and
// changes nothing. Runs on Linux and macOS.
import DesignModel
import SuiteKernel
import Testing

/// `file.new` run through the catalog on `workspace` with `params`.
private func newFile(_ params: [String: JSONValue], on workspace: inout DesignWorkspace) throws {
    _ = try DesignWorkspace.catalog.run("file.new", params: .object(params), on: &workspace)
}

/// The new file's only page and its Desktop frame.
private func firstFrame(_ workspace: DesignWorkspace) -> (page: DesignPage, frame: DesignNode)? {
    guard workspace.pages.count == 1, let page = workspace.pages.first, let frame = page.nodes.first else { return nil }
    return (page, frame)
}

@Test func aStoryPresetMakesOnePageOfThatSize() throws {
    var workspace = DesignFixtures.cards
    try newFile(["width": .number(1080), "height": .number(1920)], on: &workspace)
    let made = try #require(firstFrame(workspace))
    #expect(made.page.sizeText == "1080 × 1920 pt")
    #expect(made.page.nodes.count == 1)
    #expect(made.frame.kind == .frame)
    #expect(made.frame.frame == DesignRect(x: 0, y: 0, width: 1080, height: 1920))
    #expect(workspace.documentURL == nil)
    #expect(workspace.undoActionName == "Undo New File")
}

@Test func whiteIsTheDefaultBackground() throws {
    var workspace = DesignWorkspace()
    try newFile(["width": .number(800), "height": .number(600)], on: &workspace)
    let frame = try #require(firstFrame(workspace)).frame
    #expect(frame.fill == .white)
    #expect(frame.gradient == nil)
}

@Test func transparentLeavesTheFrameUnfilled() throws {
    var workspace = DesignWorkspace()
    try newFile(["width": .number(1080), "height": .number(1080), "background": .string("transparent")], on: &workspace)
    let frame = try #require(firstFrame(workspace)).frame
    guard case .solid(let color) = frame.fill(in: Rect(minX: 0, minY: 0, maxX: 1080, maxY: 1080)) else {
        Issue.record("a transparent frame is a solid fill")
        return
    }
    #expect(color.a == 0)
}

@Test func aColourBackgroundFillsTheFrame() throws {
    var workspace = DesignWorkspace()
    try newFile(["width": .number(640), "height": .number(480), "background": .string("#336699")], on: &workspace)
    let frame = try #require(firstFrame(workspace)).frame
    #expect(frame.fill == DesignColor(0x33, 0x66, 0x99))
    #expect(frame.gradient == nil)
}

@Test func otherUnitsReachThePageAsPixels() throws {
    var workspace = DesignWorkspace()
    try newFile(["width": .number(2), "height": .number(1), "unit": .string("in"), "resolution": .number(72)], on: &workspace)
    #expect(try #require(firstFrame(workspace)).page.sizeText == "144 × 72 pt")
}

@Test func aSizePastTheLimitRefusesAndChangesNothing() {
    var workspace = DesignFixtures.cards
    let before = workspace.pages
    #expect(throws: CatalogError.self) { try newFile(["width": .number(20_000), "height": .number(100)], on: &workspace) }
    #expect(workspace.pages == before)
}

@Test func undoPutsTheOldFileBack() throws {
    var workspace = DesignFixtures.cards
    let before = workspace.pages
    try newFile(["width": .number(1080), "height": .number(1920), "background": .string("transparent")], on: &workspace)
    workspace.undo()
    #expect(workspace.pages == before)
    workspace.redo()
    #expect(firstFrame(workspace)?.page.sizeText == "1080 × 1920 pt")
}

@Test func aLiveNewFileTakesTheSetupAndAnyOtherFileRefuses() {
    var fresh = DesignWorkspace()
    fresh.newFile()
    let shaped = DesignHeadless(fresh).shapingNewFile(DocumentSetup(width: 393, height: 852))
    #expect(shaped.flatMap { firstFrame($0.workspace) }?.page.sizeText == "393 × 852 pt")
    #expect(DesignHeadless(DesignFixtures.cards).shapingNewFile(DocumentSetup(width: 393, height: 852)) == nil)
}

