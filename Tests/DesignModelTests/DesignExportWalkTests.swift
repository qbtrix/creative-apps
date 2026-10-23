// DesignExportWalkTests.swift: MJ13, the export plan walk (design-export packet, Journey step 3),
// on DesignFixtures.cards: the selection A, B at PNG 2x into a folder holding "A.png", the frame
// around A, the two refusals, and the page at SVG. Runs on Linux and macOS.
import DesignModel
import Testing

@Suite struct DesignExportWalkTests {
    @Test func testPlanWalk() throws {
        var workspace = DesignFixtures.cards
        workspace.selectItem("node-2")
        workspace.toggleSelection("node-3")
        let both = try workspace.exportPlan(DesignExportOptions(scale: 2, scope: .selection), existing: ["A@2x.png"])
        #expect(both == [
            DesignExportItem(nodeID: "node-2", fileName: "A@2x 2.png", width: 100, height: 80, pixelWidth: 200, pixelHeight: 160),
            DesignExportItem(nodeID: "node-3", fileName: "B@2x.png", width: 200, height: 80, pixelWidth: 400, pixelHeight: 160),
        ])

        workspace.selectItem("node-2")
        let frame = try workspace.exportPlan(DesignExportOptions(scale: 2, scope: .frame), existing: ["A.png"])
        #expect(frame == [DesignExportItem(nodeID: "node-1", fileName: "Desktop@2x.png", width: 1440, height: 1024,
                                           pixelWidth: 2880, pixelHeight: 2048)])

        workspace.deselect()
        #expect(throws: DesignRefusal.nothingSelected) {
            try workspace.exportPlan(DesignExportOptions(scope: .selection), existing: [])
        }
        #expect(workspace.exportHelp(DesignExportOptions(scope: .selection)) == "Select a layer first.")

        var empty = DesignFixtures.cards
        empty.selectItem("node-1")
        empty.deleteSelection()
        #expect(empty.selectedPage?.nodes.isEmpty == true)
        #expect(throws: DesignRefusal.nothingToExport) {
            try empty.exportPlan(DesignExportOptions(scope: .frame), existing: [])
        }

        let whole = try workspace.exportPlan(DesignExportOptions(format: .svg, scale: 2, scope: .page), existing: ["A.png"])
        #expect(whole == [DesignExportItem(nodeID: "page-1", fileName: "Page 1.svg", width: 1440, height: 1024,
                                           pixelWidth: 1440, pixelHeight: 1024)])
    }
}
