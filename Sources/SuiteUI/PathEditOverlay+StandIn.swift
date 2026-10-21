// PathEditOverlay+StandIn.swift (pen-paths PN-3): the PN-2 overlay's
// `PathContourStandIn` and its marks-only init, kept so a caller still on the
// stand-in (FlareApp's stage) builds while its line moves to the kernel types
// and `onIntent`. The init maps the stand-ins onto a `PenDraft` and a
// `PathInEdit` in document space and turns the gesture off, as PN-2 drew.
// Delete both once no caller uses them.
import SuiteKernel
import SwiftUI

/// One contour as the PN-2 overlay took it: its anchors in order, in document
/// pixels, and whether the last joins the first.
public struct PathContourStandIn: Equatable, Sendable {
    public let anchors: [PathAnchor]
    public let closed: Bool

    public init(anchors: [PathAnchor], closed: Bool) {
        self.anchors = anchors
        self.closed = closed
    }

    /// The kernel contour these anchors describe.
    var contour: VectorContour {
        func point(_ p: CGPoint) -> Point { Point(x: p.x, y: p.y) }
        return VectorContour(
            anchors: anchors.map { anchor in
                VectorAnchor(point: point(anchor.point), handleIn: anchor.handleIn.map(point),
                             handleOut: anchor.handleOut.map(point), kind: anchor.kind == .corner ? .corner : .smooth)
            },
            closed: closed)
    }
}

extension PathEditOverlay {
    /// The PN-2 overlay: `draft` and `path` drawn as marks, nothing selected,
    /// no gesture. Use `init(draft:path:selection:tool:zoom:onIntent:)` to edit.
    public init(draft: PathContourStandIn?, path: [PathContourStandIn], tool: PenTool, zoom: Double) {
        self.init(draft: draft.map { PenDraft(contour: $0.contour, scale: PathMarks.scale(zoom)) },
                  path: path.isEmpty ? nil
                      : PathInEdit(id: "stand-in", path: VectorPath(contours: path.map(\.contour)), toDocument: .identity),
                  selection: Selection(), tool: tool, zoom: zoom) { _ in }
        interactive = false
    }
}
