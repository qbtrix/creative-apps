// FlareLayers+Kernel.swift: the edited owner's FlareCore layers projected into SuiteKernel's LayerTree
// (adopt-kernel-layers AL-f1). FlareCore keeps layers bottom first, which is the tree's back-to-front root order,
// so the tree's frontToBack and rows are the panel's top-first order. A panel move runs through LayerTree.move;
// the index the kernel leaves the layer at is the one FlareCore's ReorderLayer is given. Edits stay FlareCore
// commands: the tree is a read, rebuilt from the document each time. A LayerTreeList reorder drop (AL-f3) names the
// layer and its kernel index among the roots; `layerMove` turns that into moveLayer's top-first row offsets.
import FlareCore
import SuiteKernel

/// What a Flare layer stores in the kernel's tree: nothing more than its node, and no children (Flare layers are flat).
public struct FlareLayerPayload: LayerPayload {
    /// Always false: a Flare layer is never a container another layer moves into.
    public var holdsChildren: Bool { false }
    public init() {}
}

extension FlareWorkspace {
    /// The edited owner's layers as one kernel tree of roots, back to front; empty with no owner.
    public var layerTree: LayerTree<FlareLayerPayload> { Self.layerTree(ownerLayers ?? []) }

    /// The layers panel's rows, top first: one root row per layer with its name and own hide and lock flags.
    public var layerRows: [LayerRow] { layerTree.rows(expanded: []) }

    /// moveLayer's `from` and `to` (top-first row offsets) for a panel drop of layer `id` into `parent` at `index`,
    /// counted from the back among the roots once `id` leaves them, as LayerTreeList.reorder proposes it. Nil for a
    /// drop into a layer (Flare's layers are flat), an unknown layer or an index past the roots.
    public func layerMove(_ id: String, parent: String?, index: Int) -> (from: Int, to: Int)? {
        let rows = layerRows
        let source = parent == nil && rows.indices.contains(index) ? rows.firstIndex { $0.id == id } : nil
        return source.map { from in
            let row = rows.count - 1 - index
            return (from, row > from ? row + 1 : row)
        }
    }

    /// The tree of `backToFront`, FlareCore's bottom-first layer list; a layer's `parentID` is its follow link (AN-10).
    static func layerTree(_ backToFront: [Layer]) -> LayerTree<FlareLayerPayload> {
        LayerTree(backToFront.map {
            LayerNode(id: $0.id, name: $0.name, isHidden: !$0.isVisible, isLocked: $0.isLocked,
                      followsID: $0.parentID, payload: FlareLayerPayload())
        })
    }

    /// `backToFront` in the tree's front-to-back order, top first.
    static func frontToBack(_ backToFront: [Layer]) -> [Layer] {
        let byID = Dictionary(backToFront.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return layerTree(backToFront).frontToBack.compactMap { byID[$0] }
    }

    /// The bottom-first index LayerTree.move leaves layer `id` at when it moves to panel row `row` (top first);
    /// nil when the kernel refuses the move.
    static func kernelReorderIndex(_ id: String, toRow row: Int, in backToFront: [Layer]) -> Int? {
        var tree = layerTree(backToFront)
        let count = tree.roots.count
        do {
            try tree.move(id, into: nil, at: count - 1 - row)
        } catch {
            return nil
        }
        return tree.roots.firstIndex { $0.id == id }
    }
}
