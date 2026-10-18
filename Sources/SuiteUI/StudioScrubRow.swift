// StudioScrubRow.swift: the Studio editor's number row (Flare's easing
// inspector), which is the suite's one bar slider: an InspectorSliderRow
// showing two decimals and its unit ("0.50 s"; none by default). The name
// stays so Studio callers read the same; the look and every rule live in
// ScrubField's bar.
import SwiftUI

public struct StudioScrubRow: View {
    private let row: InspectorSliderRow

    public init(
        label: String, value: Double, range: ClosedRange<Double>, step: Double, unit: String = "",
        onChange: @escaping @MainActor (Double) -> Void, onEnd: @escaping @MainActor () -> Void = {}
    ) {
        row = InspectorSliderRow(
            label, value: value, in: range, step: step, unit: unit, decimals: 2, onChange: onChange, onEnd: onEnd)
    }

    public var body: some View { row }
}
