// FontPicker.swift: SuiteUI's one font picker (packet
// docs/blueprints/suiteui/features/font-picker.md). It takes font families and
// the current pick in, and reports picks out through `onPick`; it never reads a
// Model or a service. FP-1 is a placeholder that lists the families' names
// and the current pick, with no controls yet; FP-3 builds the view: a
// searchable list with each family in its own face, the face menu and the
// size row.
import SuiteModel
import SwiftUI

public struct FontPicker: View {
    let families: [FontFamily]
    let pick: FontPick
    let onPick: (FontPick) -> Void

    public init(families: [FontFamily], pick: FontPick, onPick: @escaping (FontPick) -> Void) {
        self.families = families
        self.pick = pick
        self.onPick = onPick
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            ForEach(families) { family in
                Text(family.name)
                    .font(SuiteFont.body)
                    .foregroundStyle(family.name == pick.family ? SuiteColor.textPrimary : SuiteColor.secondaryText)
            }
            Text("\(pick.family) \(pick.face.name)")
                .font(SuiteFont.caption)
                .foregroundStyle(SuiteColor.secondaryText)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("suite.fontpicker")
    }
}
