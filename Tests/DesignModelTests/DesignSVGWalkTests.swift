// DesignSVGWalkTests.swift: MJ14 (packet design-export, Journey step 4; DE-5), the SVG walk
// through the workspace on the Linux gate: the SVG of Desktop on `cards` equals the reference
// literal (QD-V8); hiding B drops its element and nothing else changes; a text "A & B <C>" is
// escaped; the page's SVG on `twoPages`' Mobile has `viewBox="0 0 390 844"` and one <g> for
// Phone with a clipPath. Runs on Linux and macOS.
import DesignModel
import Foundation
import Testing

@Suite struct DesignSVGWalkTests {
    private let desktop = DesignExportItem(nodeID: "node-1", fileName: "Desktop.svg", width: 1440, height: 1024,
                                           pixelWidth: 1440, pixelHeight: 1024)
    private let bLine = "      <rect x=\"300\" y=\"140\" width=\"200\" height=\"80\" fill=\"#d9d9d9\"/>\n"

    @Test func testDocumentWalk() throws {
        var workspace = DesignFixtures.cards
        workspace.useServices(.live)
        let reference = try workspace.exportSVG(desktop)
        #expect(reference == DesignSVGTests.desktopReference)

        // Hiding B drops exactly its line.
        try workspace.toggleNodeFlag("node-3", .hidden)
        let hidden = try workspace.exportSVG(desktop)
        #expect(hidden == reference.replacingOccurrences(of: bLine, with: ""))
        #expect(hidden != reference)

        // Text is escaped.
        try workspace.setText("node-5", "A & B <C>")
        let escaped = try workspace.exportSVG(desktop)
        #expect(escaped.contains(">A &amp; B &lt;C&gt;</text>"))
        #expect(!escaped.contains("A & B"))

        // The page's SVG on twoPages' Mobile.
        var two = DesignFixtures.twoPages
        two.useServices(.live)
        two.selectPage("page-2")
        let plan = try two.exportPlan(DesignExportOptions(format: .svg, scope: .page), existing: [])
        let page = try #require(plan.first)
        let text = try two.exportSVG(page)
        #expect(text.hasPrefix("<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 390 844\""))
        #expect(text.components(separatedBy: "<g clip-path=\"url(#clip-node-11)\">").count == 2)
        #expect(text.contains("<clipPath id=\"clip-node-11\">"))
    }
}
