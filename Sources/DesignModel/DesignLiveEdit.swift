// DesignLiveEdit.swift: the copy of the workspace a canvas drag or an inspector
// scrub shows while it lasts (design-window D0-8a). The press goes to the
// workspace itself, so the selection shows at once; `begin(from:)` then takes
// a copy, each later sample reruns the gesture on that copy (`sample`) or sets
// the scrubbed value on the copy taken at `begin` (`preview`), and the
// workspace is left alone. `end(into:)` replays the last sample or value into
// the workspace through its own methods (`drag` then `endDrag`, or `setStyle`
// then `endEditRun`), so the gesture lands as the one undo step it would have
// been sample by sample, and clears the copy. DesignApp's DesignLiveDrag holds
// one where SwiftUI can watch it without the window. Linux-safe.

/// A drag or scrub shown on a copy of the workspace until it ends.
public struct DesignLiveEdit: Sendable, Equatable {
    /// What `end(into:)` replays.
    private enum Last: Sendable, Equatable {
        case drag(from: DesignPoint, to: DesignPoint, modifiers: DesignModifiers)
        case style(DesignStyleChange)
    }

    /// The copy the canvas draws while a gesture lasts; nil with none live.
    public private(set) var workspace: DesignWorkspace?
    /// The workspace as `begin` found it, the base every preview starts from.
    private var base: DesignWorkspace?
    private var last: Last?

    public init() {}

    /// Starts showing a copy of `model` (after the press went to it).
    public mutating func begin(from model: DesignWorkspace) {
        (workspace, base, last) = (model, model, nil)
    }

    /// One pointer sample of the gesture, run on the copy only. Nothing before `begin`.
    public mutating func sample(from start: DesignPoint, to end: DesignPoint, modifiers: DesignModifiers = []) {
        guard workspace != nil else { return }
        workspace?.drag(from: start, to: end, modifiers: modifiers)
        last = .drag(from: start, to: end, modifiers: modifiers)
    }

    /// One value of an inspector scrub, set on the copy `begin` took, so the copy holds one change
    /// however many values came before. A refused change shows the base. Nothing before `begin`.
    public mutating func preview(_ change: DesignStyleChange) {
        guard var shown = base else { return }
        try? shown.setStyle(change)
        workspace = shown
        last = .style(change)
    }

    /// Replays the last sample or value into `model` and ends it there as one step, then clears
    /// the copy. A drag with no sample after the press only ends. Returns a refused value's reason.
    @discardableResult
    public mutating func end(into model: inout DesignWorkspace) -> DesignRefusal? {
        defer { (workspace, base, last) = (nil, nil, nil) }
        switch last {
        case .drag(let start, let end, let modifiers):
            model.drag(from: start, to: end, modifiers: modifiers)
            model.endDrag()
        case .style(let change):
            defer { model.endEditRun() }
            do { try model.setStyle(change) } catch { return error }
        case nil:
            model.endDrag()
        }
        return nil
    }
}
