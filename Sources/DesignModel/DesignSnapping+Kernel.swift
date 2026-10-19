// DesignSnapping+Kernel.swift (snapping SN-1 with SN-12): Design's side of the
// snap contract on the editor kernel's snap module (Sources/SuiteKernel/Snap).
// The guide types are the kernel's under Design names; the candidates a drag can
// line up with come from `Snapping.candidates` over the selected page's layer
// tree (DesignNode+Kernel.swift): the moving layers' siblings and parent frames,
// or the children of the frame a draw goes into and that frame, then the page.
// Hidden layers and the moving subtrees are skipped, locked layers kept.
// `DesignModifiers.noSnap` turns layer snapping off for a step (⌘ held, or View >
// Snap to Layers off); whole points still apply. `snapGuides` is a stub (SN-9): the
// kernel's fixed `.fake` set while a gesture runs, nil otherwise, until the gesture
// routes (SN-4) fill it. Linux-safe.
import SuiteKernel

/// A line the moving box sits on after a snapped step, in document points.
public typealias DesignSnapLine = SnapLine
/// A labelled gap: from the moving box to a neighbour, or one of a pair of equal gaps.
public typealias DesignSnapGap = SnapGap
/// The guides one drag shows: its lines and its gaps.
public typealias DesignSnapGuides = SnapGuides
/// A box a drag can line up with: a layer, or the page (id nil).
public typealias DesignSnapCandidate = SnapCandidate

extension DesignModifiers {
    /// Layer snapping off for this step: ⌘ held, or View > Snap to Layers off. Whole points still apply.
    public static let noSnap = DesignModifiers(rawValue: 4)

    /// The modifiers of one pointer step: `.noSnap` when `command` or when `snapToLayers` is false.
    public init(shift: Bool, option: Bool, command: Bool, snapToLayers: Bool) {
        self = []
        if shift { insert(.shift) }
        if option { insert(.option) }
        if command || !snapToLayers { insert(.noSnap) }
    }
}

public enum DesignSnapSettings {
    /// The defaults key View > Snap to Layers writes; a missing value reads as on.
    public static let defaultsKey = "design.snapToLayers"
}

extension DesignWorkspace {
    /// The guides of the drag under way: nil when no gesture runs, empty when one runs and
    /// nothing lined up. A stub until the routes land: the kernel's `.fake` while a gesture runs
    /// (SN-9), so the screen has a set to draw; SN-4 replaces it with the live set.
    public var snapGuides: DesignSnapGuides? {
        guard gesture != nil else { return nil }
        return .fake
    }

    /// The boxes a drag of `moving` on the selected page can line up with: the siblings of each
    /// moving layer and the frame they sit in (a draw into `parent`: that frame's children and the
    /// frame), then the page. Skips hidden layers, the moving layers and everything inside them;
    /// locked layers count. Empty with no page open.
    public func snapCandidates(moving: [String], drawingInto parent: String?) -> [DesignSnapCandidate] {
        guard let page = selectedPage else { return [] }
        let bounds = Rect(minX: 0, minY: 0, maxX: page.frameWidth, maxY: page.frameHeight)
        return Snapping.candidates(in: page.nodes.layerTree, moving: moving, drawingInto: parent, page: bounds) {
            let box = $0.payload.node.frame
            return Rect(minX: box.x, minY: box.y, maxX: box.maxX, maxY: box.maxY)
        }
    }
}
