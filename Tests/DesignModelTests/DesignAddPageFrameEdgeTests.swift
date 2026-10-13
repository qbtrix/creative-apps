// DesignAddPageFrameEdgeTests.swift: adversarial checks on the Desktop frame Add Page
// seeds (#265): the frame takes drawing like New File's, survives save and reopen,
// never reuses an id across undo, redo and reopened files, and every page in a long
// random run holds its own. Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import DesignModel
import Testing

private func allIDs(_ nodes: [DesignNode]) -> [String] { nodes.flatMap { [$0.id] + allIDs($0.children) } }

@Test func aRectangleDrawnOnAnAddedPageLandsInsideItsDesktopFrame() throws {
    var workspace = openDesign()
    workspace.addPage()
    workspace.gesture(.rectangle, pt(40, 40), pt(200, 160))
    let page = try #require(workspace.selectedPage)
    #expect(page.id == "page-2")
    #expect(page.nodes.map(\.id) == ["node-2"])
    #expect(page.nodes.first?.children.map(\.id) == ["node-3"])
    #expect(workspace.selectedNodeID == "node-3")
    #expect(workspace.pages.first?.nodes.first?.children.isEmpty == true)
}

@Test func clickingTheAddedPageSelectsItsDesktopFrame() {
    var workspace = openDesign()
    workspace.addPage()
    #expect(workspace.hitTest(pt(720, 512)) == "node-2")
    #expect(workspace.hitTest(pt(-5, -5)) == nil)
}

@Test func redoingAddPageBringsBackTheSameFrameAndANewAddNeverReusesIt() throws {
    var workspace = openDesign()
    workspace.addPage()
    let added = try #require(workspace.selectedPage)
    workspace.undo()
    workspace.redo()
    #expect(workspace.selectedPage == added)
    workspace.undo()
    workspace.addPage()
    let again = try #require(workspace.selectedPage)
    #expect(again.id != added.id)
    #expect(again.nodes.map(\.id) != added.nodes.map(\.id))
    #expect(again.nodes.map(\.name) == ["Desktop"])
}

@Test func anAddedPagesFrameSurvivesSaveAndReopen() throws {
    var workspace = openDesign()
    workspace.addPage()
    let pages = workspace.pages
    var reopened = DesignWorkspace()
    try reopened.open(workspace.fileData())
    #expect(reopened.pages == pages)
    reopened.addPage()
    #expect(reopened.pages.last?.id == "page-3")
    #expect(reopened.pages.last?.nodes.map(\.id) == ["node-3"])
}

@Test func addPageOverAFileWithForeignIDsTakesAFreshFrameID() throws {
    // A file whose page and frame ids came from somewhere other than the counters.
    let saved = String(decoding: try openDesign().fileData(), as: UTF8.self)
    let foreign = saved.replacingOccurrences(of: "\"page-1\"", with: "\"intro\"")
        .replacingOccurrences(of: "\"node-1\"", with: "\"hero\"")
    var workspace = DesignWorkspace()
    try workspace.open(Data(foreign.utf8))
    #expect(workspace.pages.map(\.id) == ["intro"])
    workspace.addPage()
    let page = try #require(workspace.selectedPage)
    #expect(page.id == "page-1" && page.name == "Page 1")
    #expect(page.nodes.map(\.id) == ["node-1"])
    #expect(workspace.pages.first?.nodes.map(\.id) == ["hero"])
}

@Test(arguments: [UInt64(3), 11, 99, 4096])
func everyPageInARandomRunHoldsItsOwnDesktopFrameAndIDsStayUnique(seed: UInt64) throws {
    var rng = SeededRNG(seed: seed)
    var workspace = openDesign()
    var seeded: [String: String] = ["page-1": "node-1"]
    for _ in 0..<200 {
        switch rng.next(below: 6) {
        case 0:
            workspace.addPage()
            let page = try #require(workspace.selectedPage)
            let frame = try #require(page.nodes.first)
            #expect(page.nodes.count == 1 && frame.name == "Desktop" && frame.kind == .frame)
            seeded[page.id] = frame.id
        case 1: workspace.undo()
        case 2: workspace.redo()
        case 3:
            if let page = workspace.pages.randomElement(using: &rng), workspace.canDeletePage {
                try? workspace.deletePage(page.id)
            }
        default:
            if let page = workspace.pages.randomElement(using: &rng) { workspace.selectPage(page.id) }
            let x = Double(rng.next(below: 1200)), y = Double(rng.next(below: 900))
            workspace.gesture(.rectangle, pt(x, y), pt(x + 40, y + 30))
        }
        let ids = workspace.pages.flatMap { allIDs($0.nodes) }
        #expect(Set(ids).count == ids.count)
        #expect(Set(workspace.pages.map(\.id)).count == workspace.pages.count)
    }
    // Each page still carries the frame it was seeded with, unless the page went away.
    for page in workspace.pages {
        if let frame = seeded[page.id] { #expect(page.nodes.contains { $0.id == frame && $0.name == "Desktop" }) }
    }
}

/// SplitMix64, so each seed replays the same run.
private struct SeededRNG: RandomNumberGenerator {
    var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func next(below bound: Int) -> Int { Int(next() % UInt64(Swift.max(bound, 1))) }
}
