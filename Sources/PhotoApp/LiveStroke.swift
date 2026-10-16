// LiveStroke.swift: the workspace a paint stroke draws on while it lasts.
// The window keeps its workspace in State, and every write to it re-runs and
// lays out the whole editor on the main actor (top bar, rail, panels, menus,
// the checkerboard behind the picture): a SwiftUI pass per pointer sample. A
// brush, eraser, clone or heal drag changes only pixels
// (PhotoWorkspace.dragPaintsOnly), so its samples go to a copy kept here, out
// of SwiftUI's sight, and the tile canvas shows each one through
// CanvasRenderer. The window takes the copy back once (`take()`): at the
// drag's end, before any other intent, before the status message clears, and
// at once when a sample set a status message, so a refusal shows at the
// press. Other tools' drags (marquee, crop, move, eyedropper) show through
// the panels and overlays, so they still go to the window's workspace.
// Presentation state only.
import PhotoModel

@MainActor final class LiveStroke {
    private var workspace: PhotoWorkspace?

    /// `moves` drawn on the stroke's copy, made from `model` at the first;
    /// nil when the drag doesn't only paint, for the window to apply itself.
    func drags(_ moves: [StrokePacer.Move], on model: PhotoWorkspace, zoom: Double) -> PhotoWorkspace? {
        guard workspace != nil || model.dragPaintsOnly else { return nil }
        var live = workspace ?? model
        // The copy's only owner here, so the drags write its tiles in place.
        workspace = nil
        live.drags(moves, zoom: zoom)
        workspace = live
        return live
    }

    /// The stroke's copy, handed over once; nil with no stroke live.
    func take() -> PhotoWorkspace? {
        defer { workspace = nil }
        return workspace
    }
}
