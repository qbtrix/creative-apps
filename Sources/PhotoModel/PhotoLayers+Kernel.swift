// PhotoLayers+Kernel.swift: Photo's layer stack run on SuiteKernel's LayerTree
// (adopt-kernel-layers AL-p1). `layers` stays Photo's top-first list; the
// adapter projects it into a single-level tree whose roots are the layers back
// to front (bottom first), runs the kernel's move, arrange, duplicate or
// update on it, and projects the result back. `PhotoLayer` is the payload; a
// node's own id, name and hidden flag win over its payload's, so a duplicate
// keeps the id the kernel gave it. A refusal from the kernel changes nothing.
// The Layers panel (AL-p3) reads `layerRows`, `layerCaption`, `layerListMove`.
// Linux-safe.
import SuiteKernel

extension PhotoLayer: LayerPayload {
    /// Always false: a Photo layer is never a container another layer moves into.
    public var holdsChildren: Bool { false }

    /// This layer under `id`, named `name` and shown when `isVisible`, every
    /// other property kept.
    func relabeled(_ id: String, name: String, isVisible: Bool) -> PhotoLayer {
        var layer = PhotoLayer(id: id, name: name, isVisible: isVisible, opacity: opacity, blendMode: blendMode)
        layer.offsetX = offsetX
        layer.offsetY = offsetY
        layer.kind = kind
        layer.hasMask = hasMask
        layer.isMaskEnabled = isMaskEnabled
        layer.isClipped = isClipped
        return layer
    }
}

extension PhotoWorkspace {
    /// The layers as one kernel tree of roots, back to front (bottom first).
    public var layerTree: LayerTree<PhotoLayer> { Self.layerTree(layers) }

    /// The tree of `topFirst`, Photo's top-first layer list.
    static func layerTree(_ topFirst: [PhotoLayer]) -> LayerTree<PhotoLayer> {
        LayerTree(topFirst.reversed().map {
            LayerNode(id: $0.id, name: $0.name, isHidden: !$0.isVisible, payload: $0)
        })
    }

    /// `tree`'s roots as Photo's top-first layer list.
    static func layers(of tree: LayerTree<PhotoLayer>) -> [PhotoLayer] {
        tree.roots.reversed().map { $0.payload.relabeled($0.id, name: $0.name, isVisible: !$0.isHidden) }
    }

    /// The layers after `edit` runs on their tree; nil when the kernel refuses it.
    static func kernelEdited(
        _ topFirst: [PhotoLayer], _ edit: (inout LayerTree<PhotoLayer>) throws(TreeRefusal) -> Void
    ) -> [PhotoLayer]? {
        var tree = layerTree(topFirst)
        do {
            try edit(&tree)
        } catch {
            return nil
        }
        return layers(of: tree)
    }

    /// `topFirst` with the layers at `offsets` moved before the layer at
    /// `destination` (top-first, as a list drag reports it), through
    /// LayerTree.move: the lowest moving layer goes just above the staying
    /// layer the block lands on (or to the bottom), each next one just above
    /// it. Nil when the kernel refuses a move.
    static func kernelMoved(_ topFirst: [PhotoLayer], fromOffsets offsets: Set<Int>, toOffset destination: Int)
        -> [PhotoLayer]?
    {
        let moving = topFirst.indices.filter { offsets.contains($0) }.map { topFirst[$0].id }
        let staying = topFirst.indices.filter { !offsets.contains($0) }.map { topFirst[$0].id }
        let landing = destination - offsets.filter { $0 < destination }.count
        var anchor = staying.indices.contains(landing) ? staying[landing] : nil
        return kernelEdited(topFirst) { (tree: inout LayerTree<PhotoLayer>) throws(TreeRefusal) in
            for id in moving.reversed() {
                guard let from = tree.roots.firstIndex(where: { $0.id == id }) else { throw .unknown(id) }
                var at = 0
                if let anchor {
                    guard let below = tree.roots.firstIndex(where: { $0.id == anchor }) else { throw .unknown(anchor) }
                    // Taking the layer out first shifts the anchor down when it sat below it.
                    at = below + 1 - (from < below ? 1 : 0)
                }
                try tree.move(id, into: nil, at: at)
                anchor = id
            }
        }
    }

    /// The Layers panel's rows (AL-p3): the tree's rows, top first, flat.
    public var layerRows: [LayerRow] { layerTree.rows(expanded: []) }

    /// The line under layer `id`'s name: `layerInfo`, then the blend summary,
    /// joined by " · "; nil when it has neither.
    public func layerCaption(_ id: PhotoLayer.ID) -> String? {
        let parts = [layerInfo(id), layerBlendSummary(id)?.text].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The `moveLayers` offset and destination for the panel's drop of `id`
    /// into `parent` (only nil, the roots) at `index` from the bottom among
    /// the others; nil for an unknown id, a parent, a bad index or no move.
    public func layerListMove(_ id: PhotoLayer.ID, parent: String?, index: Int) -> (offset: Int, destination: Int)? {
        guard parent == nil, let from = layers.firstIndex(where: { $0.id == id }),
              (0..<layers.count).contains(index) else { return nil }
        // Top first, once the others close up around it.
        let to = layers.count - 1 - index
        guard to != from else { return nil }
        return (from, to < from ? to : to + 1)
    }

    /// Applies kernel-edited `next` as one undo step named `name`; nothing
    /// when the kernel refused (nil) or the order didn't change.
    mutating func commitKernelLayers(_ next: [PhotoLayer]?, named name: String) {
        guard let next, next != layers else { return }
        recordLayers(named: name)
        layers = next
        touch(.all)
    }

    /// The layers with `id` moved one place up (`.bringForward`) or down
    /// (`.sendBackward`) through LayerTree.arrange, as one "Reorder Layers" step.
    mutating func arrangeLayer(_ id: PhotoLayer.ID, _ step: ArrangeStep) {
        commitKernelLayers(
            Self.kernelEdited(layers) { (tree: inout LayerTree<PhotoLayer>) throws(TreeRefusal) in
                try tree.arrange(step, [id])
            }, named: "Reorder Layers")
    }

    /// The layers with a copy of `id` just above it, named `name`, under the
    /// next free layer id, through LayerTree.duplicate; the copy's id, or nil
    /// for an unknown id.
    mutating func kernelDuplicate(_ id: PhotoLayer.ID, named name: String) -> PhotoLayer.ID? {
        var tree = layerTree
        var number = nextLayerNumber
        let copies = tree.duplicate([id]) {
            defer { number += 1 }
            return "layer-\(number)"
        }
        guard let copy = copies.first, tree.update(copy, { $0.name = name }) else { return nil }
        nextLayerNumber = number
        layers = Self.layers(of: tree)
        return copy
    }
}
