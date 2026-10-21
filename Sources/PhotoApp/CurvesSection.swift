// CurvesSection.swift: the Curves adjustment in Photo's inspector. CurvesEditor
// is the section's one row: SuiteUI's ToneCurveEditor drawing the model's
// points, its engine-sampled curve (AdjustmentSettings.curveSamples) and the
// histogram of the image as it enters Curves. Each point change goes out as
// one .curvePoints edit and the gesture's end as onEnd, so a drag, a nudge or
// a delete is one "Curves" undo step. A click that would add a point past
// curvePointCount is refused by the model, so nothing changes. Identifiers:
// photo.curves, photo.curves.point1, ...
// AdjustmentsPanel is the inspector's adjustment sections for its target
// (adjustTarget): the whole image's sections and intents, or, for a selected
// adjustment layer, that layer's settings (so Curves reads and writes the
// layer's curve), only its sections (adjustSections), no enable switch, and
// the .adjustmentLayer intents. It keeps the
// histogram as presentation state and counts it off the main actor only when
// curvesHistogramKey changes (pixels, layers, exposure, levels), never during
// a curve drag, and not during a canvas drag either: a brush stroke changes
// the pixels every frame, so the count waits for the drag's end. A slider
// drag changes the key every step, so the count waits until the key has held
// for 150 ms. The count runs in the key's task, so a newer key cancels it and
// it stops at its next row; on a many-layer image one count is seconds of
// CPU, and superseded ones left running burned the cores after every toggle
// or slider step. Values in, intents out.
import CoreRaster
import PhotoModel
import SuiteModel
import SuiteUI
import SwiftUI

struct CurvesEditor: View {
    let settings: AdjustmentSettings
    let histogram: ToneHistogram
    let onEdit: @MainActor (AdjustmentEdit) -> Void
    let onEnd: @MainActor () -> Void

    var body: some View {
        ToneCurveEditor(
            points: settings.curvePoints.map(Self.unit), samples: settings.curveSamples().map(Self.unit),
            histogram: histogram.heights, id: "photo.curves",
            onChange: { points in onEdit(.curvePoints(points.map { CurvePoint(x: Float($0.x), y: Float($0.y)) })) },
            onEnd: onEnd)
    }

    private static func unit(_ point: CurvePoint) -> CGPoint { CGPoint(x: Double(point.x), y: Double(point.y)) }
}

struct AdjustmentsPanel: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    /// Counts the histogram of a workspace; a test passes its own to see which counts finish.
    var count: @Sendable (PhotoWorkspace) async -> ToneHistogram = AdjustmentsPanel.count
    @State private var histogram = ToneHistogram.empty

    var body: some View {
        inspector
        // Nil while dragging, so a brush stroke never recounts; its end does, once.
        .task(id: model.isDragging ? nil : model.curvesHistogramKey) {
            guard !model.isDragging else { return }
            // A slider drag changes the key every step: count once it rests, not once per step (each count
            // composites 256 rows on the CPU). Not detached: a newer key's cancel must reach the count.
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            let counted = await count(model)
            if !Task.isCancelled { histogram = counted }
        }
    }

    /// The histogram, counted off the main actor (a nonisolated async function runs on the global executor)
    /// inside the calling task, so cancelling that task stops the count.
    nonisolated static func count(_ workspace: PhotoWorkspace) async -> ToneHistogram { workspace.curvesHistogram() }

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
