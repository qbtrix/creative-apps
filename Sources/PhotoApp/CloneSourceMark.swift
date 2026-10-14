// CloneSourceMark.swift: where the Clone tool copies from, drawn over the
// canvas in a CanvasViewport's overlay: a ring with a cross through its
// center at the sampled point, a black line under a white one like
// SelectionOutline, so it reads on any pixels. It keeps its size at every
// zoom and never takes a click; the canvas gesture does.
import SuiteUI
import SwiftUI

struct CloneSourceMark: View {
    /// The source in document pixels; `zoom` in points per pixel.
    let x: Double
    let y: Double
    let zoom: Double

    var body: some View {
        let center = CGPoint(x: x * zoom, y: y * zoom), radius = SuiteSpacing.s
        let mark = Path { path in
            path.addEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
            path.move(to: CGPoint(x: center.x - radius * 1.5, y: center.y))
            path.addLine(to: CGPoint(x: center.x + radius * 1.5, y: center.y))
            path.move(to: CGPoint(x: center.x, y: center.y - radius * 1.5))
            path.addLine(to: CGPoint(x: center.x, y: center.y + radius * 1.5))
        }
        ZStack {
            mark.stroke(SuiteColor.overlayInk, lineWidth: 3)
            mark.stroke(SuiteColor.overlayPaper, lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityElement()
        .accessibilityLabel("Clone source")
        .accessibilityIdentifier("photo.clone.source")
    }
}
