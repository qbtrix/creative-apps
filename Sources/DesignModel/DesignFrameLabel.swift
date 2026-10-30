// DesignFrameLabel.swift: which frames the canvas names and where a name sits
// (#1387, #266). Only visible top-level frames show a name; a nested frame shows
// none. The names are drawn in the canvas overlay, which isn't clipped to the
// page, so a name always sits just above its frame's top-left corner, even for a
// frame at the page's top edge. Plain numbers in one space (the view passes view
// points: the frame's top after the zoom), so the name stays one size at any zoom.
// The view gets `labels`: plain id, name and frame values, so a drag that moves
// none of them leaves the overlay's inputs equal and it does no work (#4085).
// Linux-safe: no UI imports.

/// The frames the canvas names, and where a name's bottom edge goes.
public enum DesignFrameLabel {
    /// The frames that show a name: visible top-level frames, back to front.
    public static func labelled(on page: DesignPage) -> [DesignNode] {
        page.nodes.filter { $0.kind == .frame && !$0.isHidden }
    }

    /// One frame's name and box, all the overlay draws.
    public struct Label: Sendable, Equatable, Identifiable {
        public let id: String
        public let name: String
        public let frame: DesignRect
    }

    /// `labelled(on:)` as plain values, back to front.
    public static func labels(on page: DesignPage) -> [Label] {
        labelled(on: page).map { Label(id: $0.id, name: $0.name, frame: $0.frame) }
    }

    /// A name `labelHeight` tall sits with its bottom edge `gap` above the frame's top, at any zoom.
    public static func bottom(frameTop: Double, gap: Double) -> Double {
        frameTop - gap
    }
}
