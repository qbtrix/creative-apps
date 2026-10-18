// DesignSVGTests.swift: QD-V8, the SVG text of Design layers (Live/DesignSVG.swift, DE-5).
// The SVG of DesignFixtures.cards' Desktop frame equals the reference literal byte for byte;
// one element per visible layer in paint order; a clipPath on every frame; escaped text;
// opacity, stroke, stroke-width and rx only when not the SVG default; coordinates relative
// to the box. Runs on Linux and macOS.
@testable import DesignModel
import Foundation
import Testing

@Suite struct DesignSVGTests {
    /// The Desktop frame of `cards` as File > Export writes it (QD-V8). Hidden is left out.
    static let desktopReference = """
        <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1440 1024" width="1440" height="1024">
          <defs><clipPath id="clip"><rect width="1440" height="1024"/></clipPath></defs>
          <g clip-path="url(#clip)">
            <clipPath id="clip-node-1"><rect x="0" y="0" width="1440" height="1024"/></clipPath>
            <g clip-path="url(#clip-node-1)">
              <rect x="0" y="0" width="1440" height="1024" fill="#ffffff"/>
              <rect x="100" y="100" width="100" height="80" fill="#d9d9d9"/>
              <rect x="300" y="140" width="200" height="80" fill="#d9d9d9"/>
              <rect x="700" y="100" width="100" height="120" fill="#d9d9d9"/>
              <text x="100" y="56" font-size="16" font-family="system-ui" fill="#000000">Title</text>
              <g>
                <ellipse cx="950" cy="450" rx="50" ry="50" fill="#d9d9d9"/>
                <ellipse cx="1150" cy="450" rx="50" ry="50" fill="#d9d9d9"/>
              </g>
              <rect x="400" y="600" width="100" height="100" fill="#d9d9d9"/>
            </g>
          </g>
        </svg>

        """

    private func rect(_ x: Double, _ y: Double, _ w: Double, _ h: Double) -> DesignRect {
        DesignRect(x: x, y: y, width: w, height: h)
    }

    /// The document of one layer in its own box, as LiveExport.svg writes it.
    private func svg(_ node: DesignNode) -> String {
        DesignSVG.document([node], box: node.frame, clip: node.kind == .frame)
    }

    @Test func desktopEqualsTheReference() throws {
        let page = try #require(DesignFixtures.cards.selectedPage)
        #expect(try LiveExport().svg(for: "node-1", on: page) == Self.desktopReference)
    }

    @Test func oneElementPerVisibleLayerHiddenLeftOut() throws {
        let page = try #require(DesignFixtures.cards.selectedPage)
        let text = try LiveExport().svg(for: "node-1", on: page)
        #expect(!text.contains("x=\"600\" y=\"600\""), "the hidden rectangle was written")
        #expect(text.components(separatedBy: "<rect ").count - 1 == 7)  // clip, frame, A, B, C, Locked, box clip
        #expect(text.components(separatedBy: "<ellipse ").count - 1 == 2)
        let hiddenGroup = DesignNode(id: "g", name: "G", kind: .group, frame: rect(0, 0, 10, 10),
                                     children: [DesignNode(id: "r", name: "R", kind: .rectangle, frame: rect(0, 0, 5, 5))],
                                     isHidden: true)
        #expect(!DesignSVG.document([hiddenGroup], box: rect(0, 0, 10, 10), clip: false).contains("<rect"))
    }

    @Test func coordinatesAreRelativeToTheBox() {
        let a = DesignNode(id: "a", name: "A", kind: .rectangle, frame: rect(100, 100, 100, 80))
        #expect(svg(a) == """
            <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 80" width="100" height="80">
              <rect x="0" y="0" width="100" height="80" fill="#d9d9d9"/>
            </svg>

            """)
        let e = DesignNode(id: "e", name: "E", kind: .ellipse, frame: rect(50, 60, 20, 10))
        #expect(svg(e).contains("<ellipse cx=\"10\" cy=\"5\" rx=\"10\" ry=\"5\" fill=\"#d9d9d9\"/>"))
    }

    @Test func framesClipTheirChildren() {
        let child = DesignNode(id: "c", name: "C", kind: .rectangle, frame: rect(15, 25, 10, 10))
        let frame = DesignNode(id: "f", name: "F", kind: .frame, frame: rect(10, 20, 50, 40), children: [child],
                               cornerRadius: 8)
        let text = svg(frame)
        #expect(text.contains("<clipPath id=\"clip-f\"><rect x=\"0\" y=\"0\" width=\"50\" height=\"40\" rx=\"8\"/></clipPath>"))
        #expect(text.contains("<g clip-path=\"url(#clip-f)\">"))
        #expect(text.contains("<rect x=\"5\" y=\"5\" width=\"10\" height=\"10\" fill=\"#d9d9d9\"/>"))
    }

    @Test func textIsEscaped() {
        let t = DesignNode(id: "t", name: "T", kind: .text, frame: rect(0, 0, 100, 20), text: "A & B <C> \"d\"")
        #expect(svg(t).contains(">A &amp; B &lt;C&gt; &quot;d&quot;</text>"))
        var styled = t
        styled.textStyle = DesignTextStyle(family: "Fira \"Sans\"", size: 20, weight: 700, alignment: .center)
        #expect(svg(styled).contains(
            "<text x=\"50\" y=\"20\" font-size=\"20\" font-family=\"Fira &quot;Sans&quot;\" font-weight=\"700\" text-anchor=\"middle\""))
    }

    @Test func defaultsAreOmittedAndOthersWritten() {
        let plain = DesignNode(id: "p", name: "P", kind: .rectangle, frame: rect(0, 0, 10, 10), stroke: .default)
        let plainText = svg(plain)
        #expect(plainText.contains("<rect x=\"0\" y=\"0\" width=\"10\" height=\"10\" fill=\"#d9d9d9\" stroke=\"#000000\"/>"))
        for attribute in ["opacity=", "stroke-width=", "rx="] { #expect(!plainText.contains(attribute), "\(attribute) written at its default") }
        let styled = DesignNode(id: "s", name: "S", kind: .rectangle, frame: rect(0, 0, 10, 10), cornerRadius: 3,
                                opacity: 0.5, stroke: DesignStroke(color: DesignColor(255, 0, 16), width: 2.5))
        #expect(svg(styled).contains(
            "<rect x=\"0\" y=\"0\" width=\"10\" height=\"10\" rx=\"3\" fill=\"#d9d9d9\" stroke=\"#ff0010\" stroke-width=\"2.5\" opacity=\"0.5\"/>"))
        let group = DesignNode(id: "g", name: "G", kind: .group, frame: rect(0, 0, 10, 10), opacity: 0.25)
        #expect(svg(group).contains("<g opacity=\"0.25\">"))
        let noStroke = DesignNode(id: "n", name: "N", kind: .ellipse, frame: rect(0, 0, 10, 10),
                                  stroke: DesignStroke(color: .black, width: 0))
        #expect(!svg(noStroke).contains("stroke"))
    }
}
