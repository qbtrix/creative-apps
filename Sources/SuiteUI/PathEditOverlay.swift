// PathEditOverlay.swift (pen-paths PN-2): the Pen and point editor's overlay
// over a canvas. This placeholder draws the path only: the edited contours'
// and the open pen draft's outline through `PathMarks.outline`, in black and
// white so it reads on any pixels; no anchors, handles or gesture, hidden
// from accessibility. PN-3 makes it the real overlay (rubber band, anchor and
// handle marks with hover and selected states, the close ring, the gesture
// emitting intents) on the kernel's `PenDraft` and `PathInEdit` from PN-1,
// which replace `PathContourStandIn` below.
import SwiftUI

/// One contour as the PN-2 placeholder takes it: its anchors in order and
/// whether the last joins the first. A SuiteUI-local stand-in for the kernel's
/// contour (FlareCore's `PathContour`: anchors and `closed`) until PN-1's path
/// types land; PN-3 swaps those in and deletes this.
public struct PathContourStandIn: Equatable, Sendable {
    public let anchors: [PathAnchor]
    public let closed: Bool

    public init(anchors: [PathAnchor], closed: Bool) {
        self.anchors = anchors
        self.closed = closed
    }
}

/// The path tool the overlay serves: the Pen adds anchors, Direct Selection picks and drags them.
public enum PenTool: String, CaseIterable, Sendable {
    case pen
    case directSelect

    public var title: String {
        switch self {
        case .pen: "Pen"
        case .directSelect: "Direct Selection"
        }
    }
}

/// The path being edited and the open pen draft, drawn over the canvas.
public struct PathEditOverlay: View {
    private let draft: PathContourStandIn?
    private let path: [PathContourStandIn]
    private let tool: PenTool
    private let zoom: Double

    /// `draft` is the open pen path and `path` the contours being edited, both
    /// in document pixels; `zoom` in points per pixel. `tool` picks the
    /// gestures once PN-3 adds them.
    public init(draft: PathContourStandIn?, path: [PathContourStandIn], tool: PenTool, zoom: Double) {
        self.draft = draft
        self.path = path
        self.tool = tool
        self.zoom = zoom
    }

    public var body: some View {
        let parts = PathMarks.parts(path + [draft].compactMap { $0 })
        let outline = PathMarks.outline(anchors: parts.anchors, segments: parts.segments, zoom: zoom)
        ZStack {
            outline.stroke(SuiteColor.overlayInk, lineWidth: 2)
            outline.stroke(SuiteColor.overlayPaper, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
