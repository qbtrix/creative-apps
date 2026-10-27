// LiveDragLine.swift: the line a drag shows over the canvas while it lasts,
// out of the window's workspace (gradient-fill PG-6). Every write to that
// workspace re-runs and lays out the whole editor (LiveStroke.swift says why),
// and a Gradient drag changes nothing but its line until the release draws
// (PhotoWorkspace.dragShowsLineOnly). So the press goes to the workspace (it
// holds the drag, and the panels see it at once), and the later samples go
// here, to a SuiteKernel LiveCopy of it that only PhotoCanvasOverlay reads,
// as `line`. The window takes the copy back once (`take()`), before the
// release or any other intent, so the release draws from the last sample.
// PhotoWindow owns one and hands it down as the `photoDragLine` environment
// value; without one (a view hosted alone) the overlay draws the workspace's
// line. Remove's outline (`path`, fill-heal FH-4) rides the same copy.
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

    /// `moves` run on the copy, made from `model` at the first, when `model`
    /// holds a line-only drag; false when it doesn't, for the window to apply them.
    func drags(_ moves: [PhotoStrokeMove], on model: PhotoWorkspace, zoom: Double) -> Bool {
        guard model.dragShowsLineOnly else { return false }
        var live = copy.take() ?? model
        live.drags(moves, zoom: zoom)
        copy.begin(live)
        line = live.gradientDrag
        path = live.removeStroke
        return true
    }

    /// The copy, handed over once, and the line gone; nil with no drag live here.
    func take() -> PhotoWorkspace? {
        if line != nil { line = nil }
        if path != nil { path = nil }
        return copy.take()
    }
}

extension EnvironmentValues {
    /// The window's live drag line; nil outside a PhotoWindow.
    @Entry var photoDragLine: LiveDragLine?
}
