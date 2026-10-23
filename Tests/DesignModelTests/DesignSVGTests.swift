// DesignSVGTests.swift: QD-V8, the SVG text of Design layers (Live/DesignSVG.swift, DE-5).
// The SVG of DesignFixtures.cards' Desktop frame equals the reference literal byte for byte;
// one element per visible layer in paint order; a clipPath on every frame; escaped text;
// opacity, stroke, stroke-width and rx only when not the SVG default; coordinates relative
// to the box. A gradient is a definition in frame space and a `fill="url(#g-…)"` (gradient-fill DG-5).
// A turned or mirrored layer carries `transform="rotate(d cx cy) …"` about its frame's centre (transform DT-6),
// and RJ-D15's 60 small turns under one drag token write `rotate(15 60 35)` and undo in one step.
// A shape writes its kernel path as a <path>, closed only where its contour is (shape-tools DS-6, RJ-D35).
// Runs on Linux and macOS.
@testable import DesignModel
import Foundation
import SuiteKernel
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

    /// Blue to white down the unit box: a 90° line, as `fill.angle` 90 stores it.
    private let unitDown = Fill.linear(
        stops: [GradientStop(offset: 0, color: FillColor(r: 0, g: 0, b: 1)), GradientStop(offset: 1, color: .white)],
        start: Point(x: 0.5, y: 0), end: Point(x: 0.5, y: 1))

    /// A 90° gradient writes its line in the layer's frame, relative to the box: vertical, top to bottom.
    @Test func gradientInFrameSpace() {
        let r = DesignNode(id: "r", name: "R", kind: .rectangle, frame: rect(10, 20, 200, 100), gradient: unitDown)
        let text = DesignSVG.document([r], box: rect(0, 0, 300, 200), clip: false)
        #expect(text.contains(#"<defs><linearGradient id="g-r" gradientUnits="userSpaceOnUse" x1="110" y1="20" x2="110" y2="120">"#
            + ##"<stop offset="0" stop-color="#0000ff"/><stop offset="1" stop-color="#ffffff"/></linearGradient></defs>"##))
        #expect(text.contains(#"<rect x="10" y="20" width="200" height="100" fill="url(#g-r)"/>"#))
        let e = DesignNode(id: "e", name: "E", kind: .ellipse, frame: rect(0, 0, 40, 40), gradient: unitDown)
        #expect(svg(e).contains(#"fill="url(#g-e)""#))
        #expect(svg(e).contains(#"x1="20" y1="0" x2="20" y2="40""#))
    }

    /// A text layer's gradient is defined too, and its letters fill with it.
    @Test func textGradient() {
        let t = DesignNode(id: "t", name: "T", kind: .text, frame: rect(0, 0, 100, 20), text: "Hi", gradient: unitDown)
        let text = svg(t)
        #expect(text.contains(#"<linearGradient id="g-t" gradientUnits="userSpaceOnUse" x1="50" y1="0" x2="50" y2="20">"#))
        #expect(text.contains(#"fill="url(#g-t)">Hi</text>"#))
    }

    /// `node` in a 200 × 100 box from the origin, so its coordinates are its own.
    private func placed(_ node: DesignNode) -> String {
        DesignSVG.document([node], box: rect(0, 0, 200, 100), clip: false)
    }

    /// A turned layer turns about its frame's centre; a mirror is a scale about that centre after the turn,
    /// the kernel's order; an upright, unmirrored layer writes no transform (transform DT-6).
    @Test func turnedNode() {
        var r = DesignNode(id: "r", name: "R", kind: .rectangle, frame: rect(10, 10, 100, 50))
        #expect(!placed(r).contains("transform"))
        r.rotation = 15
        #expect(placed(r).contains(##"<rect x="10" y="10" width="100" height="50" fill="#d9d9d9" transform="rotate(15 60 35)"/>"##))
        #expect(!placed(r).contains("scale("), "an unmirrored layer writes a scale")
        r.flipX = true
        #expect(placed(r).contains(#"transform="rotate(15 60 35) translate(60 35) scale(-1 1) translate(-60 -35)""#))
        (r.rotation, r.flipX, r.flipY) = (0, false, true)
        #expect(placed(r).contains(#"transform="translate(60 35) scale(1 -1) translate(-60 -35)""#))
        var e = DesignNode(id: "e", name: "E", kind: .ellipse, frame: rect(0, 0, 40, 20))
        e.rotation = -90
        #expect(placed(e).contains(##"<ellipse cx="20" cy="10" rx="20" ry="10" fill="#d9d9d9" transform="rotate(-90 20 10)"/>"##))
        var t = DesignNode(id: "t", name: "T", kind: .text, frame: rect(0, 0, 100, 20), text: "Hi")
        t.rotation = 45
        #expect(placed(t).contains(#"transform="rotate(45 50 10)">Hi</text>"#))
    }

    /// A turned frame turns its clip and its own box; its children keep theirs.
    @Test func turnedFrameKeepsItsChildren() {
        let child = DesignNode(id: "c", name: "C", kind: .rectangle, frame: rect(15, 25, 10, 10))
        var frame = DesignNode(id: "f", name: "F", kind: .frame, frame: rect(10, 20, 50, 40), children: [child])
        frame.rotation = 30
        let text = placed(frame)
        #expect(text.contains(#"<clipPath id="clip-f"><rect x="10" y="20" width="50" height="40" transform="rotate(30 35 40)"/></clipPath>"#))
        #expect(text.contains(##"<rect x="10" y="20" width="50" height="40" fill="#ffffff" transform="rotate(30 35 40)"/>"##))
        #expect(text.contains(##"<rect x="15" y="25" width="10" height="10" fill="#d9d9d9"/>"##))
    }

    /// RJ-D15 on the Model: 60 turns of 0.25° under one drag token turn the rect 15° about its centre as one
    /// step, the export writes `rotate(15 60 35)`, and one undo stands it up again.
    @Test func rotate15Job() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../RealJobs/design/rotate-15/input/one-rect.design")
        var w = DesignWorkspace()
        try w.open(Data(contentsOf: url))
        _ = try DesignWorkspace.catalog.run("edit.select", params: .object(["ids": .array([.string("node-2")])]), on: &w)
        let turn = JSONValue.object(["degrees": .number(0.25), "drag": .string("knob")])
        for _ in 0..<60 { _ = try DesignWorkspace.catalog.run("transform.rotate", params: turn, on: &w) }
        #expect(w.treeNode("node-2")?.rotation == 15)
        #expect(w.treeNode("node-2")?.frame == rect(10, 10, 100, 50))
        let files = try DesignHeadless(w).export("svg", options: .object([:]))
        #expect(files.count == 1)
        let exported = String(decoding: files.first?.data ?? Data(), as: UTF8.self)
        #expect(exported.contains(#"transform="rotate(15 60 35)""#))
        _ = try DesignWorkspace.catalog.run("edit.undo", params: .object([:]), on: &w)
        #expect(w.treeNode("node-2")?.rotation == 0)
    }

    /// A shape writes its kernel path, not its box (shape-tools DS-6): a star is closed with Z, a line stays open.
    @Test func shapePath() {
        var star = DesignNode(id: "s", name: "Star", kind: .shape, frame: rect(10, 0, 100, 100))
        star.shape = .defaults(.star)
        let closed = placed(star)
        #expect(!closed.contains("<rect"), "a shape wrote its box")
        #expect(closed.contains(##"<path d="M60 0 L"##) && closed.contains(##" Z" fill="#d9d9d9"/>"##))
        var line = DesignNode(id: "l", name: "Line", kind: .shape, frame: rect(0, 0, 100, 50))
        line.shape = .defaults(.line)
        let open = placed(line)
        #expect(open.contains(#"<path d="M"#) && !open.contains("Z"), "an open line was closed")
    }

    /// RJ-D35 on the Model: shape.draw puts a five-point star in blank.design's frame; it saves and reopens as a
    /// shape with the same spec, and the export writes its path: 10 vertices, the first at the top centre (50, 0).
    @Test func starBadgeJob() throws {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
            .appendingPathComponent("../RealJobs/design/star-badge/input/blank.design")
        var w = DesignWorkspace()
        try w.open(Data(contentsOf: url))
        let draw = JSONValue.object(["kind": .string("star"), "points": .number(5), "innerRatio": .number(0.5),
                                     "x": .number(0), "y": .number(0), "w": .number(100), "h": .number(100)])
        _ = try DesignWorkspace.catalog.run("shape.draw", params: draw, on: &w)
        let spec = ShapeIntent.innerRatio(0.5).applied(to: ShapeIntent.points(5).applied(to: .defaults(.star)))
        var reopened = DesignWorkspace()
        try reopened.open(try w.fileData())
        #expect(reopened.treeNode("node-2")?.kind == .shape && reopened.treeNode("node-2")?.shape == spec)
        let files = try DesignHeadless(reopened).export("svg", options: .object([:]))
        let exported = String(decoding: files.first?.data ?? Data(), as: UTF8.self)
        let d = exported.components(separatedBy: "<path d=\"").dropFirst().first?.prefix { $0 != "\"" } ?? ""
        let vertices = d.split(separator: " ").filter { $0.hasPrefix("M") || $0.hasPrefix("L") }
        #expect(vertices.count == 10 && d.hasPrefix("M50 0 L") && d.hasSuffix(" Z"), "\(d)")
    }
}
