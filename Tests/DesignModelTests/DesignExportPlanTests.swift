// DesignExportPlanTests.swift: the export contract (DesignExport+Kernel, DE-2), shape half: the
// signatures exist, both service sets hold LiveExport, exportTargetIDs names the right layers for
// each scope, the remembered options are not a history step, and the stub plan gives the blueprint
// FakeExport's items on DesignFixtures.cards (Desktop node-1 holding A node-2, B node-3, C node-4,
// Title node-5, Pair node-6, Locked node-9, Hidden node-10). Runs on Linux and macOS.
// Rules half: DE-1 adds it disabled, DE-3 turns it on.
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
}
