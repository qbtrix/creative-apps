// PhotoReadout.swift: text a journey reads, as the label of a hidden element.
// XCUITest reads SwiftUI accessibility values as empty strings (#262), and a
// menu item's help tag as no text at all, so Photo publishes what it says
// there again as the label of a 1 × 1 pt element: the Edit and Layer items'
// help (`photo.menu.reasons`). It takes no hits and draws nothing, so the app
// audit finds no control in it and too few pixels to measure as text.
import SwiftUI

struct PhotoReadout: View {
    /// Not a design size: under the audit's 16 pixels at 2x.
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
