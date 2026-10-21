// PathEditOverlay+StandIn.swift (pen-paths PN-3): PN-2's `PathContourStandIn` and marks-only init, kept for callers
// still on them (FlareApp's stage) until they move to the kernel types and `onIntent`; then delete this file.
import SuiteKernel
import SwiftUI

/// One contour as PN-2 took it: its anchors in order, in document pixels, and whether the last joins the first.
public struct PathContourStandIn: Equatable, Sendable {
    public let anchors: [PathAnchor]
    public let closed: Bool

    public init(anchors: [PathAnchor], closed: Bool) {
        self.anchors = anchors
        self.closed = closed
    }

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
    /// PN-2's overlay: `draft` and `path` as marks, no selection, no gesture.
    public init(draft: PathContourStandIn?, path: [PathContourStandIn], tool: PenTool, zoom: Double) {
        self.init(draft: draft.map { PenDraft(contour: $0.contour, scale: PathMarks.scale(zoom)) },
                  path: path.isEmpty ? nil
                      : PathInEdit(id: "stand-in", path: VectorPath(contours: path.map(\.contour)), toDocument: .identity),
                  selection: Selection(), tool: tool, zoom: zoom) { _ in }
        interactive = false
    }
}
