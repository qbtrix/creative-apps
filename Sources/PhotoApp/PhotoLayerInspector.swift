// PhotoLayerInspector.swift: the inspector for the selected layer: its name
// and the canvas size, then a Layer section with the blend mode picker
// (every CoreRaster BlendMode, named in full since SwiftUI has its own) and
// the opacity slider in percent. Values in, closures out; PhotoWorkspace
// clamps the opacity.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoLayerInspector: View {
    let layer: PhotoLayer
    let canvasSize: String
    var onBlendMode: @MainActor (CoreRaster.BlendMode) -> Void = { _ in }
    var onOpacity: @MainActor (Double) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: SuiteSpacing.m) {
            SurfaceCard(title: layer.name, detail: canvasSize)
            InspectorSection("Layer") {
                InspectorPickerRow(
                    "Blend Mode", options: CoreRaster.BlendMode.allCases.map { InspectorOption(id: $0, title: $0.title) },
                    selection: layer.blendMode, onChange: onBlendMode)
                InspectorSliderRow("Opacity", value: layer.opacityPercent, in: 0...100, unit: "%", onChange: onOpacity)
            }
        }
    }
}
