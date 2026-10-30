// LiveDragLine.swift: the overlay mark a drag shows over the canvas while it
// lasts, out of the window's workspace (gradient-fill PG-6). Every write to
// that workspace re-runs and lays out the whole editor (LiveStroke.swift says
// why), and such a drag changes nothing but its mark until the release
// (PhotoWorkspace.dragShowsLineOnly). So its samples go here, to a SuiteKernel
// LiveCopy of the workspace that only PhotoCanvasOverlay reads: the Gradient
// line as `line`, Remove's outline as `path` (fill-heal FH-4), and the whole
// copy as `shown`, which the overlay draws instead of the workspace for the
// area tools' selection in progress, the Crop tool's box (#6020) and
// Select's box (#6012). A Gradient or Remove press goes to the workspace
// first (it holds the drag, and the panels see it at once); an area, Crop or
// Select-box gesture runs here from its press. The window takes the copy back once (`take()`), before the release
// or any other intent, so the release lands from the last sample. PhotoWindow
// owns one and hands it down as the `photoDragLine` environment value;
// without one (a view hosted alone) the overlay draws the workspace's marks.
// Presentation state only.
import CoreRaster
import Observation
import PhotoModel
import SuiteKernel
import SwiftUI

@MainActor @Observable final class LiveDragLine {
    @ObservationIgnored private var copy = LiveCopy<PhotoWorkspace>()
    /// The copy's line, from the press to the last sample, in canvas pixels; nil with none live.
    private(set) var line: (from: Mask.Point, to: Mask.Point)?
    /// The copy's Remove outline, the points from the press, in canvas pixels; nil with none live.
    private(set) var path: [Mask.Point]?
    /// The copy with the latest sample run on it, for the overlay's selection and crop marks; nil with none live.
    private(set) var shown: PhotoWorkspace?

    /// `moves` run on the copy, made from `model` at the first, when `model`
    /// holds a line-only drag pressed where the first move starts, or the copy
    /// is live already (a later sample's `from` is the last sample, not the
    /// press); false otherwise, for the window to apply them.
    func drags(_ moves: [PhotoStrokeMove], on model: PhotoWorkspace, zoom: Double) -> Bool {
        guard let press = moves.first, copy.shown != nil || model.dragShowsLineOnly(pressAt: press.from) else { return false }
        var live = copy.take() ?? model
        live.drags(moves, zoom: zoom)
        copy.begin(live)
        line = live.gradientDrag
        path = live.removeStroke
        shown = live
        return true
    }

    /// The copy, handed over once, and its marks gone; nil with no drag live here.
    func take() -> PhotoWorkspace? {
        if line != nil { line = nil }
        if path != nil { path = nil }
        if shown != nil { shown = nil }
        return copy.take()
    }
}

extension EnvironmentValues {
    /// The window's live drag line; nil outside a PhotoWindow.
    @Entry var photoDragLine: LiveDragLine?
}
