// SuiteCurveEditorSnapshots.swift: SuiteUI's Studio easing parts at the
// inspector's content width (236 pt), in Light and Dark. Each column is a
// CurveEditor over its ChoiceChips and four StudioScrubRows: handle 1 focused on
// an Ease In curve, handle 2 focused on a curve that overshoots (the plot
// widens to hold it), and dimmed handles on a Hold step. The focus ring comes
// from `focusedHandle`, since the offscreen snapshot window never holds key
// focus. Curves come from FlareCore through the easing contract, so they are
// the real ones. Writes suite-curve-editor-light.png and -dark.png.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI
import Testing

@MainActor
@Suite struct SuiteCurveEditorSnapshots {
    @Test func curveEditor() throws {
        for scheme in [ColorScheme.light, .dark] {
            try snapshot(CurveEditorGallery(), name: "suite-curve-editor-\(scheme == .dark ? "dark" : "light")", scheme: scheme)
        }
    }
}

private struct CurveEditorGallery: View {
    private static let overshoot =
        EasingCurve.moving(.easeOut, .second, to: Point(x: 0.62, y: 1.45)) ?? .easeOut

    var body: some View {
        HStack(alignment: .top, spacing: SuiteSpacing.xxl) {
            column(.easeIn, preset: .easeIn, focus: .first)
            column(Self.overshoot, preset: nil, focus: .second)
            column(.hold, preset: .hold, focus: nil)
        }
        .padding(SuiteSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func column(_ easing: Easing, preset: EasingPreset?, focus: EasingHandleIndex?) -> some View {
        let (h1, h2) = EasingCurve.handles(of: easing)
        let values = [("X1", h1.x, 0.0...1.0), ("Y1", h1.y, -1.0...2.0), ("X2", h2.x, 0.0...1.0), ("Y2", h2.y, -1.0...2.0)]
        return VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            Text("Easing")
                .font(SuiteFont.sectionCaps)
                .textCase(.uppercase)
                .tracking(SuiteSize.capsTracking)
                .foregroundStyle(SuiteColor.secondaryText)
            CurveEditor(
                samples: EasingCurve.samples(of: easing, count: 129).map { CGPoint(x: $0.x, y: $0.y) },
                handles: (CGPoint(x: h1.x, y: h1.y), CGPoint(x: h2.x, y: h2.y)),
                dimmedHandles: easing == .hold, focusedHandle: focus, onMove: { _, _ in }, onEnd: {})
            ChoiceChips(
                options: EasingPreset.allCases.map { InspectorOption(id: $0, title: $0.title) }, selected: preset,
                onSelect: { _ in })
            ForEach(values, id: \.0) { label, value, range in
                StudioScrubRow(label: label, value: value, range: range, step: 0.01, onChange: { _ in })
            }
        }
        .frame(width: SuiteSize.inspectorWidth.ideal - 2 * SuiteSpacing.m)
        .padding(SuiteSpacing.m)
        .background(SuiteColor.panel)
    }
}
