// DesignSelectionMarks.swift: the selection over the canvas, in the overlay (not
// clipped to the page, so marks past its edge still show). One layer: an accent
// outline and, unless a lock stops it, its resize handles where DesignRect.handles
// puts them (a small selection shows only its corners, outside the box) and the rotate knob on its
// stem above the top, SuiteUI's `SelectionHandles` marks (transform DT-u). Several
// layers: the same accent outline on each, all in one stroked path, and a solid accent box around them all,
// with the box's handles, but no knob, while the Model's `showsSelectionHandles` holds; a lock or
// hidden layer in the selection leaves none. While a marquee is live only each hit
// layer's outline draws: no box, no handles until the drag ends. Dashes are the live marquee's alone
// (SuiteUI's SelectBoxMark), so a committed selection never reads as one in progress.
// A turned layer's outline and handles turn with it. The text node being edited shows its editor's box instead. The box carries the
// one accessibility element, `design.canvas.selection` ("Selection"): a clear
// rectangle at the box's frame, an image, never a control. Takes no clicks; the
// canvas gesture does, with the same handles these marks draw.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignSelectionMarks: View {
    /// The selection's probe (SuiteUI's ProbeElement): a clear box labelled "Selection", painting nothing.
    static let selectionID = "design.canvas.selection"
    let model: DesignWorkspace
    let painted: [DesignPainted]
    let zoom: Double

    var body: some View {
        // A hidden node, or one inside a hidden frame, is not on the canvas, so it has no outline.
        if model.hasMultipleSelection {
            let ids = Set(model.selectedNodeIDs)
            // Painted skips hidden subtrees as selectionBounds does, so the hits' union is that box, without a second walk.
            let hits = Array(painted.lazy.filter { ids.contains($0.node.id) }.map(\.node))
            // Every hit's outline in one stroked path, not a view each: a marquee that grows by a
            // hundred layers changes one shape instead of inserting a hundred views (render contract rule 3).
            DesignSelectionBox.outlines(hits, zoom: zoom)
            if let bounds = DesignRect.union(hits.map(\.frame)) {
                // A live marquee shows what it will select, not the box it will commit.
                if model.marquee == nil {
                    DesignSelectionBox(rect: bounds, zoom: zoom, handles: model.showsSelectionHandles, knob: true)
                }
                ProbeElement(Self.selectionID, label: "Selection", rect: bounds.cgRect, zoom: usable(zoom), traits: .isImage)
            }
        } else if let selected = painted.first(where: { $0.node.id == model.selectedNodeID })?.node,
                  selected.id != model.editingTextID {
            DesignSelectionBox(
                rect: selected.frame, zoom: zoom, handles: model.showsSelectionHandles, degrees: selected.rotation, knob: true)
            ProbeElement(
                Self.selectionID, label: "Selection", rect: selected.frame.cgRect, zoom: usable(zoom), traits: .isImage)
        }
    }
}

/// One selected layer, or the box around several: an accent outline around `rect`, and with
/// `handles` its resize handles, white squares with an
/// accent edge, and with `knob` too the rotate knob, a white circle on an accent stem from the top
/// handle (SuiteUI's `SelectionHandles.marks` and `stem`), all turned `degrees` about the box's centre the way the artwork turns. Shapes, not a Canvas, so marks past the page's edge still draw: CanvasViewport
/// doesn't clip its overlay. Frames and handles stay one size at any zoom; `lineWidth` widens the outline
/// (DesignAgentGlow's 2 pt).
struct DesignSelectionBox: View {
    let rect: DesignRect
    let zoom: Double
    var handles = true
    var degrees: Double = 0
    var knob = false
    var lineWidth: CGFloat = 1

    var body: some View {
        let scale = usable(zoom)
        let side = SuiteSpacing.s
        let box = rect.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale))
        let shown = handles ? rect.handles(size: Double(side) / scale) : [:]
        let centers = shown.filter { $0.key != .rotate }.values
        // The knob and the top handle as SuiteUI's marks, each a point rect at its centre.
        let spots: [EditorHandle: Rect] = knob
            ? [.rotate: shown[.rotate], .top: shown[.top]].compactMapValues { $0.map { Rect(minX: $0.x, minY: $0.y, maxX: $0.x, maxY: $0.y) } }
            : [:]
        let marks = SelectionHandles.marks(handles: spots, zoom: scale)
        let knobMark = marks.first { $0.handle == .rotate }
        let squares = Path { path in
            for at in centers {
                path.addRect(CGRect(x: at.x * scale - side / 2, y: at.y * scale - side / 2, width: side, height: side))
            }
        }
        let turn = Self.turn(rect, degrees: degrees)
        ZStack(alignment: .topLeading) {
            Path(box).stroke(SuiteColor.accent, lineWidth: lineWidth)
            squares.fill(SuiteColor.overlayPaper)
            squares.stroke(SuiteColor.accent, lineWidth: 1)
            if let knobMark {
                SelectionHandles.stem(marks).stroke(SuiteColor.accent, lineWidth: 1)
                Circle().fill(SuiteColor.overlayPaper)
                    .overlay { Circle().stroke(SuiteColor.accent, lineWidth: 1) }
                    .frame(width: knobMark.frame.width, height: knobMark.frame.height)
                    .position(x: knobMark.frame.midX, y: knobMark.frame.midY)
            }
        }
        .transformEffect(artworkPlacement(turn, scale: scale))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    nonisolated static func turn(_ rect: DesignRect, degrees: Double) -> TransformBox {
        TransformBox(box: Rect(minX: rect.x, minY: rect.y, maxX: rect.maxX, maxY: rect.maxY), degrees: degrees)
    }

    /// Each node's accent outline as the box draws it alone, all stroked as one shape.
    @MainActor static func outlines(_ nodes: [DesignNode], zoom: Double) -> some View {
        outlinePath(nodes, zoom: zoom).stroke(SuiteColor.accent, lineWidth: 1)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Each node's outline, scaled by `zoom` and turned with the node, in one path.
    nonisolated static func outlinePath(_ nodes: [DesignNode], zoom: Double) -> Path {
        let scale = usable(zoom)
        return Path { path in
            for node in nodes {
                let box = node.frame.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale))
                path.addRect(box, transform: artworkPlacement(turn(node.frame, degrees: node.rotation), scale: scale))
            }
        }
    }
}
