// DesignExportPlanTests.swift: the export contract (DesignExport+Kernel, DE-2), shape half: the
// signatures exist, both service sets hold LiveExport, exportTargetIDs names the right layers for
// each scope, the remembered options are not a history step, and the stub plan gives the blueprint
// FakeExport's items on DesignFixtures.cards (Desktop node-1 holding A node-2, B node-3, C node-4,
// Title node-5, Pair node-6, Locked node-9, Hidden node-10). Runs on Linux and macOS.
// Rules half (DE-3): names unique against the folder and within the plan, pixels at whole points times
// the clamped scale (PNG only), the refusal that names its cause, locked layers export, hidden ones
// don't, and the page item is the page's size.
import DesignModel
import Testing

@Suite struct DesignExportPlanTests {
    let cards = DesignFixtures.cards
    var page: DesignPage { cards.selectedPage ?? DesignPage(id: "none", name: "None", frameWidth: 1, frameHeight: 1) }
    let desktop = DesignExportItem(nodeID: "node-1", fileName: "Desktop.png", width: 1440, height: 1024, pixelWidth: 1440, pixelHeight: 1024)

    /// What `body` threw as a refusal; nil when it returned (or threw something else).
    private func refusal(_ body: () throws -> Void) -> DesignRefusal? {
        do { try body() } catch { return error as? DesignRefusal }
        return nil
    }

    @Test func signaturesAreAsTheContractWrites() {
        let export: any ExportPlanning = LiveExport()
        let _: ([String], DesignPage) -> String? = export.exportHelp(_:on:)
        let _: ([String], DesignPage, DesignExportFormat, Int, Set<String>) throws(DesignRefusal) -> [DesignExportItem]
            = export.plan(_:on:format:scale:existing:)
        let _: (String, DesignPage) throws(DesignRefusal) -> String = export.svg(for:on:)
        let _: (DesignExportScope) -> [String] = cards.exportTargetIDs(_:)
        let _: (DesignExportOptions) -> String? = cards.exportHelp(_:)
        let _: (DesignExportOptions, Set<String>) throws(DesignRefusal) -> [DesignExportItem] = cards.exportPlan(_:existing:)
        let _: (DesignExportItem) throws(DesignRefusal) -> String = cards.exportSVG(_:)
        let _: DesignExportOptions = cards.exportDefaults
        var remembered = cards
        remembered.rememberExport(DesignExportOptions(format: .pdf, scale: 1, scope: .selection))
        #expect(remembered.exportDefaults.format == .pdf)
        #expect(DesignExportScope.allCases == [.selection, .frame, .page])
    }

    @Test func bothServiceSetsHoldLiveExport() {
        #expect(DesignServices.fake.export is LiveExport)
        #expect(DesignServices.live.export is LiveExport)
    }

    @Test func targetIDsFollowTheScope() {
        var workspace = cards
        workspace.selectItem("node-2")
        #expect(workspace.exportTargetIDs(.selection) == ["node-2"])
        #expect(workspace.exportTargetIDs(.frame) == ["node-1"])
        workspace.deselect()
        #expect(workspace.exportTargetIDs(.selection) == [])
        #expect(workspace.exportTargetIDs(.frame) == ["node-1"])
        #expect(workspace.exportTargetIDs(.page) == ["page-1"])
        workspace.selectItem("node-10")
        workspace.toggleSelection("node-2")
        #expect(workspace.selectedNodeIDs == ["node-10", "node-2"])
        #expect(workspace.exportTargetIDs(.selection) == ["node-2"])
        #expect(DesignWorkspace().exportTargetIDs(.frame) == [])
    }

    @Test func aTopLevelShapeFallsBackToTheFrames() throws {
        var workspace = cards
        let id = try workspace.addNode(.rectangle, frame: rc(10, 10, 50, 50), in: nil)
        #expect(workspace.selectedNodeID == id)
        #expect(workspace.exportTargetIDs(.frame) == ["node-1"])
        #expect(workspace.exportTargetIDs(.selection) == [id])
    }

    @Test func rememberedOptionsAreNotAHistoryStep() {
        var workspace = cards
        #expect(workspace.exportDefaults == DesignExportOptions(format: .png, scale: 1, scope: .frame))
        let (name, undo) = (workspace.undoActionName, workspace.canUndo)
        workspace.rememberExport(DesignExportOptions(format: .svg, scale: 2, scope: .page))
        #expect(workspace.exportDefaults == DesignExportOptions(format: .svg, scale: 2, scope: .page))
        #expect(workspace.undoActionName == name && workspace.canUndo == undo)
        #expect(name == "Undo" && !undo)
    }

    @Test func thePlanIsTheFramesAtTheScale() throws {
        #expect(try cards.exportPlan(DesignExportOptions(), existing: []) == [desktop])
        let twice = try cards.exportPlan(DesignExportOptions(scale: 2), existing: [])
        #expect(twice.map(\.pixelWidth) == [2880] && twice.map(\.pixelHeight) == [2048])
        #expect(twice.map(\.width) == [1440] && twice.map(\.height) == [1024])
        let svg = try cards.exportPlan(DesignExportOptions(format: .svg, scale: 2), existing: [])
        #expect(svg.map(\.fileName) == ["Desktop.svg"] && svg.map(\.pixelWidth) == [1440])
        let whole = try cards.exportPlan(DesignExportOptions(scope: .page), existing: [])
        #expect(whole == [DesignExportItem(nodeID: "page-1", fileName: "Page 1.png", width: 1440, height: 1024,
                                           pixelWidth: 1440, pixelHeight: 1024)])
        var selected = cards
        selected.selectItem("node-3")
        let b = try selected.exportPlan(DesignExportOptions(scope: .selection), existing: [])
        #expect(b == [DesignExportItem(nodeID: "node-3", fileName: "B.png", width: 200, height: 80, pixelWidth: 200, pixelHeight: 80)])
    }

    @Test func helpNamesTheRefusal() {
        #expect(cards.exportHelp(DesignExportOptions()) == nil)
        #expect(cards.exportHelp(DesignExportOptions(scope: .selection)) == "Select a layer first.")
        #expect(refusal { _ = try cards.exportPlan(DesignExportOptions(scope: .selection), existing: []) } == .nothingSelected)
        var empty = openDesign()
        empty.selectItem("node-1")
        empty.deleteSelection()
        #expect(empty.selectedPage?.nodes.isEmpty == true)
        #expect(empty.exportHelp(DesignExportOptions()) == "There's nothing on this page to export.")
        #expect(refusal { _ = try empty.exportPlan(DesignExportOptions(), existing: []) } == .nothingToExport)
        #expect(DesignWorkspace().exportHelp(DesignExportOptions(scope: .page)) == "There's nothing on this page to export.")
    }

    @Test func svgIsADocumentOfTheItem() throws {
        #expect(try cards.exportSVG(desktop).hasPrefix("<svg"))
        let whole = DesignExportItem(nodeID: "page-1", fileName: "Page 1.svg", width: 1440, height: 1024, pixelWidth: 1440, pixelHeight: 1024)
        #expect(try cards.exportSVG(whole).hasPrefix("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 1440"))
        #expect(try LiveExport().svg(for: "node-2", on: page).hasPrefix("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 100"))
        #expect(refusal { _ = try LiveExport().svg(for: "nope", on: page) } == .unknownID("nope"))
        #expect(refusal { _ = try DesignWorkspace().exportSVG(desktop) } == .nothingToExport)
    }

    // MARK: Rules half (DE-3)

    /// A page holding `nodes` at the top level, 1440 × 1024.
    private func pageOf(_ nodes: [DesignNode]) -> DesignPage {
        DesignPage(id: "page-x", name: "Page", frameWidth: 1440, frameHeight: 1024, nodes: nodes)
    }

    private func card(_ id: String, _ name: String = "Card", hidden: Bool = false) -> DesignNode {
        DesignNode(id: id, name: name, kind: .frame, frame: rc(0, 0, 100, 50), isHidden: hidden)
    }

    @Test func namesUniqueAgainstFolder() throws {
        var workspace = cards
        workspace.selectItem("node-2")
        workspace.toggleSelection("node-3")
        let plan = try workspace.exportPlan(DesignExportOptions(scope: .selection), existing: ["a.png", "B.svg"])
        #expect(plan.map(\.fileName) == ["A 2.png", "B.png"])
        let frame = try cards.exportPlan(DesignExportOptions(), existing: ["Desktop.png", "Desktop 2.png"])
        #expect(frame.map(\.fileName) == ["Desktop 3.png"])
        let whole = try cards.exportPlan(DesignExportOptions(format: .svg, scope: .page), existing: ["Page 1.svg"])
        #expect(whole.map(\.fileName) == ["Page 1 2.svg"])
    }

    @Test func namesUniqueWithinPlan() throws {
        let twins = pageOf([card("c1"), card("c2"), card("c3", "Card 2")])
        let plan = try LiveExport().plan([], on: twins, format: .png, scale: 1, existing: [])
        #expect(plan.map(\.fileName) == ["Card.png", "Card 2.png", "Card 2 2.png"])
        #expect(Set(plan.map { $0.fileName.lowercased() }).count == plan.count)
    }

    @Test func svgIgnoresScale() throws {
        for format in [DesignExportFormat.svg, .pdf] {
            let plan = try cards.exportPlan(DesignExportOptions(format: format, scale: 3), existing: [])
            #expect(plan.map(\.pixelWidth) == [1440] && plan.map(\.pixelHeight) == [1024])
            #expect(plan.map(\.fileName) == ["Desktop.\(format.rawValue)"])
        }
        let png = try cards.exportPlan(DesignExportOptions(format: .png, scale: 3), existing: [])
        #expect(png.map(\.pixelWidth) == [4320] && png.map(\.pixelHeight) == [3072])
    }

    @Test func scaleClamps() throws {
        let odd = pageOf([DesignNode(id: "o", name: "Odd", kind: .frame, frame: rc(0, 0, 100.4, 80.6))])
        let at = { (scale: Int) throws -> [Int] in
            let item = try LiveExport().plan([], on: odd, format: .png, scale: scale, existing: [])
            return item.flatMap { [$0.pixelWidth, $0.pixelHeight] }
        }
        #expect(try at(0) == [100, 81])
        #expect(try at(-4) == [100, 81])
        #expect(try at(2) == [200, 162])
        #expect(try at(3) == [300, 243])
        #expect(try at(9) == [300, 243])
        let whole = try cards.exportPlan(DesignExportOptions(scale: 9, scope: .page), existing: [])
        #expect(whole.map(\.pixelWidth) == [4320])
    }

    @Test func refusalNamesTheCause() {
        let export = LiveExport()
        #expect(refusal { _ = try export.plan(["node-10"], on: page, format: .png, scale: 1, existing: []) } == .nothingSelected)
        #expect(refusal { _ = try export.plan(["nope"], on: page, format: .png, scale: 1, existing: []) } == .nothingSelected)
        #expect(refusal { _ = try export.plan([], on: pageOf([]), format: .png, scale: 1, existing: []) } == .nothingToExport)
        #expect(refusal { _ = try export.plan([], on: pageOf([card("h", hidden: true)]), format: .svg, scale: 1, existing: []) }
                == .nothingToExport)
        #expect(export.exportHelp(["node-10"], on: page) == "Select a layer first.")
        #expect(export.exportHelp([], on: pageOf([])) == "There's nothing on this page to export.")
        #expect(export.exportHelp(["node-2"], on: page) == nil)
    }

    @Test func lockedExports() throws {
        var workspace = cards
        workspace.selectItem("node-9")
        #expect(workspace.exportHelp(DesignExportOptions(scope: .selection)) == nil)
        let plan = try workspace.exportPlan(DesignExportOptions(scope: .selection), existing: [])
        #expect(plan == [DesignExportItem(nodeID: "node-9", fileName: "Locked.png", width: 100, height: 100,
                                          pixelWidth: 100, pixelHeight: 100)])
    }

    @Test func hiddenLayersAreDropped() throws {
        let inner = DesignNode(id: "in", name: "Inner", kind: .rectangle, frame: rc(0, 0, 10, 10))
        let shut = DesignNode(id: "shut", name: "Shut", kind: .frame, frame: rc(0, 0, 50, 50), children: [inner], isHidden: true)
        let mixed = pageOf([card("c1"), shut])
        #expect(try LiveExport().plan([], on: mixed, format: .png, scale: 1, existing: []).map(\.nodeID) == ["c1"])
        #expect(try LiveExport().plan(["in", "c1"], on: mixed, format: .png, scale: 1, existing: []).map(\.nodeID) == ["c1"])
        #expect(refusal { _ = try LiveExport().plan(["in"], on: mixed, format: .png, scale: 1, existing: []) } == .nothingSelected)
    }

    @Test func pageIsThePage() throws {
        var workspace = cards
        _ = try workspace.addNode(.rectangle, frame: rc(1500, 1500, 300, 200), in: nil)
        #expect(workspace.selectedPage?.contentBounds != workspace.selectedPage.map { rc(0, 0, $0.frameWidth, $0.frameHeight) })
        let plan = try workspace.exportPlan(DesignExportOptions(scale: 2, scope: .page), existing: [])
        #expect(plan == [DesignExportItem(nodeID: "page-1", fileName: "Page 1.png", width: 1440, height: 1024,
                                          pixelWidth: 2880, pixelHeight: 2048)])
        var empty = openDesign()
        empty.selectItem("node-1")
        empty.deleteSelection()
        let bare = try empty.exportPlan(DesignExportOptions(format: .svg, scope: .page), existing: [])
        #expect(bare.map(\.width) == [1440] && bare.map(\.height) == [1024])
    }

    @Test func framesOnlyWhenNoIDs() throws {
        let loose = DesignNode(id: "r", name: "Loose", kind: .rectangle, frame: rc(0, 0, 10, 10))
        let plan = try LiveExport().plan([], on: pageOf([card("c1"), loose]), format: .png, scale: 1, existing: [])
        #expect(plan.map(\.nodeID) == ["c1"])
        #expect(refusal { _ = try LiveExport().plan([], on: pageOf([loose]), format: .png, scale: 1, existing: []) } == .nothingToExport)
    }

    @Test func planAndLayersShareOneHiddenRule() throws {
        var workspace = cards
        let group = try workspace.addNode(.frame, frame: rc(10, 10, 80, 80), in: nil)
        let child = try workspace.addNode(.rectangle, frame: rc(5, 5, 10, 10), in: group)
        for hidden in [false, true] {
            try workspace.setNodeHidden(group, hidden)
            let page = try #require(workspace.selectedPage)
            #expect(page.isHiddenInTree(child) == hidden)
            #expect(workspace.isHiddenInTree(child) == page.isHiddenInTree(child))
            let refused = refusal { _ = try LiveExport().plan([child], on: page, format: .png, scale: 1, existing: []) }
            #expect((refused == .nothingSelected) == page.isHiddenInTree(child))
        }
        #expect(!page.isHiddenInTree("nope"))
    }
}
