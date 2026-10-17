// DesignCanvasFeedback.swift: the canvas's tool feedback, a slot that canvas
// tool feedback (design-window DW-d) fills: the pointer CanvasViewport shows, the
// handler for where the pointer is over the artboard, and the marks drawn on top
// of the overlay (the hover outline and the size badge, later). Empty for now: the
// pointer is the active tool's own, nothing listens to the pointer, and nothing is
// drawn. It reads the model and never writes it.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignCanvasFeedback: View {
    let model: DesignWorkspace
    let zoom: Double

    /// The pointer over the canvas: the active tool's own.
    var pointer: PointerStyle { model.tool.pointer }

    /// Called with the pointer's place on the artboard, nil when it leaves; nil while nothing listens.
    var onPointer: (@MainActor (CGPoint?) -> Void)? { nil }

    var body: some View {
        EmptyView()
    }
}
