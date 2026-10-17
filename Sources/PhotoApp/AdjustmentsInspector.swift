// AdjustmentsInspector.swift: the inspector's adjustment sections (Exposure,
// Levels, Hue/Saturation, Blur), each with an enable checkbox, bar sliders
// (Gamma on its log track) and a Reset icon that shows while the section
// differs from its defaults.
// Values in, one closure out: every change goes out as an AdjustmentEdit, and
// AdjustmentSettings clamps and validates it. A disabled section dims its
// rows. Numbers show whole degrees and percents, one decimal for EV and px,
// and Black and White as a percent of the tonal range (PhotoLevelsFormat),
// at places that keep distinct points reading distinct.
// Curves (CurvesEditor) sits between Levels and Hue/Saturation, over
// `histogram`. The end of every gesture, a curve drag or a bar slider's drag,
// key step or typed value, goes out as onEditEnd, so each is one undo step.
// `sections` picks which sections show, in the order above (the inspector
// passes adjustSections), and `showsEnable` false drops the enable checkboxes, for
// an adjustment layer, whose row's eye turns it off. The defaults are the
// whole image's inspector, unchanged.
import PhotoModel
import SuiteUI
import SwiftUI

struct AdjustmentsInspector: View {
    let settings: AdjustmentSettings
    var onEdit: @MainActor (AdjustmentEdit) -> Void = { _ in }
    var histogram: [Double] = []
    var onEditEnd: @MainActor () -> Void = {}
    var sections: [AdjustmentKind] = AdjustmentKind.allCases
    var showsEnable = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            section(.exposure) {
                slider("Exposure", Double(settings.exposure), Self.doubles(AdjustmentSettings.exposureRange), unit: "EV", decimals: 1) {
                    .exposure(Float($0))
                }
            }
            section(.levels) {
                levelsRow("Black", settings.blackPoint) { .blackPoint($0) }
                levelsRow("White", settings.whitePoint) { .whitePoint($0) }
                gammaRow
            }
            section(.curves) {
                CurvesEditor(settings: settings, histogram: histogram, onEdit: onEdit, onEnd: onEditEnd)
            }
            section(.hueSaturation) {
                slider("Hue", settings.hue, AdjustmentSettings.hueRange, unit: "°", decimals: 0) { .hue($0) }
                slider("Saturation", settings.saturation, AdjustmentSettings.percentRange, unit: "%", decimals: 0) { .saturation($0) }
                slider("Lightness", settings.lightness, AdjustmentSettings.percentRange, unit: "%", decimals: 0) { .lightness($0) }
            }
            section(.blur) {
                slider("Radius", settings.blurSigma, AdjustmentSettings.sigmaRange, unit: "px", decimals: 1) { .blurSigma($0) }
            }
        }
    }

    /// One section, when `sections` holds it: its enable checkbox (while
    /// `showsEnable`) above its rows, and Reset while it isn't at its defaults.
    @ViewBuilder
    private func section(_ kind: AdjustmentKind, @ViewBuilder rows: () -> some View) -> some View {
        if sections.contains(kind) {
            InspectorSection(kind.title, onReset: settings.isIdentity(kind) ? nil : reset(kind)) {
                if showsEnable {
                    InspectorRow("") {
                        Toggle(
                            "Enabled",
                            isOn: Binding(get: { settings.isEnabled(kind) }, set: { onEdit(.setEnabled(kind, $0)) }))
                        .toggleStyle(.checkbox)
                        .accessibilityLabel("\(kind.title) Enabled")
                    }
                }
                rows().disabled(!settings.isEnabled(kind))
            }
        }
    }

    private func reset(_ kind: AdjustmentKind) -> @MainActor () -> Void {
        { onEdit(.reset(kind)) }
    }

    /// A Levels point as a percent of the tonal range (PhotoLevelsFormat):
    /// 0% pure black, 100% pure white.
    private func levelsRow(_ label: String, _ point: Float, _ edit: @escaping (Float) -> AdjustmentEdit) -> some View {
        slider(
            label, PhotoLevelsFormat.percent(point), PhotoLevelsFormat.range, unit: PhotoLevelsFormat.unit,
            decimals: PhotoLevelsFormat.decimals
        ) { edit(PhotoLevelsFormat.point(percent: $0)) }
    }

    /// Gamma as a bar slider on a log10 track (GammaTrack), so 1 sits mid-row
    /// and a drag or key into the midpoint detent snaps to exactly 1 (until
    /// #88); typing takes gamma itself, in hundredths, and a click and click
    /// away changes nothing (NumericInput.committed).
    private var gammaRow: some View {
        slider(
            "Gamma", Double(settings.gamma), Self.doubles(AdjustmentSettings.gammaRange), step: 0.01,
            decimals: AdjustmentSettings.gammaDecimals,
            track: ScrubTrack(
                positions: GammaTrack.positionRange, step: GammaTrack.step, position: { GammaTrack.position(ofGamma: $0) },
                value: { GammaTrack.snappedGamma(atPosition: $0) })
        ) { .gamma(Float($0)) }
    }

    /// A bar slider whose changes go out as `edit`, and whose gesture's end
    /// (a drag, a key step, a typed value) goes out as onEditEnd, so each
    /// gesture is its own undo step.
    private func slider(
        _ label: String, _ value: Double, _ range: ClosedRange<Double>, step: Double? = nil, unit: String = "",
        decimals: Int, track: ScrubTrack? = nil, _ edit: @escaping (Double) -> AdjustmentEdit
    ) -> some View {
        InspectorSliderRow(
            label, value: value, in: range, step: step, unit: unit, decimals: decimals, track: track,
            onChange: { onEdit(edit($0)) }, onEnd: onEditEnd)
    }

    /// The slider rows take Double; exposure and levels are Float.
    private static func doubles(_ range: ClosedRange<Float>) -> ClosedRange<Double> {
        Double(range.lowerBound)...Double(range.upperBound)
    }
}
