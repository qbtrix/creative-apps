// DesignTextStyleTests.swift (text-style TS-7, MJ-TS-design): Design's text layers take the kernel's text style.
// Every `.design` the repo ships opens the same and re-saves byte for byte, a text style's italic, line height and
// tracking round-trip and stay out of the file at their defaults, the seven text commands run on the selected text
// layer through Design's catalog as one undo step each (a scrub under one drag token is one), and a font change
// refits an auto-width box by re-measuring it (#3339). Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import SuiteModel
import Testing

/// The repo's `.design` files: the bundled sample, the journeys' fixtures and every real job's input.
private let files = ["Bundle/Samples/Cards.design", "UITests/Fixtures/suite/Cards.design", "UITests/Fixtures/suite/Logo.design"]
    + ["align-and-save/input/three-cards", "exact-jpeg/input/cards", "export-frames-svg/input/loose-front",
       "gradient-angle/input/background", "group-click/input/card", "history-jump/input/one-card",
       "open-sample/input/Cards", "pick-fill/input/two-shapes", "rotate-15/input/one-rect", "star-badge/input/blank"]
        .map { "Tests/RealJobs/design/\($0).design" }
private let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

/// `cards` with Title (node-5, auto width, 100,40 200 × 32, "Title" at 16 pt) selected, measured by FakeText
/// (0.5 em a grapheme), so Title measures 40 wide.
private func titled() -> DesignWorkspace {
    var services = DesignServices.fake
    services.text = FakeText()
    var workspace = DesignFixtures.cards
    workspace.useServices(services)
    workspace.selectItem("node-5")
    return workspace
}

/// Runs text command `id` with `params` on `workspace`.
private func run(_ id: String, _ params: [String: JSONValue], _ workspace: inout DesignWorkspace) throws {
    _ = try DesignWorkspace.catalog.run(id, params: .object(params), on: &workspace)
}

@Suite struct DesignTextStyleTests {
    @Test func oldFilesUnchanged() throws {
        for file in files {
            let bytes = try Data(contentsOf: root.appendingPathComponent(file))
            var opened = DesignWorkspace()
            try opened.open(bytes)
            #expect(try opened.fileData() == bytes, "\(file) changed on a re-save")
            var reopened = DesignWorkspace()
            try reopened.open(opened.fileData())
            #expect(reopened.pages == opened.pages, "\(file)")
        }
        let old = #"{"alignment":"center","family":"System","size":16,"weight":700}"#
        let style = try JSONDecoder().decode(DesignTextStyle.self, from: Data(old.utf8))
        #expect(!style.italic && style.lineHeight == 1.2 && style.tracking == 0 && style.alignment == .center)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        #expect(String(decoding: try encoder.encode(style), as: UTF8.self) == old)
    }

    @Test func newFieldsRoundTrip() throws {
        var style = DesignTextStyle.default
        (style.italic, style.lineHeight, style.tracking, style.alignment) = (true, 1.5, 20, .justified)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let text = String(decoding: try encoder.encode(style), as: UTF8.self)
        #expect(text == #"{"alignment":"justified","family":"System","italic":true,"lineHeight":1.5,"size":16,"tracking":20,"weight":400}"#)
        #expect(try JSONDecoder().decode(DesignTextStyle.self, from: Data(text.utf8)) == style)
    }

    @Test func theCatalogSetsTheSelectedTextStyle() throws {
        var w = titled()
        #expect(w.textStyle?.family == "System" && w.textStyle?.size == 16 && w.textHelp == nil)
        try run("text.set-italic", ["on": .bool(true)], &w)
        try run("text.set-alignment", ["alignment": .string("justified")], &w)
        try run("text.set-line-height", ["value": .number(1.5)], &w)
        let style = try #require(w.treeNode("node-5")?.textStyle)
        #expect(style.italic && style.alignment == .justified && style.lineHeight == 1.5)
        #expect(w.history.undo.suffix(3).map(\.name) == ["Italic", "Alignment", "Line Height"])
        w.undo()
        #expect(w.treeNode("node-5")?.textStyle.lineHeight == 1.2)
    }

    @Test func aScrubIsOneStep() throws {
        var w = titled()
        let steps = w.history.undo.count
        for value in [10.0, 20, 30] { try run("text.set-tracking", ["value": .number(value), "drag": .string("d")], &w) }
        #expect(w.treeNode("node-5")?.textStyle.tracking == 30)
        #expect(w.history.undo.count == steps + 1 && w.history.undo.last?.name == "Letter Spacing")
        w.undo()
        #expect(w.treeNode("node-5")?.textStyle.tracking == 0)
    }

    @Test func noTextLayerIsUnavailable() {
        var w = DesignFixtures.cards
        w.selectItem("node-2")
        #expect(w.textStyle == nil)
        #expect(DesignWorkspace.catalog.availability("text.set-size", on: w) == .unavailable("Select a text layer first."))
    }

    @Test func fontChangeRefits() throws {
        var w = titled()
        try run("text.set-font", ["family": .string("Serif")], &w)
        let title = try #require(w.treeNode("node-5"))
        #expect(title.textStyle.family == "Serif" && title.textStyle.weight == 400)
        #expect(title.frame.x == 100 && title.frame.y == 40 && title.frame.width == 40, "\(title.frame)")
        #expect(w.history.undo.last?.name == "Font")
    }

    @Test func aCenteredBoxKeepsItsCentre() throws {
        var w = titled()
        try run("text.set-alignment", ["alignment": .string("center")], &w)
        try run("text.set-size", ["size": .number(32)], &w)
        let frame = try #require(w.treeNode("node-5")?.frame)
        #expect(frame.width == 80 && frame.x + frame.width / 2 == 200, "\(frame)")
    }

    @Test func aFixedWidthBoxKeepsItsWidth() throws {
        var w = titled()
        var fixed = DesignTextStyle.default
        fixed.fixedWidth = true
        try w.setStyle(.textStyle(fixed))
        try run("text.set-font", ["family": .string("Mono")], &w)
        let frame = try #require(w.treeNode("node-5")?.frame)
        #expect(frame.x == 100 && frame.width == 200, "\(frame)")
    }
}
