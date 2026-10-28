// HaloTextLayoutTests.swift (text-style TS-10, slice TS-halo): a Halo text layer off the standard face, or of more
// than one line, is set by the kernel's layout, so the viewer and the render draw the same lines. Measured with a
// fixed face (each grapheme 0.5 em, ascent 0.8 em, descent 0.2 em): two lines sit a line height apart, centre leads
// the shorter line in, tracking widens the run, and a one-line layer at the standard face keeps its old draw. The
// rows' gestures, run on a text layer, set its face and paragraph as one step each.
// Linux and macOS.
import HaloModel
import SuiteKernel
import Testing

@Suite struct HaloTextLayoutTests {
    /// `string` at 100 px in the standard face with `change` applied.
    static func content(_ string: String, _ change: (inout TextStyle) -> Void = { _ in }) -> HaloTextContent {
        var style = TextStyle.standard
        change(&style)
        return HaloTextContent(string: string, fontSize: 100, style: style)
    }

    /// The fixed face at 100 px: every grapheme 50 wide, ascent 80, descent 20.
    static func fixed(_ graphemes: [String]) -> (advances: [Double], ascent: Double, descent: Double) {
        (graphemes.map { _ in 50 }, 80, 20)
    }

    @Test func onlyAStyledOrMultiLineLayerTakesTheLayout() {
        #expect(!Self.content("Title").drawsThroughLayout)
        #expect(Self.content("Title\nCard").drawsThroughLayout)
        #expect(Self.content("Title") { $0.italic = true }.drawsThroughLayout)
        #expect(Self.content("Title") { $0.weight = 700 }.drawsThroughLayout)
        #expect(Self.content("Title") { $0.paragraph.tracking = 50 }.drawsThroughLayout)
        #expect(Self.content("Title") { $0.paragraph.alignment = .center }.drawsThroughLayout)
    }

    @Test func twoLinesSitALineHeightApart() throws {
        let setting = try #require(Self.content("Title\nCard") { $0.paragraph.lineHeight = 1.5 }.laidOut(advances: Self.fixed))
        #expect(setting.lines.map(\.text) == ["Title", "Card"])
        #expect(setting.lines.map(\.baseline) == [80, 230])
        #expect(setting.width == 250)
        #expect(setting.height == 250)
    }

    @Test func centreLeadsTheShorterLineIn() throws {
        let setting = try #require(Self.content("Title\nCard") { $0.paragraph.alignment = .center }.laidOut(advances: Self.fixed))
        #expect(setting.lines.map(\.x) == [0, 25])
    }

    @Test func trackingWidensTheRun() throws {
        let plain = try #require(Self.content("Title\nCard").laidOut(advances: Self.fixed))
        let tracked = try #require(Self.content("Title\nCard") { $0.paragraph.tracking = 50 }.laidOut(advances: Self.fixed))
        #expect(Self.content("Title") { $0.paragraph.tracking = 50 }.trackingPoints == 5)
        #expect(tracked.width > plain.width)
    }

    @Test func theRowsGesturesSetTheLayersStyle() throws {
        var project = HaloProject(services: .fake, document: try #require(HaloFixtures.project("empty")))
        project.newLayer(.text)
        project.setText("Title\nCard")
        for intent: TextIntent in [.font(family: "Avenir", weight: 700, italic: nil), .tracking(50, drag: nil), .alignment(.center)] {
            project.runText(intent)
        }
        let style = try #require(project.selectedText?.style)
        #expect(style.family == "Avenir" && style.weight == 700)
        #expect(style.paragraph.tracking == 50 && style.paragraph.alignment == .center)
        #expect(project.undoTitle == "Undo Alignment")
    }
}
