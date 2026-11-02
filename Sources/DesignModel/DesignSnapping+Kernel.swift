// DesignSnapping+Kernel.swift (snapping SN-1 with SN-12): Design's side of the
// snap contract on the editor kernel's snap module (Sources/SuiteKernel/Snap).
// The guide types are the kernel's under Design names; the candidates a drag can
// line up with come from `Snapping.candidates` over the selected page's layer
// tree (DesignNode+Kernel.swift): the moving layers' siblings and parent frames,
// or the children of the frame a draw goes into and that frame, then the page.
// Hidden layers and the moving subtrees are skipped, locked layers kept.
// `DesignModifiers.noSnap` turns layer snapping off for a step (⌘ held, or View >
// Snap to Layers off); whole points still apply. A press builds a `DesignSnapIndex`
// (SN-4); `snapGuides` reads the live step's guides. Linux-safe.
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
    /// nothing lined up (or `.noSnap` holds); the lines and gaps of its last step otherwise (SN-4).
    public var snapGuides: DesignSnapGuides? {
        gesture?.guides
    }

    /// The boxes a drag of `moving` on the selected page can line up with: the siblings of each
    /// moving layer and the frame they sit in (a draw into `parent`: that frame's children and the
    /// frame), then the page. Skips hidden layers, the moving layers and everything inside them;
    /// locked layers count. Empty with no page open.
    public func snapCandidates(moving: [String], drawingInto parent: String?) -> [DesignSnapCandidate] {
        guard let page = shownPage else { return [] }
        let bounds = Rect(minX: 0, minY: 0, maxX: page.frameWidth, maxY: page.frameHeight)
        return Snapping.candidates(in: page.nodes.layerTree, moving: moving, drawingInto: parent, page: bounds) {
            $0.payload.node.frame.snapRect
        }
    }
}

extension DesignRect {
    /// This rectangle as the kernel's `Rect`, by its corners.
    var snapRect: Rect { Rect(minX: x, minY: y, maxX: maxX, maxY: maxY) }
}

/// The snap engine a gesture builds at its press, over its candidates. Equal by its candidates.
struct DesignSnapIndex: Sendable, Equatable {
    let candidates: [DesignSnapCandidate]
    let lines: SnapLines
    let gaps: SnapGaps

    init(_ candidates: [DesignSnapCandidate]) {
        (self.candidates, lines, gaps) = (candidates, SnapLines(candidates), SnapGaps(candidates))
    }

    static func == (lhs: DesignSnapIndex, rhs: DesignSnapIndex) -> Bool { lhs.candidates == rhs.candidates }

    /// `delta` plus, per axis, the offset within `tolerance` putting `box` + `delta` on a line, else a gap.
    func snapped(_ delta: DesignPoint, box: DesignRect, tolerance: Double) -> DesignPoint {
        let rect = DesignRect(x: box.x + delta.x, y: box.y + delta.y, width: box.width, height: box.height).snapRect
        func offset(_ axis: SnapLine.Axis, _ values: [Double]) -> Double {
            let d = Snapping.offset(
                lines: lines.offset(axis, for: values, tolerance: tolerance),
                gaps: gaps.spacingOffset(axis, for: rect, tolerance: tolerance), wholePoints: 0)
            return d.isFinite ? d : 0
        }
        let dx = offset(.x, [rect.minX, (rect.minX + rect.maxX) / 2, rect.maxX])
        let dy = offset(.y, [rect.minY, (rect.minY + rect.maxY) / 2, rect.maxY])
        return DesignPoint(x: delta.x + dx, y: delta.y + dy)
    }

    /// The lines `box` sits on and the gaps around it, to draw once a step has landed.
    func guides(on box: DesignRect) -> DesignSnapGuides {
        DesignSnapGuides(lines: lines.lines(on: box.snapRect), gaps: gaps.gaps(around: box.snapRect))
    }
}
