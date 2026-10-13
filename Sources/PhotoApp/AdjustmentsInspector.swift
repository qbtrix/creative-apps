// AdjustmentsInspector.swift: the Adjust tab's adjustment sections (Exposure,
// Levels, Hue/Saturation, Blur), each with an enable checkbox, slider rows
// and a Reset icon that shows while the section differs from its defaults.
// Values in, one closure out: every change goes out as an AdjustmentEdit, and
// AdjustmentSettings clamps and validates it. A disabled section dims its
// rows. Numbers show whole degrees and percents, one decimal for EV and px,
// and levelsDecimals for Black and White, so distinct points read distinct.
import PhotoModel
import SuiteUI
import SwiftUI

struct AdjustmentsInspector: View {
    let settings: AdjustmentSettings
    var onEdit: @MainActor (AdjustmentEdit) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section(.exposure) {
                InspectorSliderRow(
                    "Exposure", value: Double(settings.exposure), in: Self.doubles(AdjustmentSettings.exposureRange),
                    unit: "EV", decimals: 1) { onEdit(.exposure(Float($0))) }
            }
            section(.levels) {
                InspectorSliderRow(
                    "Black", value: Double(settings.blackPoint), in: Self.doubles(AdjustmentSettings.levelsRange),
                    decimals: AdjustmentSettings.levelsDecimals) { onEdit(.blackPoint(Float($0))) }
                InspectorSliderRow(
                    "White", value: Double(settings.whitePoint), in: Self.doubles(AdjustmentSettings.levelsRange),
                    decimals: AdjustmentSettings.levelsDecimals) { onEdit(.whitePoint(Float($0))) }
                gammaRow
            }
            section(.hueSaturation) {
                InspectorSliderRow("Hue", value: settings.hue, in: AdjustmentSettings.hueRange, unit: "°", decimals: 0) {
                    onEdit(.hue($0))
                }
                InspectorSliderRow(
                    "Saturation", value: settings.saturation, in: AdjustmentSettings.percentRange, unit: "%", decimals: 0
                ) { onEdit(.saturation($0)) }
                InspectorSliderRow(
                    "Lightness", value: settings.lightness, in: AdjustmentSettings.percentRange, unit: "%", decimals: 0
                ) { onEdit(.lightness($0)) }
            }
            section(.blur) {
                InspectorSliderRow("Radius", value: settings.blurSigma, in: AdjustmentSettings.sigmaRange, unit: "px", decimals: 1) {
                    onEdit(.blurSigma($0))
                }
            }
        }
    }

    /// One section: its enable checkbox above its rows, and Reset while it
    /// isn't at its defaults.
    private func section(_ kind: AdjustmentKind, @ViewBuilder rows: () -> some View) -> some View {
        InspectorSection(kind.title, onReset: settings.isIdentity(kind) ? nil : reset(kind)) {
            InspectorRow("") {
                Toggle(
                    "Enabled",
                    isOn: Binding(get: { settings.isEnabled(kind) }, set: { onEdit(.setEnabled(kind, $0)) }))
                .toggleStyle(.checkbox)
                .accessibilityLabel("\(kind.title) Enabled")
            }
            rows().disabled(!settings.isEnabled(kind))
        }
    }

    private func reset(_ kind: AdjustmentKind) -> @MainActor () -> Void {
        { onEdit(.reset(kind)) }
    }

    /// Gamma on a log10 track (GammaTrack), so 1 sits mid-track and a drag
    /// into the midpoint detent snaps to exactly 1 (until #88); the
    /// ScrubField shows and takes gamma itself, in hundredths.
    private var gammaRow: some View {
        InspectorRow("Gamma") {
            HStack(spacing: SuiteSpacing.s) {
                Slider(
                    value: Binding(
                        get: { GammaTrack.position(ofGamma: Double(settings.gamma)) },
                        set: { onEdit(.gamma(Float(GammaTrack.snappedGamma(atPosition: $0)))) }),
                    in: GammaTrack.positionRange
                )
                .accessibilityLabel("Gamma")
                .accessibilityValue(NumericInput.format(Double(settings.gamma)))
                ScrubField("Gamma", value: Double(settings.gamma), in: Self.doubles(AdjustmentSettings.gammaRange), step: 0.01) {
                    onEdit(.gamma(Float($0)))
                }
            }
        }
    }

    /// The slider rows take Double; exposure and levels are Float.
    private static func doubles(_ range: ClosedRange<Float>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }
}
