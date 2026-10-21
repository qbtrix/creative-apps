// DesignTransform+Kernel.swift (transform DT-1 stubs, DT-5 bodies): Design's workspace is a kernel
// `TransformTarget`, so the six transform.* commands in `TransformCommands` turn, scale and mirror the
// selected layers the way the other apps' do. A node's `TransformBox` is its unturned `frame` with its
// `rotation`, `flipX` and `flipY`; no Design rotate maths, every point comes from `TransformRules`.
// `runTransform` sends an inspector, menu or knob gesture through `catalog`. Until DT-5 the set throws
// `notBuilt`, the catalog has no transform commands (DT-6), `turnHelp` says so, and `contains`
// answers by the unturned frame, so the rows and Object items are off with that reason. Linux-safe.
import SuiteKernel

// `transformHelp`, the requirement's "why not", is the workspace's own (DesignActions): the help a
// drag's move and resize already give, nothing selected, editing text, or a locked layer.
extension DesignWorkspace: TransformTarget {
    /// The primary selected node's box; nil with nothing selected. DT-5 makes several the union, unturned.
    public var transformSelection: TransformBox? { selectedNode?.transformBox }

    /// Why the inspector's Rotation and Flip rows and Object's turn and flip items are off; nil when they
    /// can act. Stub: after `transformHelp` it says turning isn't built; DT-5 makes it `transformHelp`.
    public var turnHelp: String? {
        transformHelp ?? DesignRefusal.notBuilt("Turning and mirroring a layer").help
    }

    /// Sets every selected unlocked node's box, each about its share of the selection, as one step named
    /// `name`; steps under one `drag` fold into one. Stub: refuses; DT-5 builds it.
    public mutating func setTransform(_ t: TransformBox, name: String, drag: String?) throws {
        throw DesignRefusal.notBuilt("Turning and mirroring a layer")
    }

    /// Runs a transform gesture as its command through `catalog`. A refusal changes nothing; the window
    /// shows `transformHelp` as the reason. Until DT-6 registers the transform specs every gesture refuses.
    public mutating func runTransform(_ intent: TransformIntent) {
        let (id, params) = intent.command
        _ = try? Self.catalog.run(id, params: params, on: &self)
    }
}

extension DesignNode {
    /// This node's frame, turn and mirrors as the kernel's box.
    public var transformBox: TransformBox {
        TransformBox(box: frame.kernelRect, degrees: rotation, flipX: flipX, flipY: flipY)
    }

    /// Whether `point` is inside the node's turned outline; the edges count. `[DesignNode].hit(at:)` asks
    /// this. Stub: the unturned frame; DT-5 tests the point in the box's own space (`TransformRules.local`).
    public func contains(_ point: DesignPoint) -> Bool {
        frame.contains(point)
    }
}
