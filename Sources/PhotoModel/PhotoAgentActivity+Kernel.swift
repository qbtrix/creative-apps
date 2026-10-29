// PhotoAgentActivity+Kernel.swift: Photo's side of the AI tab (#6029), an
// adapter onto SuiteKernel's AgentRequests. `agentRequests` groups the agent
// steps of this image's history; until History records each step's origin
// (#6028, `StepOrigin.agent(client:request:)`) there are none, so the tab
// shows its empty state. A step's layers come from its undo payload, which
// is cheap and needs no extra state: a tile or mask edit names its layer; a
// layer-list or whole-stack edit is diffed by id against the layers now
// (new ids were created, a differing value was changed). `setLayersHidden`
// is the tab's eye, one "Hide Agent Layers"/"Show Agent Layers" step;
// `selectLayers` picks exactly the live ones of the ids. Linux-safe.
import SuiteKernel

extension PhotoWorkspace {
    /// The agent's requests in this image, newest first.
    public var agentRequests: [AgentRequest] { AgentRequests.group(agentSteps) }

    /// The applied agent steps, oldest first. Wire: agent-provenance (#6028) maps
    /// `history.kernel.undoSteps` whose `origin` is `.agent(client:request:)` to records,
    /// keyed by `idAfter`, with `payload.layerIDs(now: layers)` for their layers and the
    /// time from a `[idAfter: Date]` the workspace stamps on record (History carries no date).
    var agentSteps: [AgentStepRecord] { [] }

    /// Hides or shows every live layer in `ids` as one step; nothing when none changes.
    public mutating func setLayersHidden(_ ids: [PhotoLayer.ID], hidden: Bool) {
        let targets = layers.filter { ids.contains($0.id) && $0.isVisible == hidden }.map(\.id)
        guard !targets.isEmpty else { return }
        commitKernelLayers(
            Self.kernelEdited(layers) { tree in
                for target in targets { _ = tree.update(target) { $0.isHidden = hidden } }
            },
            named: hidden ? "Hide Agent Layers" : "Show Agent Layers")
    }

    /// Picks exactly the live layers among `ids`; nothing when none is live.
    public mutating func selectLayers(_ ids: [PhotoLayer.ID]) {
        let live = layers.map(\.id).filter(ids.contains)
        guard !live.isEmpty else { return }
        layerSelection.replace(live)
    }
}

extension PhotoEdit {
    /// The layers the step that recorded this undo payload created or changed.
    // ponytail: list and stack edits diff against the layers now, not the step's own after-state, so a
    // later edit to the same layer also counts; a per-step after-list in History fixes it if it matters.
    func layerIDs(now: [PhotoLayer]) -> [PhotoLayer.ID] {
        switch self {
        case .tiles(let layer, _), .maskTiles(let layer, _): [layer]
        case .layers(let before, _): Self.diff(before, now)
        case .stack(let stack): Self.diff(stack.layers, now)
        case .group(let edits):
            edits.flatMap { $0.layerIDs(now: now) }.reduce(into: []) { if !$0.contains($1) { $0.append($1) } }
        case .adjustments, .selection, .draft, .paths, .area: []
        }
    }

    private static func diff(_ before: [PhotoLayer], _ now: [PhotoLayer]) -> [PhotoLayer.ID] {
        now.filter { layer in before.first { $0.id == layer.id } != layer }.map(\.id)
    }
}
