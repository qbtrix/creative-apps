// DesignLiveDrag.swift: the live drag box (design-window D0-8a). Every write
// to the window's DesignWorkspace re-runs DesignWindow and lays out the whole
// editor (toolbar, palette, sidebar, inspector, menus), so a canvas drag that
// wrote the workspace per pointer sample ran the window per sample. Instead the
// press goes to the workspace (the selection shows at once) and the later
// samples go here, to a copy of it (DesignLiveEdit) that only DesignCanvas
// reads: `live.workspace ?? model`. Mouse-up (`end(into:)`) replays the last
// sample into the workspace through its own methods, then `endDrag`, so the
// window changes once and records one step. `preview` and `end` do the same
// for an inspector scrub. DesignWindow owns one and hands it down as the
// `designLiveDrag` environment value; without one (a view hosted alone) the
// canvas draws the workspace. Presentation state only.
import DesignModel
import Observation
import SwiftUI

@MainActor @Observable final class DesignLiveDrag {
    private var edit = DesignLiveEdit()

    /// The copy the canvas draws while a drag or scrub lasts; nil with none live.
    var workspace: DesignWorkspace? { edit.workspace }

    /// Starts showing a copy of `model`, after the press went to it.
    func begin(from model: DesignWorkspace) { edit.begin(from: model) }

    /// One pointer sample, run on the copy only.
    func sample(from start: DesignPoint, to end: DesignPoint, modifiers: DesignModifiers) {
        edit.sample(from: start, to: end, modifiers: modifiers)
    }

    /// One value of an inspector scrub, shown on the copy only.
    func preview(_ change: DesignStyleChange) { edit.preview(change) }

    /// Replays the last sample or value into `model` as one step and clears the copy; a refused
    /// value's reason.
    @discardableResult
    func end(into model: inout DesignWorkspace) -> DesignRefusal? { edit.end(into: &model) }
}

extension EnvironmentValues {
    /// The window's live drag box; nil outside a DesignWindow.
    @Entry var designLiveDrag: DesignLiveDrag?
}
