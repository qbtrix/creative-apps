// InspectorRowLabelTests.swift (#2263, #2302): a disabled InspectorRow's
// label stays readable. The app audit measures it as ordinary text (it sits
// beside the row's controls, not inside a disabled one), so it must clear
// 4.5:1 on the row's fill in all four appearances; the row's controls carry
// the disabled dimming. macOS only, like the rest of SuiteUI.
@testable import SuiteUI
import SwiftUI
import Testing

@Suite struct InspectorRowLabelTests {
    @Test func aDisabledRowsLabelClearsTextContrast() {
        let P = SuitePalette.self
        for look in 0..<4 {
            let fill = P.card.values[look]
            let ink = TokensTests.over(P.textSecondary.values[look], fill, alpha: InspectorRow<EmptyView>.labelOpacity(enabled: false))
            #expect(TokensTests.contrast(ink, fill) >= 4.5, "appearance \(look)")
        }
        #expect(InspectorRow<EmptyView>.labelOpacity(enabled: true) == 1)
    }
}
