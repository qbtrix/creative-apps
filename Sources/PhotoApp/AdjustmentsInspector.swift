// AdjustmentsInspector.swift: the inspector's adjustment sections (Exposure,
// Levels, Blur, Hue and Saturation), each with an enable switch, a Reset
// button and SuiteUI slider rows. Values in, one closure out: every change
// goes out as an AdjustmentEdit, and AdjustmentSettings clamps and validates
// it. A disabled section dims its rows; Reset is off while a section is at
// its defaults.
import PhotoModel
import SuiteUI
import SwiftUI

struct AdjustmentsInspector: View {
    let settings: AdjustmentSettings
    var onEdit: @MainActor (AdjustmentEdit) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            section(.exposure) {
                InspectorSliderRow(
                    "Exposure", value: Double(settings.exposure), in: Self.doubles(AdjustmentSettings.exposureRange),
                    unit: "EV") { onEdit(.exposure(Float($0))) }
            }
            section(.levels) {
                InspectorSliderRow("Black", value: Double(settings.blackPoint), in: Self.doubles(AdjustmentSettings.levelsRange)) {
                    onEdit(.blackPoint(Float($0)))
                }
                InspectorSliderRow("White", value: Double(settings.whitePoint), in: Self.doubles(AdjustmentSettings.levelsRange)) {
                    onEdit(.whitePoint(Float($0)))
                }
                InspectorSliderRow("Gamma", value: Double(settings.gamma), in: Self.doubles(AdjustmentSettings.gammaRange)) {
                    onEdit(.gamma(Float($0)))
                }
            }
            section(.blur) {
                InspectorSliderRow("Radius", value: settings.blurSigma, in: AdjustmentSettings.sigmaRange, unit: "px") {
                    onEdit(.blurSigma($0))
                }
            }
            section(.hueSaturation) {
                InspectorSliderRow("Hue", value: settings.hue, in: AdjustmentSettings.hueRange, unit: "°") { onEdit(.hue($0)) }
                InspectorSliderRow("Saturation", value: settings.saturation, in: AdjustmentSettings.percentRange) {
                    onEdit(.saturation($0))
                }
                InspectorSliderRow("Lightness", value: settings.lightness, in: AdjustmentSettings.percentRange) {
                    onEdit(.lightness($0))
                }
            }
        }
    }

    /// One section: its switch and Reset button above its rows.
    private func section(_ kind: AdjustmentKind, @ViewBuilder rows: () -> some View) -> some View {
        InspectorSection(kind.title) {
            HStack {
                Toggle(
                    "Enabled",
                    isOn: Binding(get: { settings.isEnabled(kind) }, set: { onEdit(.setEnabled(kind, $0)) }))
                .toggleStyle(.switch)
                .controlSize(.small)
                Spacer()
                Button("Reset") { onEdit(.reset(kind)) }
                    .controlSize(.small)
                    .disabled(settings.isIdentity(kind))
                    .help("Reset \(kind.title)")
            }
            rows().disabled(!settings.isEnabled(kind))
        }
    }

    /// The slider rows take Double; exposure and levels are Float.
    private static func doubles(_ range: ClosedRange<Float>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }
}

extension AdjustmentKind {
    var title: String {
        switch self {
        case .exposure: "Exposure"
        case .levels: "Levels"
        case .blur: "Blur"
        case .hueSaturation: "Hue and Saturation"
        }
    }
}
