// HaloLiveEdit.swift: the project a drag shows while it lasts, out of the
// window's State. Every write to the window's HaloProject re-runs HaloWindow
// and lays out the whole window (sidebar, menus, every lane and row), so a
// viewer drag or an inspector scrub that wrote the project per mouse sample
// ran the window per sample. Instead each sample puts the window's current
// project with that sample applied (through the Model's own methods, `show`)
// here, and only the views that read `project` re-run: the viewer's drawn
// layers. A view that previews this way needs no project of its own, so the
// inspector's rows compare as plain values and skip frames that leave them
// unchanged. The drag's
// end sends its last value to the window as before, so the window changes
// once and records one step. HaloWindow owns one and hands it down as the
// `haloLiveEdit` environment value; without one (a view hosted alone) a drag
// writes the window per sample, as it used to. Presentation state only.
import HaloModel
import Observation
import SwiftUI

@MainActor @Observable final class HaloLiveEdit {
    /// The window's project with the live drag's latest sample applied; nil
    /// with no drag live.
    var project: HaloProject?
    /// The window's project now; HaloWindow sets it once it appears.
    @ObservationIgnored var current: @MainActor () -> HaloProject? = { nil }

    /// Shows the window's current project with `change` applied; nothing
    /// before the window has set `current`.
    func show(_ change: (inout HaloProject) -> Void) {
        guard var shown = current() else { return }
        change(&shown)
        project = shown
    }
}

extension EnvironmentValues {
    /// The window's live drag; nil outside a HaloWindow.
    @Entry var haloLiveEdit: HaloLiveEdit?
}
