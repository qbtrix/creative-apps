// LiveStroke.swift: the workspace a paint stroke draws on while it lasts, a
// SuiteKernel LiveCopy<PhotoWorkspace>, and the pacer that feeds it
// (SuiteUI's SuiteStrokePacer, at SuitePointerPressure's pressure).
// The window keeps its workspace in State, and every write to it re-runs and
// lays out the whole editor on the main actor (toolbar, tool palette, sidebar,
// inspector, menus, the checkerboard behind the picture): a SwiftUI pass per
// pointer sample. A brush, eraser, clone or heal drag changes only pixels
// (PhotoWorkspace.dragPaintsOnly), so its samples go to the live copy, kept
// in this class out of SwiftUI's sight, and the tile canvas shows each one
// through CanvasRenderer. The window takes the copy back once (`take()`): at
// the drag's end, before any other intent, before the status message clears,
// and at once when a sample set a status message, so a refusal shows at the
// press. Other tools' drags (marquee, crop, move, eyedropper) show through
// the panels and overlays, so they still go to the window's workspace.
// Presentation state only.
import AppKit
import CoreRaster
import PhotoModel
import SuiteKernel
import SuiteUI

/// One canvas drag sample as the pacer keeps it: the pen pressure and the
/// modifier keys it arrived with, never merged across samples.
typealias PhotoStrokeMove = (from: Mask.Point, to: Mask.Point, pressure: Double, modifiers: DragModifiers)

/// The window's pacer: SuiteUI's, over Photo's drag samples.
typealias StrokePacer = SuiteStrokePacer<PhotoStrokeMove>

extension SuiteStrokePacer where Move == PhotoStrokeMove {
    /// The sample type, by the name the window and its tests use.
    typealias Move = PhotoStrokeMove
}

@MainActor final class LiveStroke {
    private var copy = LiveCopy<PhotoWorkspace>()

    /// `moves` drawn on the stroke's copy, made from `model` at the first;
    /// nil when the drag doesn't only paint, for the window to apply itself.
    func drags(_ moves: [PhotoStrokeMove], on model: PhotoWorkspace, zoom: Double) -> PhotoWorkspace? {
        // Taken out, the copy has one owner here, so the drags write its tiles
        // in place (LiveCopy.edit would hold a second reference and copy them).
        guard var live = copy.take() ?? (model.dragPaintsOnly ? model : nil) else { return nil }
        live.drags(moves, zoom: zoom)
        copy.begin(live)
        return live
    }

    /// The stroke's copy, handed over once; nil with no stroke live.
    func take() -> PhotoWorkspace? { copy.take() }
}

extension DragModifiers {
    /// The keys among `flags` a canvas drag reads: Shift and Option.
    init(flags: NSEvent.ModifierFlags) {
        self.init()
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.option) { insert(.option) }
    }
}
