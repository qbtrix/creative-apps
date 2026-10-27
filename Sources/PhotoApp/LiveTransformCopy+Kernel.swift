// LiveTransformCopy+Kernel.swift: the workspace a Free Transform edit shows while it
// lasts, out of the window's workspace (transform PT-7's render budget). Every
// write to that workspace re-runs and lays out the whole editor (LiveStroke.swift
// says why), and a handle drag or a transform-row scrub sends one catalog
// command per sample, each a draft change under its gesture's token. So those
// samples run on a SuiteKernel LiveCopy of the workspace that only
// TransformOverlay reads, as `shown` (TransformOptions as `rowsShown`, not while a drag holds it), and the canvas draws
// it through CanvasRenderer. The window takes the copy back once (`take()`):
// before any other intent (a handle drag's release sends `endDrag`), and when
// the samples go quiet for `quiet` (the end of a row scrub or of a run of
// VoiceOver steps, each its own gesture). A handle or canvas drag `hold()`s the copy
// with every sample, so a pointer that rests mid-drag gets no quiet hand-back:
// the copy waits for mouse-up (#4795). So the window's workspace,
// its edited dot and its undo stack catch up with one SwiftUI pass. The draft's
// steps fold under their token on the copy, so the undo stack is the same as
// running each sample on the workspace. A tone row's drag samples run on the
// same copy, which the Adjust panel reads (`adjusting`, tone-controls PT-5). PhotoWindow owns one and hands it down
// as the `photoLiveTransform` environment value; without one (a view hosted
// alone) the overlay and rows read the workspace. Presentation state only.
import Observation
import PhotoModel
import SuiteKernel
import SwiftUI

@MainActor @Observable final class LiveTransformCopy {
    @ObservationIgnored private var copy = LiveCopy<PhotoWorkspace>()
    @ObservationIgnored private var settle: Task<Void, Never>?
    /// True while a handle drag holds the copy: no quiet hand-back until `take()`.
    @ObservationIgnored private(set) var held = false
    /// The copy with the latest sample run on it; nil with none live.
    private(set) var shown: PhotoWorkspace?
    /// The copy as the Adjust panel reads it: set only once a sample changes the adjustments it shows (a tone
    /// row's drag), so a transform drag's samples never run the panel.
    private(set) var adjusting: PhotoWorkspace?
    /// The copy as the Transform rows read it: every sample of a row scrub, none of a held handle or canvas
    /// drag (the rows catch up at mouse-up), so a drag's samples don't rerun the inspector.
    private(set) var rowsShown: PhotoWorkspace?
    /// How long the samples stay quiet before the window takes the copy back.
    static let quiet = Duration.milliseconds(50)

    /// Whether a quiet hand-back is waiting.
    var settling: Bool { settle != nil }

    /// Keeps the copy until `take()`: a handle drag's sample, pointer down.
    func hold() {
        held = true
        settle?.cancel()
        settle = nil
    }

    /// Runs `edit` on the copy, made from `model` at the first sample, and
    /// calls `done` once the samples go quiet unless the copy is held; returns the copy.
    func run(
        on model: PhotoWorkspace, done: @escaping @MainActor () -> Void, _ edit: (inout PhotoWorkspace) -> Void
    ) -> PhotoWorkspace {
        var live = copy.take() ?? model
        edit(&live)
        copy.begin(live)
        shown = live
        let panel = adjusting ?? model
        if live.adjustTarget != panel.adjustTarget || live.adjustments != panel.adjustments { adjusting = live }
        if !held { rowsShown = live }
        settle?.cancel()
        settle = nil
        if held { return live }
        settle = Task { @MainActor in
            do { try await Task.sleep(for: Self.quiet) } catch { return }
            done()
        }
        return live
    }

    /// The copy, handed over once, and nothing shown; nil with none live.
    func take() -> PhotoWorkspace? {
        settle?.cancel()
        settle = nil
        held = false
        if shown != nil { shown = nil }
        if adjusting != nil { adjusting = nil }
        if rowsShown != nil { rowsShown = nil }
        return copy.take()
    }
}

extension EnvironmentValues {
    /// The window's live transform; nil outside a PhotoWindow.
    @Entry var photoLiveTransform: LiveTransformCopy?
}
