// DesignSelectionMarks.swift: the selection over the canvas, in the overlay (not
// clipped to the page, so marks past its edge still show). One layer: an accent
// outline and, unless a lock stops it, its resize handles where DesignRect.handles
// puts them (a small selection shows only its corners, outside the box) and the rotate knob on its
// stem above the top, SuiteUI's `SelectionHandles` marks (transform DT-u). Several
// layers: the same accent outline on each and a solid accent box around them all,
// with the box's handles, but no knob, while the Model's `showsSelectionHandles` holds; a lock or
// hidden layer in the selection leaves none. While a marquee is live only each hit
// layer's outline draws: no box, no handles until the drag ends. Dashes are the live marquee's alone
// (DesignMarqueeMark), so a committed selection never reads as one in progress.
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
            ForEach(painted.map(\.node).filter { ids.contains($0.id) }) { node in
                DesignSelectionBox(rect: node.frame, zoom: zoom, handles: false, degrees: node.rotation)
            }
            if let bounds = model.selectionBounds {
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
        let turn = TransformBox(box: Rect(minX: rect.x, minY: rect.y, maxX: rect.maxX, maxY: rect.maxY), degrees: degrees)
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
}
