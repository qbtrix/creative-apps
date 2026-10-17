// DesignSelectionMarks.swift: the selection over the canvas, in the overlay (not
// clipped to the page, so marks past its edge still show). One layer: an accent
// outline and, unless a lock stops it, its resize handles where DesignRect.handles
// puts them (a small selection shows only its corners, outside the box). Several
// layers: the same accent outline on each and a solid accent box around them all,
// with the box's handles while the Model's `showsSelectionHandles` holds; a lock or
// hidden layer in the selection leaves none. While a marquee is live only each hit
// layer's outline draws: no box, no handles until the drag ends. Dashes are the live marquee's alone
// (DesignMarqueeMark), so a committed selection never reads as one in progress.
// The text node being edited shows its editor's box instead. The box carries the
// one accessibility element, `design.canvas.selection` ("Selection"): a clear
// rectangle at the box's frame, an image, never a control. Takes no clicks; the
// canvas gesture does, with the same handles these marks draw.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignSelectionMarks: View {
    let model: DesignWorkspace
    let painted: [DesignPainted]
    let zoom: Double

    var body: some View {
        // A hidden node, or one inside a hidden frame, is not on the canvas, so it has no outline.
        if model.hasMultipleSelection {
            let ids = Set(model.selectedNodeIDs)
            ForEach(painted.map(\.node).filter { ids.contains($0.id) }) { node in
                DesignSelectionBox(rect: node.frame, zoom: zoom, handles: false)
            }
            if let bounds = model.selectionBounds {
                // A live marquee shows what it will select, not the box it will commit.
                if model.marquee == nil {
                    DesignSelectionBox(rect: bounds, zoom: zoom, handles: model.showsSelectionHandles)
                }
                DesignSelectionElement(rect: bounds, zoom: zoom)
            }
        } else if let selected = painted.first(where: { $0.node.id == model.selectedNodeID })?.node,
                  selected.id != model.editingTextID {
            DesignSelectionBox(rect: selected.frame, zoom: zoom, handles: model.showsSelectionHandles)
            DesignSelectionElement(rect: selected.frame, zoom: zoom)
        }
    }
}

/// One selected layer, or the box around several: an accent outline around `rect`, and with
/// `handles` its resize handles, white squares with an
/// accent edge. Shapes, not a Canvas, so marks past the page's edge still draw: CanvasViewport
/// doesn't clip its overlay. Frames and handles stay one size at any zoom.
struct DesignSelectionBox: View {
    let rect: DesignRect
    let zoom: Double
    var handles = true

    var body: some View {
        let scale = usable(zoom)
        let side = SuiteSpacing.s
        let box = rect.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale))
        let centers = handles ? Array(rect.handles(size: Double(side) / scale).values) : []
        let squares = Path { path in
            for at in centers {
                path.addRect(CGRect(x: at.x * scale - side / 2, y: at.y * scale - side / 2, width: side, height: side))
            }
        }
        ZStack(alignment: .topLeading) {
            Path(box).stroke(SuiteColor.accent, lineWidth: 1)
            squares.fill(SuiteColor.overlayPaper)
            squares.stroke(SuiteColor.accent, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The selection's accessibility element: a clear rectangle at `rect` (page points) at `zoom`,
/// identified `design.canvas.selection` and labelled "Selection". It paints nothing.
private struct DesignSelectionElement: View {
    let rect: DesignRect
    let zoom: Double

    var body: some View {
        let scale = usable(zoom)
        let box = rect.cgRect.applying(CGAffineTransform(scaleX: scale, y: scale)).standardized
        Color.clear
            .frame(width: box.width, height: box.height)
            .accessibilityElement()
            .accessibilityLabel(Text(verbatim: "Selection"))
            .accessibilityIdentifier("design.canvas.selection")
            .accessibilityAddTraits(.isImage)
            .padding(.leading, box.minX)
            .padding(.top, box.minY)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .allowsHitTesting(false)
    }
}
