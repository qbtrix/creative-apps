// HaloShapeTool.swift (shape-tools HS-2): the Shape button by the viewer and
// its options popover. The button is a floating ToolbarGroup item
// (`halo.viewer.shape`) disabled with HaloProject's `shapeHelp` as its
// tooltip while the tool can't draw; it opens HaloShapeOptions, SuiteUI's
// ShapeToolOptions on the Model's `shapeTool` with `shapeHelp` under its
// rows. Each option goes to `onIntent`. The view only reads the Model; the
// popover's open state is presentation state.
import HaloModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct HaloShapeTool: View {
    let model: HaloProject
    var onIntent: @MainActor (ShapeIntent) -> Void = { _ in }
    /// Whether the options popover is open. Presentation state only.
    @State private var showsOptions = false

    /// The button, off with the Model's reason while it can't draw.
    nonisolated static func action(_ model: HaloProject, perform: @escaping @MainActor () -> Void) -> ToolbarAction {
        ToolbarAction(
            "Shape", systemImage: "star", unavailableHelp: model.shapeHelp, identifier: "halo.viewer.shape",
            perform: perform)
    }

    var body: some View {
        ToolbarGroup([Self.action(model) { showsOptions = true }])
            .popover(isPresented: $showsOptions, arrowEdge: .bottom) {
                HaloShapeOptions(model: model, onIntent: onIntent)
            }
    }
}

/// The Shape popover's content, on its own so a snapshot can show it.
struct HaloShapeOptions: View {
    let model: HaloProject
    var onIntent: @MainActor (ShapeIntent) -> Void = { _ in }

    var body: some View {
        ShapeToolOptions(spec: model.shapeTool, help: model.shapeHelp, onIntent: onIntent)
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.editorPanelWidth)
    }
}
