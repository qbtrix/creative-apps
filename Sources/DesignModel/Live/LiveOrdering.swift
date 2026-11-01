// Live/LiveOrdering.swift: Move Layer (the Layers panel's drag) and Object >
// Arrange on the live services (layers-panel L-1, blueprint 5.4). An adapter over
// SuiteKernel's LayerTree (DesignNode+Kernel): the kernel moves and arranges, and
// this file maps its refusals to Design's, by layer name.
//
// Invariants:
// - Move refuses an unknown layer or parent (`.unknownID`), a locked layer or one
//   inside a locked layer (`.locked(name)`, naming the outermost locked layer
//   around it, the one to unlock), a parent that is the layer or below
//   it (`.intoItself(layer's name)`), a parent that is not a frame or group
//   (`.notAContainer(parent's name)`), and a locked target (`.locked`, named the same way).
//   `index` counts the new parent's children back to front after the layer is
//   removed, clamped to that count.
// - Arrange works within each selected layer's own parent and keeps the selected
//   layers' relative order; Bring Forward and Send Backward move one place. A
//   locked layer (or one inside a locked layer) refuses it.
// - A move or arrange that changes nothing throws `.unchanged`; its help is
//   "Nothing would change.". Every other help is nil exactly when the write
//   succeeds, else the refusal's help (the help law).
// - Move is one "Move Layer" step selecting the layer; arrange is one step named
//   `step.title` that keeps the selection.
// Linux-safe.
import SuiteKernel

public struct LiveOrdering: LayerOrdering {
    public init() {}

    public func moveHelp(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) -> String? {
        help { () throws(DesignRefusal) in try move(id, into: parentID, at: index, on: page) }
    }

    public func move(_ id: String, into parentID: String?, at index: Int, on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        var tree = page.nodes.layerTree
        guard let layer = tree.node(id) else { throw .unknownID(id) }
        if let locked = lockedName(id, in: tree) { throw .locked(locked) }
        do throws(TreeRefusal) {
            try tree.move(id, into: parentID, at: index)
        } catch {
            throw refusal(error, moving: layer.name, in: tree)
        }
        let nodes = tree.designNodes
        guard nodes != page.nodes else { throw .unchanged }
        return DesignEdit(name: "Move Layer", nodes: nodes, selection: [id])
    }

    public func arrangeHelp(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) -> String? {
        help { () throws(DesignRefusal) in try arrange(step, ids, on: page) }
    }

    public func arrange(_ step: DesignArrangeStep, _ ids: [String], on page: DesignPage) throws(DesignRefusal) -> DesignEdit {
        guard !ids.isEmpty else { throw .nothingSelected }
        var tree = page.nodes.layerTree
        for id in ids {
            guard tree.node(id) != nil else { throw .unknownID(id) }
            if let locked = lockedName(id, in: tree) { throw .locked(locked) }
        }
        do throws(TreeRefusal) {
            try tree.arrange(step.kernelStep, ids)
        } catch {
            throw refusal(error, moving: ids.last ?? "", in: tree)
        }
        let nodes = tree.designNodes
        guard nodes != page.nodes else { throw .unchanged }
        return DesignEdit(name: step.title, nodes: nodes, selection: ids)
    }

    /// The name of the outermost locked layer at or around `id`; nil when nothing locks it.
    private func lockedName(_ id: String, in tree: LayerTree<DesignNodePayload>) -> String? {
        // One search answers the usual case, nothing locked; naming the lock costs one per ancestor.
        guard tree.isEffectivelyLocked(id) else { return nil }
        return ((tree.ancestors(of: id) ?? []) + [id]).lazy.compactMap { tree.node($0) }.first { $0.isLocked }?.name
    }

    /// The Design refusal for the kernel's `error` on a move of the layer named `name`.
    private func refusal(_ error: TreeRefusal, moving name: String, in tree: LayerTree<DesignNodePayload>) -> DesignRefusal {
        func named(_ id: String) -> String { tree.node(id)?.name ?? id }
        return switch error {
        case .unknown(let id): .unknownID(id)
        case .intoItself, .cycle: .intoItself(name)
        case .notAContainer(let id): .notAContainer(named(id))
        case .locked(let id): .locked(lockedName(id, in: tree) ?? named(id))
        }
    }

    /// The help law: nil when `write` succeeds, else the refusal's help ("Nothing would change." for `.unchanged`).
    private func help(_ write: () throws(DesignRefusal) -> DesignEdit) -> String? {
        do {
            _ = try write()
            return nil
        } catch {
            return error.help
        }
    }
}
