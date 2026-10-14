// ThumbnailSelectionTests.swift: issue #101. A selected ThumbnailCell sits on a
// `valueFill` plate with its caption in `accentText`; the caption must clear
// 4.5:1 on that plate, and the plate must differ from the grid's own grey
// ladder steps, in all four appearances. macOS only.
import SuiteUI
import Testing

@Suite struct ThumbnailSelectionTests {
    typealias P = SuitePalette

    @Test func selectedCaptionClearsFourPointFiveOnThePlate() {
        for look in 0..<4 {
            let ratio = TokensTests.contrast(P.accentText.values[look], P.valueFill.values[look])
            #expect(ratio >= 4.5, "accentText on valueFill in \(look): \(ratio)")
        }
    }

    @Test func plateStandsApartFromTheRowsAroundIt() {
        for look in 0..<4 {
            for surface in [P.panel, P.card, P.row] {
                #expect(TokensTests.contrast(P.valueFill.values[look], surface.values[look]) > 1, "\(surface) in \(look)")
            }
        }
    }
}
