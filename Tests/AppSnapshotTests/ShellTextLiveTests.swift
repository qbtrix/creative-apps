// ShellTextLiveTests.swift: shell-text ST-8 (MJ-ST4, packet
// suite/features/shell-text.md). SuiteServices.live's `text` is LiveText end
// to end: `pending` has no `text` key; a two-style line ("Hi " in regular
// Helvetica, "there" in bold red) measures one advance per grapheme, lays out
// on the fake layout rule (each grapheme at the running sum of the advances
// before it, on one baseline), and draws ink in both colours, the red right of
// the black; the font list is Core Text's, not the fake's three families.
// macOS only (SuiteShell).
#if os(macOS)
import Foundation
import SuiteModel
import SuiteShell
import Testing

@Suite(.timeLimit(.minutes(1))) struct ShellTextLiveTests {
    private func live() -> SuiteServices {
        let support = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShellTextLiveTests-\(UUID().uuidString)").path
        return SuiteServices.live(support: support, app: .launcher, arguments: [])
    }

    let line = [TextSpan("Hi ", fontFamily: "Helvetica", fontSize: 40),
                TextSpan("there", fontFamily: "Helvetica", fontSize: 40, weight: 700, rgba: [255, 0, 0, 255])]

    @Test func theTextMemberIsLive() {
        let s = live()
        #expect(s.pending["text"] == nil)
        #expect(!(s.text is FakeText))
    }

    @Test func aTwoStyleLineMeasuresLaysOutAndDraws() throws {
        let text = live().text
        let metrics = try text.measure(line)
        #expect(metrics.map(\.advances.count) == [3, 5])
        #expect(metrics.allSatisfy { $0.resolvedFamily == "Helvetica" && $0.ascent > 0 && $0.descent > 0 })
        #expect(metrics.flatMap(\.advances).allSatisfy { $0 > 0 })

        var placed: [PlacedSpan] = [], x = 10.0
        for (span, m) in zip(line, metrics) {
            var origins: [SuitePoint] = []
            for advance in m.advances { origins.append(SuitePoint(x: x, y: 60)); x += advance }
            placed.append(PlacedSpan(span: span, origins: origins, degrees: Array(repeating: 0, count: origins.count)))
        }
        let frame = try text.draw(placed, width: Int(x.rounded(.up)) + 10, height: 80)
        var blackX: [Int] = [], redX: [Int] = []
        for y in 0..<frame.height {
            for x in 0..<frame.width {
                let i = (y * frame.width + x) * 4
                guard frame.rgba.indices.contains(i + 3), frame.rgba[i + 3] > 200 else { continue }
                if frame.rgba[i] > 200, frame.rgba[i + 1] < 60 { redX.append(x) }
                if frame.rgba[i] < 60, frame.rgba[i + 1] < 60, frame.rgba[i + 2] < 60 { blackX.append(x) }
            }
        }
        let firstRed = try #require(redX.min()), lastBlack = try #require(blackX.max())
        #expect(lastBlack < firstRed)
    }

    @Test func theFontListIsTheMacs() {
        let families = live().text.families()
        #expect(families.count > 3)
        #expect(families.contains { $0.name == "Helvetica" })
        #expect(families.contains { $0.name == FakeText.systemFamily })
    }
}
#endif
