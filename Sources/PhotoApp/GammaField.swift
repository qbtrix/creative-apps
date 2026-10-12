// GammaField.swift: the Levels Gamma row's number field. Gamma's slider sits
// on a log track (GammaTrack), so the row can't be an InspectorSliderRow yet
// (#88); this field matches that row's field instead. It shows
// NumericInput.format text, keeps the user's draft while they type, and on
// Return or losing focus parses the draft with NumericInput.parse (clamped to
// gammaRange, locale-free). The draft always clears on commit, so the field
// goes back to the stored, clamped gamma even when the edit changes nothing.
import PhotoModel
import SuiteUI
import SwiftUI

struct GammaField: View {
    let gamma: Float
    let onChange: @MainActor (Float) -> Void
    @State private var draft: String?
    @FocusState private var isFocused: Bool

    /// gammaRange as the Double range NumericInput takes.
    static let range = Double(AdjustmentSettings.gammaRange.lowerBound)...Double(AdjustmentSettings.gammaRange.upperBound)

    /// The text the field shows for `gamma` when no draft is up.
    static func text(for gamma: Float) -> String {
        NumericInput.format(Double(gamma))
    }

    /// The gamma `text` commits to from `gamma`, or nil when it leaves the
    /// value as it is (text that isn't a number, or one that clamps to it).
    static func committed(_ text: String, from gamma: Float) -> Float? {
        let parsed = Float(NumericInput.parse(text, in: range, keeping: Double(gamma)))
        return parsed == gamma ? nil : parsed
    }

    var body: some View {
        TextField("Gamma", text: Binding(get: { draft ?? Self.text(for: gamma) }, set: { draft = $0 }))
            .focused($isFocused)
            .onSubmit(commit)
            .onChange(of: isFocused) { _, focused in
                if !focused { commit() }
            }
            .labelsHidden()
            .multilineTextAlignment(.trailing)
            .font(SuiteFont.monospacedDigits)
            .frame(width: SuiteSize.inspectorField)
    }

    private func commit() {
        guard let text = draft else { return }
        draft = nil
        if let value = Self.committed(text, from: gamma) { onChange(value) }
    }
}
