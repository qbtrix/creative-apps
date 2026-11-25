// PhotoAgentActivity+Kernel.swift: Photo's side of the AI tab (#6029), an
// adapter onto SuiteKernel's AgentRequests. `agentRequests` groups the agent
// steps of this image's history (`History.agentSteps`, timed by PhotoHistory's
// `agentDates`); with none the tab shows its empty state. A step's layers come from its undo payload, which
// is cheap and needs no extra state: a tile or mask edit names its layer; a
// layer-list or whole-stack edit is diffed by id against the list right after
// that step, the next list-carrying step's before-list or the layers now (new
// ids were created, a differing value was changed), so a later user edit
// never lands in an agent's request. `setLayersHidden`
// is the tab's eye, one "Hide Agent Layers"/"Show Agent Layers" step;
// `selectLayers` picks exactly the live ones of the ids. `agentWork` feeds the
// tab's working marks. Linux-safe.
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SuiteKernel

extension PhotoWorkspace {
    /// The agent's requests in this image, newest first.
    public var agentRequests: [AgentRequest] {
        let after = layersAfterEachStep
        return AgentRequests.group(history.kernel.agentSteps(dates: history.agentDates) { step, _ in
            step.payload.layerIDs(now: after[step.idAfter] ?? layers)
        })
    }

    /// The layer list right after each applied step, by `idAfter`: the next list-carrying step's before-list
    /// (steps between them leave the list alone), or the layers now after the last one.
    private var layersAfterEachStep: [Int: [PhotoLayer]] {
        var out: [Int: [PhotoLayer]] = [:]
        var after = layers
        for step in history.kernel.undoSteps.reversed() {
            out[step.idAfter] = after
            if let before = step.payload.layerList { after = before }
        }
        return out
    }

    /// The open request and the newest agent step: what the AI tab's working marks read (SuiteUI AgentWorking).
    public var agentWork: AgentWork { history.kernel.agentWork }

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
    /// `now` is the list right after that step (`layersAfterEachStep`), so a later edit never counts.
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

    /// The layer list as it was before this edit, when the edit carries one.
    var layerList: [PhotoLayer]? {
        switch self {
        case .layers(let before, _): before
        case .stack(let stack): stack.layers
        case .group(let edits): edits.lazy.compactMap(\.layerList).first
        case .tiles, .maskTiles, .adjustments, .selection, .draft, .paths, .area: nil
        }
    }

    private static func diff(_ before: [PhotoLayer], _ now: [PhotoLayer]) -> [PhotoLayer.ID] {
        now.filter { layer in before.first { $0.id == layer.id } != layer }.map(\.id)
    }
}
