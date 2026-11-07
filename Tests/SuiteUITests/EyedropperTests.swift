// EyedropperTests.swift (eyedropper EY-3): a colour row's eyedropper pick is one gesture: the row's onChange
// then its onEnd, once each, and it ends a run of colour panel picks first; Escape (a nil pick) calls neither.
// The sampler's NSColor reads as the nearest 8-bit sRGB colour. The loupe reads "#00FF00" over green and
// "No colour here" over nothing, and the size chips carry `suite.sample.size.<n>`. macOS only.
import AppKit
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct EyedropperTests {
    /// What a hex row told its host, in order.
    final class Log {
        var lines: [String] = []
    }

    private static func row(_ log: Log, hex: HexColor = HexColor(0, 0, 255)) -> InspectorColorRow {
        InspectorColorRow("Fill", hex: hex, onChange: { log.lines.append("change \($0.text)") },
                          onEnd: { log.lines.append("end") })
    }

    @Test func pickIsOneChangeThenOneEnd() {
        let log = Log()
        var ends = HexEnds()
        Self.row(log).sample(HexColor(255, 0, 0), ends: &ends)
        #expect(log.lines == ["change #FF0000", "end"])
        #expect(!ends.isOpen)
    }

    @Test func escapePicksNothing() {
        let log = Log()
        var ends = HexEnds()
        Self.row(log).sample(nil, ends: &ends)
        #expect(log.lines.isEmpty)
    }

    @Test func pickEndsAnOpenPanelRunFirst() {
        let log = Log()
        var ends = HexEnds()
        _ = ends.picked()
        Self.row(log).sample(HexColor(0, 255, 0), ends: &ends)
        #expect(log.lines == ["end", "change #00FF00", "end"])
        #expect(!ends.isOpen)
    }

    @Test func samplerColourReadsAsNearestSRGB() {
        #expect(EyedropperButton.hex(NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)) == HexColor(0, 255, 0))
        #expect(EyedropperButton.hex(NSColor(srgbRed: 0.5, green: 0.25, blue: 1, alpha: 1)) == HexColor(128, 64, 255))
        #expect(EyedropperButton.hex(nil) == nil)
    }

    @Test func loupeReadsTheHexOrSaysThereIsNone() {
        #expect(SampleLoupe.text(for: HexColor(0, 255, 0)) == "#00FF00")
        #expect(SampleLoupe.text(for: nil) == "No colour here")
    }

    @Test func loupeRingIsWiderThanAToolButton() {
        #expect(SampleLoupe.diameter > SuiteSize.toolButton)
    }

    @Test func sizeChipsCarryTheirIdentifiers() {
        #expect(SampleSizeChips.options.map(\.identifier) == ["suite.sample.size.1", "suite.sample.size.3", "suite.sample.size.5"])
        #expect(SampleSizeChips.options.map(\.title) == ["Point", "3 × 3", "5 × 5"])
        #expect(SampleSizeChips.options.map(\.id) == SampleSize.allCases)
    }

    /// Mac finish: the row's eyedropper button lights on hover and press (HoverButtonStyle), never a bare `.plain`
    /// icon that gives the pointer no sign it is a button.
    @Test func buttonShowsHoverAndPressedStates() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent()
        let source = try String(contentsOf: root.appending(path: "Sources/SuiteUI/Eyedropper.swift"), encoding: .utf8)
        let start = try #require(source.range(of: "public struct EyedropperButton: View {"), "the button moved")
        let end = try #require(source.range(of: "private func sample()", range: start.upperBound..<source.endIndex))
        let body = source[start.upperBound..<end.lowerBound]
        #expect(body.contains(".buttonStyle(HoverButtonStyle())"))
        #expect(!body.contains(".buttonStyle(.plain)"))
    }
}
