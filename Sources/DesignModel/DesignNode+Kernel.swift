// DesignNode+Kernel.swift: a Design page's node tree projected into SuiteKernel's
// LayerTree and back (layers-panel L-1). The kernel owns nesting, back-to-front
// order, the lock cascade, moves with their refusals and arrange; Design keeps
// its own node fields in the payload. A node becomes a layer with the same id,
// name, hide and lock flags and its children as layer children; the payload is
// the node without its children, and it holds children exactly when its kind
// does (a frame or a group). Converting back rebuilds each node from its payload
// with the layer's name, flags and children, so the round trip is the identity.
// Linux-safe.
import SuiteKernel

/// A Design node as the kernel's layer payload: every field but its children.
/// (Qualified: LiveClipboard has its own LayerPayload, the copied layers.)
struct DesignNodePayload: SuiteKernel.LayerPayload {
    /// The node with `children` empty; the layer holds the children.
    let node: DesignNode

    /// True for a frame or a group, the kinds another layer can move into.
    var holdsChildren: Bool { node.kind.holdsChildren }
}

extension DesignNode {
    /// This node and its subtree as one kernel layer.
    var layerNode: LayerNode<DesignNodePayload> {
        var bare = self
        bare.children = []
        return LayerNode(id: id, name: name, isHidden: isHidden, isLocked: isLocked,
                         children: children.map { $0.layerNode }, payload: DesignNodePayload(node: bare))
    }

    /// The node `layer` holds, with the layer's id, name, flags and children.
    init(layer: LayerNode<DesignNodePayload>) {
        self.init(id: layer.id, copying: layer.payload.node)
        name = layer.name
        isHidden = layer.isHidden
        isLocked = layer.isLocked
        children = layer.children.map { DesignNode(layer: $0) }
    }
}

extension [DesignNode] {
    /// These top-level nodes (back to front) as one kernel tree.
    var layerTree: LayerTree<DesignNodePayload> { LayerTree(map { $0.layerNode }) }
}

extension LayerTree where Payload == DesignNodePayload {
    /// The tree's roots as a page's top-level nodes, back to front.
    var designNodes: [DesignNode] { roots.map { DesignNode(layer: $0) } }
}

extension DesignArrangeStep {
    /// The kernel's arrange step for this command.
    var kernelStep: ArrangeStep {
        switch self {
        case .bringToFront: .bringToFront
        case .bringForward: .bringForward
        case .sendBackward: .sendBackward
        case .sendToBack: .sendToBack
        }
    }
}
