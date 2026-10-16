// CurvesSection.swift: the Curves adjustment in Photo's inspector. CurvesEditor
// is the section's one row: SuiteUI's ToneCurveEditor drawing the model's
// points, its engine-sampled curve (AdjustmentSettings.curveSamples) and the
// histogram of the image as it enters Curves. Each point change goes out as
// one .curvePoints edit and the gesture's end as onEnd, so a drag, a nudge or
// a delete is one "Curves" undo step. A click that would add a point past
// curvePointCount is refused by the model, so nothing changes. Identifiers:
// photo.curves, photo.curves.point1, ...
// AdjustmentsPanel is the Adjust tab's sections for its target
// (adjustTarget): the whole image's sections and intents, or, for a selected
// adjustment layer, that layer's settings (so Curves reads and writes the
// layer's curve), only its sections (adjustSections), no enable switch, and
// the .adjustmentLayer intents. It keeps the
// histogram as presentation state and counts it off the main actor only when
// curvesHistogramKey changes (pixels, layers, exposure, levels), never during
// a curve drag, and not during a canvas drag either: a brush stroke changes
// the pixels every frame, so the count waits for the drag's end. Values in,
// intents out.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI

struct CurvesEditor: View {
    let settings: AdjustmentSettings
    let histogram: [Double]
    let onEdit: @MainActor (AdjustmentEdit) -> Void
    let onEnd: @MainActor () -> Void

    var body: some View {
        ToneCurveEditor(
            points: settings.curvePoints.map(Self.unit), samples: settings.curveSamples().map(Self.unit),
            histogram: histogram, id: "photo.curves",
            onChange: { points in onEdit(.curvePoints(points.map { CurvePoint(x: Float($0.x), y: Float($0.y)) })) },
            onEnd: onEnd)
    }

    private static func unit(_ point: CurvePoint) -> CGPoint { CGPoint(x: Double(point.x), y: Double(point.y)) }
}

struct AdjustmentsPanel: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    @State private var histogram: [Double] = []

    var body: some View {
        inspector
        // Nil while dragging, so a brush stroke never recounts; its end does, once.
        .task(id: model.isDragging ? nil : model.curvesHistogramKey) {
            guard !model.isDragging else { return }
            let workspace = model
            let counted = await Task.detached(priority: .userInitiated) { workspace.curvesHistogram() }.value
            if !Task.isCancelled { histogram = counted }
        }
    }

    /// An adjustment layer's sections have no enable switch: its row's eye turns it off.
    static func showsEnable(for target: AdjustTarget) -> Bool {
        if case .layer = target { false } else { true }
    }

    @ViewBuilder private var inspector: some View {
        switch model.adjustTarget {
        case .image:
            AdjustmentsInspector(
                settings: model.adjustments, onEdit: { perform(.adjust($0)) }, histogram: histogram,
                onEditEnd: { perform(.endAdjust) })
        case .layer(let id, let settings):
            AdjustmentsInspector(
                settings: settings, onEdit: { perform(.adjustmentLayer(.adjust(id, $0))) }, histogram: histogram,
                onEditEnd: { perform(.adjustmentLayer(.endAdjust)) }, sections: model.adjustSections,
                showsEnable: Self.showsEnable(for: model.adjustTarget))
        }
    }
}
