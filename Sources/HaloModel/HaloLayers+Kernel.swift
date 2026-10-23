// HaloLayers+Kernel.swift: Halo's layer list run on SuiteKernel's LayerTree
// (adopt-kernel-layers AL-h1). `HaloComposition.layers` stays Halo's top-first
// list; the adapter projects it into a single-level tree whose roots are the
// layers back to front (bottom first), each node following its layer's
// `parentID` (the file keeps that key), runs one kernel edit on it, and
// projects the result back. A node's own id, name and follow link win over
// its payload's, so a duplicate keeps the id it was given. A refusal from the
// kernel throws Halo's own error and changes nothing. Linux-safe.
import SuiteKernel

extension HaloLayer: LayerPayload {
    /// Always false: a Halo layer is never a container another layer moves into.
    public var holdsChildren: Bool { false }
}

extension HaloComposition {
    /// The layers as one kernel tree of roots, back to front (bottom first);
    /// each node follows its layer's `parentID`.
    public var layerTree: LayerTree<HaloLayer> {
        LayerTree(layers.reversed().map { LayerNode(id: $0.id, name: $0.name, followsID: $0.parentID, payload: $0) })
    }

    /// `tree`'s roots as Halo's top-first layer list.
    static func layers(of tree: LayerTree<HaloLayer>) -> [HaloLayer] {
        tree.roots.reversed().map { node in
            var layer = node.payload.id == node.id ? node.payload : node.payload.withID(node.id)
            layer.name = node.name
            layer.parentID = node.followsID
            return layer
        }
    }

    /// Runs `edit` on the layer tree and keeps its result. A kernel refusal
    /// throws Halo's error for it (`refusal(_:)`) and changes nothing.
    mutating func editLayerTree(_ edit: (inout LayerTree<HaloLayer>) throws(TreeRefusal) -> Void) throws {
        var tree = layerTree
        do {
            try edit(&tree)
        } catch {
            throw refusal(error)
        }
        layers = Self.layers(of: tree)
    }

    /// Halo's error for a kernel refusal: a cycle is `.parentCycle(<the
    /// layer's name>)`; anything else names a layer the list can't use.
    func refusal(_ refused: TreeRefusal) -> HaloEditError {
        switch refused {
        case .cycle(let id): .parentCycle(layers.first { $0.id == id }?.name ?? id)
        case .unknown(let id), .intoItself(let id), .notAContainer(let id), .locked(let id): .unknownLayer(id)
        }
    }
}
