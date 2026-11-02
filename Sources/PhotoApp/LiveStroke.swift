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
// press. The area and Crop tools' drags draw only an overlay mark, so they run
// on LiveDragLine's copy (PhotoWorkspace.dragShowsLineOnly); Free Transform's and
// a Select move runs on LiveTransformCopy (PhotoWorkspace.dragRunsLive(pressAt:)). A press that
// picks a colour (the Eyedropper, or the Brush with Option held at the press:
// PhotoWorkspace.pressPicksColor) picks once, at its first sample, and its
// other samples do nothing (`press`) until the window takes the copy back.
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

/// What a press's drag samples do when the press picks a colour.
enum SamplePress: Equatable {
    /// The press's first sample: pick the colour at this canvas point.
    case pick(Point)
    /// A later sample of the same press: nothing.
    case hold
}

@MainActor final class LiveStroke {
    private var copy = LiveCopy<PhotoWorkspace>()
    /// Whether the press under way picks a colour, decided at its first
    /// sample; nil between presses.
    private var picking: Bool?

    /// What `moves` do if the press under way picks a colour: `.pick` at the
    /// press's first sample, `.hold` after it; nil when the press draws.
    func press(_ moves: [PhotoStrokeMove], on model: PhotoWorkspace) -> SamplePress? {
        if picking == nil, let first = moves.first {
            picking = model.pressPicksColor(modifiers: first.modifiers)
            if picking == true { return .pick(Point(x: first.to.x, y: first.to.y)) }
        }
        return picking == true ? .hold : nil
    }

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

    /// The stroke's copy, handed over once; nil with no stroke live. The
    /// press is over, so the next one decides again whether it picks.
    func take() -> PhotoWorkspace? {
        picking = nil
        return copy.take()
    }
}

extension DragModifiers {
    /// The keys among `flags` a canvas drag reads: Shift and Option.
    init(flags: NSEvent.ModifierFlags) {
        self.init()
        if flags.contains(.shift) { insert(.shift) }
        if flags.contains(.option) { insert(.option) }
    }
}
