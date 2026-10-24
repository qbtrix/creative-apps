// DesignTextLayoutTests.swift (text-style TS-8): the canvas's text setting. A style at the defaults keeps the old
// draw; italic, line height, tracking or justify go through the kernel's layout, whose words land where its pen x
// and baselines say (a justified line spans its box, line height spaces the baselines, tracking widens the run);
// the shared text style rows' intents run as one undo step each; RJ-D50's input opens and re-saves unchanged.
// Runs on Linux and macOS.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
@testable import DesignModel
import SuiteKernel
import SuiteModel
import Testing

/// Every grapheme 10 pt wide, ascent 8, descent 2: a line of the default style is 12 pt apart.
private func fixed(_ graphemes: [String]) -> (advances: [Double], ascent: Double, descent: Double) {
    (Array(repeating: 10, count: graphemes.count), 8, 2)
}

@Suite struct DesignTextLayoutTests {
    @Test func onlyTheNewFieldsTakeTheLayout() {
        #expect(!DesignTextStyle.default.drawsThroughLayout)
        let changes: [(inout DesignTextStyle) -> Void] = [
            { $0.italic = true }, { $0.lineHeight = 1.5 }, { $0.tracking = 20 }, { $0.alignment = .justified },
        ]
        for change in changes {
            var style = DesignTextStyle.default
            change(&style)
            #expect(style.drawsThroughLayout, "\(style)")
        }
        var centered = DesignTextStyle.default
        centered.alignment = .center
        #expect(!centered.drawsThroughLayout, "centre alignment draws the old way")
        #expect(centered.kernel(.black, boxWidth: nil).paragraph.alignment == .center, "the layout centres it")
    }

    @Test func justifiedLinesSpanTheBoxAndTheLastStaysLeft() throws {
        var style = DesignTextStyle.default
        style.alignment = .justified
        let set = try #require(style.laidOut("ab cd ef gh", wrap: 75, advances: fixed))
        // "ab cd " fits 75 (ink 50); "ef gh" ends the paragraph, so it stays left.
        #expect(set.words.map(\.text) == ["ab", "cd", "ef", "gh"])
        #expect(set.words[0].x == 0 && set.words[1].x + 20 == 75, "the first line's last word ends at the box's edge")
        #expect(set.words[2].x == 0 && set.words[3].x == 30, "the last line keeps its spaces")
        #expect(set.words[0].baseline == 8 && set.words[2].baseline == 8 + 1.2 * 10)
        #expect(set.width == 75)
    }

    @Test func lineHeightAndTrackingMoveTheWords() throws {
        var style = DesignTextStyle.default
        (style.lineHeight, style.tracking, style.size) = (1.5, 100, 20)
        #expect(style.trackingPoints == 2)
        let set = try #require(style.laidOut("ab\ncd", wrap: nil, advances: fixed))
        #expect(set.words.map(\.baseline) == [8, 8 + 1.5 * 10], "line height 1.5 spaces the baselines 1.5 × (ascent + descent)")
        #expect(set.words.allSatisfy { $0.x == 0 })
        #expect(set.width == 24 && set.height == 8 + 15 + 2, "two graphemes of 10 + 2 tracking each")
        #expect(style.laidOut("ab", wrap: -4, advances: fixed)?.width == style.laidOut("ab", wrap: nil, advances: fixed)?.width,
                "a wrap that isn't positive counts as none")
    }

    @Test func eachRowIntentIsOneStep() throws {
        var workspace = DesignFixtures.cards
        workspace.useServices(.fake)
        workspace.selectItem("node-5")
        let intents: [(TextIntent, String)] = [
            (.font(family: "System", weight: 400, italic: true), "Font"), (.alignment(.justified), "Alignment"),
            (.lineHeight(1.5, drag: nil), "Line Height"), (.tracking(20, drag: nil), "Letter Spacing"),
        ]
        for (intent, name) in intents {
            let steps = workspace.history.undo.count
            workspace.runText(intent)
            #expect(workspace.history.undo.count == steps + 1 && workspace.history.undo.last?.name == name, "\(intent)")
        }
        let style = try #require(workspace.findNode("node-5")?.textStyle)
        #expect(style.italic && style.alignment == .justified && style.lineHeight == 1.5 && style.tracking == 20)
        let steps = workspace.history.undo.count
        workspace.runText(.tracking(20, drag: nil))
        #expect(workspace.history.undo.count == steps, "an intent that changes nothing makes no step")
    }

    @Test func paragraphJobInputResavesUnchanged() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        var bytes = try Data(contentsOf: root.appendingPathComponent("Tests/RealJobs/design/paragraph-style/input/paragraph.design"))
        if bytes.last == UInt8(ascii: "\n") { bytes.removeLast() }
        var opened = DesignWorkspace()
        try opened.open(bytes)
        #expect(try opened.fileData() == bytes)
        #expect(opened.findNode("node-2")?.textStyle.fixedWidth == true)
    }
}
