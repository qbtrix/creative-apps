// HaloReadout.swift: a value a journey reads, as the label of a hidden
// element. XCUITest reads SwiftUI accessibility values as empty strings
// (#262): a timeline lane's key count read "" on CI (run 38767265986), so
// each lane also publishes its text as the label of a 1 × 1 pt element,
// `halo.timeline.keys`, the way `halo.file` carries the save status. The
// element takes no hits and draws nothing, so the app audit finds no control
// in it and too few pixels to measure as text. The real value stays on its
// element for VoiceOver.
import SwiftUI

/// The hidden element: 1 × 1 pt, no hits, its label `text`.
struct HaloReadoutElement: View {
    /// Its side: not a design size, since it draws nothing; under the audit's
    /// 16 pixels at 2x, so the contrast check never measures it as text.
    private static let side: CGFloat = 1
    let identifier: String
    let text: String

    var body: some View {
        Color.clear
            .frame(width: Self.side, height: Self.side)
            .allowsHitTesting(false)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: text))
            .accessibilityIdentifier(identifier)
    }
}
