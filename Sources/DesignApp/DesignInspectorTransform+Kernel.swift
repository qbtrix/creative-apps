// DesignInspectorTransform+Kernel.swift (transform DT-2): the inspector's Transform section under Frame,
// an adapter from the workspace onto SuiteKernel's TransformIntent with no Design maths (rule 20).
// Rotation is a bar in degrees, clockwise about the layer's centre ("Mixed" when the selected layers
// differ), and Flip Horizontal and Flip Vertical mirror the selection in place. Each sends a kernel
// TransformIntent (`.transform`, run by `runTransform`); a Rotation scrub is one step under one drag
// token, ended by `.endEditRun`. On DT-1's stubs every control is off with `turnHelp` as its reason.
// X, Y, W and H stay the Frame section's live scrub fields, so SuiteUI's TransformRows, which carries
// its own X, Y, W and H, isn't used here yet. Values in, intents out.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

/// Rotation and the two flips over the selection; off with the Model's reason.
struct DesignInspectorTransform: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    var body: some View {
        let help = model.turnHelp
        let rotation = model.sharedValue(\.rotation)
        InspectorSection("Transform") {
            InspectorSliderRow(
                "Rotation", value: rotation ?? 0, in: -180...180, step: 1, unit: "°", decimals: 0, mixed: rotation == nil,
                onChange: { turn(to: $0) }, onEnd: { perform(.endEditRun) }
            )
            .disabled(help != nil)
            .help(help ?? "")
            .suiteControl(id: DesignControlID.inspectorRotation, enabled: help == nil, reason: help)
            HStack(spacing: SuiteSpacing.xs) {
                ForEach(FlipDirection.allCases, id: \.self) { direction in
                    InspectorAction(ToolbarAction(
                        direction.title, systemImage: direction.systemImage, unavailableHelp: help,
                        identifier: DesignControlID.inspectorFlip(direction.rawValue)
                    ) { perform(.transform(.flip(direction))) }, iconOnly: true)
                }
            }
        }
    }

    /// One value of a Rotation scrub: the selection's box at `degrees`, under the scrub's drag token.
    private func turn(to degrees: Double) {
        guard var box = model.transformSelection else { return }
        box.degrees = degrees
        perform(.transform(.set(box, drag: DesignControlID.inspectorRotation)))
    }
}
