// DesignLiveDrag.swift: the live drag box (design-window D0-8a). Every write
// to the window's DesignWorkspace re-runs DesignWindow and lays out the whole
// editor (toolbar, palette, sidebar, inspector, menus), so a canvas drag that
// wrote the workspace per pointer sample ran the window per sample. Instead the
// press goes to the workspace (the selection shows at once) and the later
// samples go here, to a copy of it (DesignLiveEdit) that only DesignCanvas
// reads: `live.workspace ?? model`. Mouse-up (`land(into:)`) replays the last
// sample into the workspace through its own methods, then `endDrag`, so the
// window changes once and records one step; the window writes that workspace
// and `clearAfterLanding()` drops the copy a turn later, so the canvas never
// draws the old workspace in between. `preview` and `land` do the same for an
// inspector scrub, a style row's or the Rotation bar's. DesignWindow owns one and hands it down as the
// `designLiveDrag` environment value; without one (a view hosted alone) the
// canvas draws the workspace. Presentation state only.
import DesignModel
import Observation
import SuiteKernel
import SwiftUI

@MainActor @Observable final class DesignLiveDrag {
    private var edit = DesignLiveEdit()
    /// Set from `clearAfterLanding()` until its clear runs: the copy still shows, but nothing is live.
    @ObservationIgnored private var isLanding = false

    /// The copy the canvas draws while a drag or scrub lasts; nil with none live.
    var workspace: DesignWorkspace? { edit.workspace }
    /// A drag or scrub is under way: the next sample or value goes to the copy, not a new `begin`.
    var isLive: Bool { workspace != nil && !isLanding }

    /// Starts showing a copy of `model`, after the press went to it.
    func begin(from model: DesignWorkspace) {
        isLanding = false
        edit.begin(from: model)
    }

    /// One pointer sample, run on the copy only.
    func sample(from start: DesignPoint, to end: DesignPoint, modifiers: DesignModifiers) {
        edit.sample(from: start, to: end, modifiers: modifiers)
    }

    /// One value of an inspector scrub, shown on the copy only.
    func preview(_ change: DesignStyleChange) { edit.preview(change) }

    /// One value of a transform scrub, shown on the copy only.
    func preview(_ intent: TransformIntent) { edit.preview(intent) }

    /// Replays the last sample or value into `model` as one step; a refused value's reason. The
    /// copy stays shown until `clear()` or `clearAfterLanding()`.
    @discardableResult
    func land(into model: inout DesignWorkspace) -> DesignRefusal? {
        var done = edit
        return done.end(into: &model)
    }

    /// Stops showing the copy.
    func clear() {
        isLanding = false
        edit = DesignLiveEdit()
    }

    /// Stops showing the copy on the next main-actor turn, once the window has passed the canvas
    /// the workspace `land(into:)` wrote. Clearing at once let the canvas, which watches this box
    /// and not the window, draw the old workspace for a frame: the dragged layer back at its start
    /// and the guides gone. A `begin` before then keeps its copy.
    func clearAfterLanding() {
        isLanding = true
        Task { @MainActor [weak self] in if self?.isLanding == true { self?.clear() } }
    }

    /// `land(into:)`, then `clear()`; a refused value's reason.
    @discardableResult
    func end(into model: inout DesignWorkspace) -> DesignRefusal? {
        defer { clear() }
        return land(into: &model)
    }
}

extension EnvironmentValues {
    /// The window's live drag box; nil outside a DesignWindow.
    @Entry var designLiveDrag: DesignLiveDrag?
}
