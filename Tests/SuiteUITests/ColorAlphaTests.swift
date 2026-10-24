// ColorAlphaTests.swift (gradient-fill, gap audit C3): the colour row's opacity init. A panel pick that only moves the
// opacity is a change, a typed hex or an eyedropper pick keeps the row's opacity instead of resetting it to 100%,
// and the gradient editor's stop colour keeps its alpha. macOS only.
import SuiteKernel
import SwiftUI
import Testing

@testable import SuiteUI

@MainActor
@Suite struct ColorAlphaTests {
    final class Log { var lines: [String] = [] }

    private static func row(_ log: Log, opacity: Double = 0.5) -> InspectorColorRow {
        InspectorColorRow("Fill", hex: HexColor(0, 0, 255), opacity: opacity,
                          onChange: { log.lines.append("change \($0.text) \(Int(($1 * 100).rounded()))%") },
                          onEnd: { log.lines.append("end") })
    }

    @Test func anOpacityOnlyPickIsAChange() {
        let log = Log()
        Self.row(log).onPick(Color.Resolved(red: 0, green: 0, blue: 1, opacity: 0.25))
        #expect(log.lines == ["change #0000FF 25%"])
    }

    @Test func theSamePickChangesNothing() {
        let log = Log()
        Self.row(log).onPick(Color.Resolved(red: 0, green: 0, blue: 1, opacity: 0.5))
        #expect(log.lines.isEmpty)
    }

    @Test func anEyedropperPickKeepsTheOpacity() {
        let log = Log()
        var ends = HexEnds()
        Self.row(log).sample(HexColor(255, 0, 0), ends: &ends)
        #expect(log.lines == ["change #FF0000 50%", "end"])
    }

    @Test func aTypedHexKeepsTheOpacity() {
        #expect(Self.row(Log(), opacity: 0.4).kept(HexColor(255, 0, 0).resolved).opacity == 0.4)
        #expect(InspectorColorRow("Fill", hex: HexColor(0, 0, 0), onChange: { _ in }).kept(HexColor(255, 0, 0).resolved).opacity == 1)
    }

    @Test func aStopColorKeepsItsAlpha() {
        #expect(GradientEditorText.fillColor(HexColor(255, 0, 0), alpha: 0.5) == FillColor(r: 1, g: 0, b: 0, a: 0.5))
    }
}
