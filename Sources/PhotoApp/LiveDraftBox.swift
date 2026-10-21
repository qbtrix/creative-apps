// LiveDraftBox.swift: the workspace Free Transform's draft edits run on while
// a handle drag or a Rotation scrub lasts (finding #4247), a SuiteKernel
// LiveCopy<PhotoWorkspace>, as LiveDragLine keeps the Gradient line's. Every
// write to the window's workspace re-runs the whole editor, so a drag that ran
// each `transform.set` on it ran the editor per sample. A set, turn or scale
// while a draft is up changes only the draft (PhotoWorkspace.editsDraftOnly),
// so its steps run on the copy here, and only the transform box over the
// canvas and the inspector's transform rows read its `selection`. The window
// takes the copy back once (`take()`): at the handles' release, before any
// other intent, and once the edits rest (`rest`), since a scrub's keys and
// VoiceOver's steps send no end the window hears. Presentation state only.
import Observation
import PhotoModel
import SuiteKernel
import SwiftUI

@MainActor @Observable final class LiveDraftBox {
    @ObservationIgnored private var copy = LiveCopy<PhotoWorkspace>()
    /// The wait before a resting copy goes back; cancelled by each edit.
    @ObservationIgnored private var resting: Task<Void, Never>?
    /// The draft's box on the copy, for the overlay and the rows; nil with no copy live.
    private(set) var selection: TransformBox?

    /// `edit` run as its catalog command on the copy, made from `model` at the first edit; false
    /// when it changes more than the draft, for the window to take the copy back and run it itself.
    /// A refused edit throws, the copy kept.
    func edits(_ edit: SuiteKernel.TransformIntent, on model: PhotoWorkspace) throws(CatalogError) -> Bool {
        guard var live = copy.take() ?? (model.editsDraftOnly(edit) ? model : nil) else { return false }
        defer { copy.begin(live) }
        guard live.editsDraftOnly(edit) else { return false }
        let (id, params) = edit.command
        _ = try PhotoWorkspace.catalog.run(id, params: params, on: &live)
        if selection != live.transformSelection { selection = live.transformSelection }
        return true
    }

    /// Calls `land` once no edit has come for 40 ms (a scrub's steps come every frame); a new
    /// edit's `rest` or a `take()` cancels the wait.
    func rest(then land: @escaping @MainActor () -> Void) {
        resting?.cancel()
        resting = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(40))
            if !Task.isCancelled { land() }
        }
    }

    /// The copy, handed over once; nil with none live.
    func take() -> PhotoWorkspace? {
        resting?.cancel()
        resting = nil
        if selection != nil { selection = nil }
        return copy.take()
    }
}

extension EnvironmentValues {
    /// The window's live Free Transform copy; nil outside a PhotoWindow.
    @Entry var photoDraftBox: LiveDraftBox?
}
