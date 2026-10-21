// FlareShapeOptions.swift (shape-tools FS-2): the inspector's SHAPE section while the Shape tool is active,
// SuiteUI's ShapeToolOptions over the Model's `shapeTool`: the kind chips (suite.shape.chip-<kind>) and the kind's
// rows. It only reads the spec; each change goes out through `onIntent`, which the window turns into the Model's
// `pickShapeTool` (`FlareWindow.shapeOptions` below). `help` is ShapeRules' reason the spec can't be drawn.
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct FlareShapeOptions: View {
    let spec: ShapeSpec
    let help: String?
    let onIntent: @MainActor (ShapeIntent) -> Void

    var body: some View {
        InspectorSection("Shape") {
            ShapeToolOptions(spec: spec, help: help) { onIntent($0) }
        }
    }
}

extension FlareWindow {
    /// The Shape tool's options while it's the active tool, else nil; each change picks the Model's next spec.
    var shapeOptions: FlareShapeOptions? {
        guard model.tool == .shape else { return nil }
        return FlareShapeOptions(spec: model.shapeTool, help: ShapeRules.help(model.shapeTool)) { intent in
            model.pickShapeTool(intent.applied(to: model.shapeTool))
        }
    }
}
