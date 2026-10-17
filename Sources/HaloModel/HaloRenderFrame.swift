// HaloRenderFrame.swift: Render Frame (⌘R, render-out RO-2, #451). Renders
// the selected composition at its playhead at preview size through the
// project's own `services.rendering` and `services.text`, and keeps the frame
// with the composition it came from in `renderedFrame`, the one property this
// file writes. Staleness is computed, never stored: the playhead lives in
// `HaloComposition`, so a scrub, a tick or any edit makes the frame stale, and
// scrubbing back or undoing to the same composition makes it fresh again. Not
// an edit: records no undo step. Linux-safe: no UI imports.

extension HaloProject {
    /// Renders the selected composition at its playhead at a quarter size
    /// (480 × 270 for 1080p) and keeps it as the shown frame. Does nothing
    /// with no composition selected; a render that fails leaves no frame.
    public mutating func renderCurrentFrame() {
        guard let comp = selectedComposition else { return }
        renderedFrame = renderSelectedFrame(at: comp.playheadFrame).map { HaloShownFrame(frame: $0, source: comp) }
    }

    /// Whether the rendered frame no longer matches the selected composition:
    /// another playhead, any edit, or another composition selected.
    public var renderedFrameStale: Bool {
        renderedFrame.map { $0.source != selectedComposition } ?? false
    }

    /// The rendered frame the viewer shows: nil when there is none, when it
    /// came from another composition, or while playback runs.
    public var shownRenderedFrame: HaloRenderedFrame? {
        guard let shown = renderedFrame, shown.source.id == selectedCompositionID, !playback.playing else { return nil }
        return shown.frame
    }

    /// The note under the shown frame: "Rendered frame is out of date." when
    /// stale, else the frame's undrawn-text note; nil when nothing is shown.
    public var renderedFrameNote: String? {
        guard let frame = shownRenderedFrame else { return nil }
        return renderedFrameStale ? "Rendered frame is out of date." : frame.note
    }

    /// The shown frame's accessibility value: "Rendered frame 12 at 480 × 270".
    public var renderedFrameSummary: String? {
        shownRenderedFrame.map { "Rendered frame \($0.frame) at \($0.pixels.width) × \($0.pixels.height)" }
    }
}
