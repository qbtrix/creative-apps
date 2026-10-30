// HistogramView.swift: the suite's histogram, one for every app (Library's
// develop panel, Photo's Levels): a ToneHistogram's bins as a filled outline in
// the field well, with a clipping marker in each top corner, shadows left and
// highlights right, lit in the warning color while any pixel clips there. With
// no bins the well says `emptyMessage`, so an empty well never reads as a
// black photo. The outline is ToneCurveEditor's `histogramPoints`, the one
// path both draw. It counts nothing: the host hands it a ToneHistogram it
// counted off the main actor (SuiteModel's ToneHistogram from the engine's
// counts). One accessibility element identified `id`. XCUITest reads SwiftUI
// values as empty strings (#262), so when the host passes a `value` the label
// carries the readout, that value then the clipping reading (`label`), and the
// value stays empty so VoiceOver says it once; without one the label is
// "Histogram" and the value its clipping reading (`reading`).
import SuiteModel
import SwiftUI

public struct HistogramView: View {
    private let histogram: ToneHistogram
    private let emptyMessage: String
    private let value: String?
    private let id: String

    /// `value` leads the accessibility label, before the clipping reading (Library keeps its mean there).
    public init(
        _ histogram: ToneHistogram, emptyMessage: String = "No histogram", value: String? = nil,
        id: String = "suite.histogram"
    ) {
        self.histogram = histogram
        self.emptyMessage = emptyMessage
        self.value = value
        self.id = id
    }

    public var body: some View {
        Canvas { context, size in draw(in: &context, size: size) }
            .frame(maxWidth: .infinity)
            .frame(height: SuiteSize.studioRow * 3)
            .background(SuiteColor.field, in: .rect(cornerRadius: SuiteRadius.row))
            .overlay {
                if histogram.heights.isEmpty {
                    Text(emptyMessage).font(SuiteFont.inspectorMeta).foregroundStyle(SuiteColor.secondaryText)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(verbatim: Self.label(histogram, value: value, empty: emptyMessage)))
            .accessibilityValue(Text(verbatim: value == nil ? Self.reading(histogram, empty: emptyMessage) : ""))
            .accessibilityIdentifier(id)
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let plot = CGRect(origin: .zero, size: size).insetBy(dx: SuiteSpacing.xs, dy: SuiteSpacing.xs)
        let outline = ToneCurveEditor.histogramPoints(histogram.heights)
        if !outline.isEmpty {
            var path = Path()
            for (i, unit) in ([CGPoint.zero] + outline + [CGPoint(x: 1, y: 0)]).enumerated() {
                let point = CGPoint(x: plot.minX + unit.x * plot.width, y: plot.maxY - unit.y * plot.height)
                if i == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.closeSubpath()
            context.fill(path, with: .color(SuiteColor.secondaryText.opacity(0.6)))
        }
        let side = SuiteSize.curveHandle
        for (left, clips) in [(true, histogram.clipsShadows), (false, histogram.clipsHighlights)] {
            let x = left ? plot.minX : plot.maxX
            var corner = Path()
            corner.move(to: CGPoint(x: x, y: plot.minY))
            corner.addLine(to: CGPoint(x: x + (left ? side : -side), y: plot.minY))
            corner.addLine(to: CGPoint(x: x, y: plot.minY + side))
            corner.closeSubpath()
            context.fill(corner, with: .color(clips ? SuiteColor.stateWarning : SuiteColor.tick))
        }
    }

    /// The host's value then the clipping reading when it passes one (UI tests read the label, #262), else "Histogram".
    nonisolated static func label(_ histogram: ToneHistogram, value: String?, empty: String) -> String {
        value.map { "\($0)  ·  \(reading(histogram, empty: empty))" } ?? "Histogram"
    }

    /// "Shadows clipped, Highlights clipped", "No clipping", or `empty` with no bins.
    nonisolated public static func reading(_ histogram: ToneHistogram, empty: String) -> String {
        guard !histogram.heights.isEmpty else { return empty }
        let clips = (histogram.clipsShadows ? ["Shadows clipped"] : []) + (histogram.clipsHighlights ? ["Highlights clipped"] : [])
        return clips.isEmpty ? "No clipping" : clips.joined(separator: ", ")
    }
}
