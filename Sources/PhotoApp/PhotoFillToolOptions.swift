// PhotoFillToolOptions.swift: the Gradient tool's own options in the
// inspector, under its one-line hint (ToolOptionsSection; gradient-fill
// PG-2). SuiteUI's GradientEditor on the tool's kernel `Fill`
// (`ToolOptions.gradient`, whose points are a unit box's), limited to linear
// and radial and with no angle row, since the drag sets the line. Each
// gesture is one `GradientIntent`, sent as `.gradientOption` to
// `PhotoWorkspace.runGradientOption`. Values in, intents out.
import PhotoModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct PhotoFillToolOptions: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    /// The fill types the editor offers: a gradient tool never paints a solid.
    static let types: [FillType] = [.linear, .radial]
    /// No angle row: the drag from press to release sets the line.
    static let showsAngle = false
    /// The space `ToolOptions.gradient`'s points are in.
    static let box = Rect(minX: 0, minY: 0, maxX: 1, maxY: 1)

    var body: some View {
        GradientEditor(
            fill: model.toolOptions.gradient, box: Self.box, showsAngle: Self.showsAngle, types: Self.types
        ) { perform(.gradientOption($0)) }
    }
}
