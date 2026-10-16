// PhotoLayerSettings.swift: the selected layer's settings in Photo's panel:
// one InspectorSection, "Layer", with its blend mode (`photo.layer.blend`)
// and opacity (`photo.layer.opacity`). Shows nothing when no layer is
// selected. Values in, intents out.
import CoreRaster
import PhotoModel
import SuiteUI
import SwiftUI

/// The selected layer's blend mode and opacity.
struct PhotoLayerSettings: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        if let layer = model.selectedLayer {
            InspectorSection("Layer") {
                InspectorPickerRow(
                    "Blend Mode", options: CoreRaster.BlendMode.allCases.map { InspectorOption(id: $0, title: $0.title) },
                    selection: layer.blendMode) { perform(.blendMode(layer.id, $0)) }
                .accessibilityIdentifier("photo.layer.blend")
                InspectorSliderRow("Opacity", value: layer.opacityPercent, in: 0...100, unit: "%", decimals: 0) {
                    perform(.opacity(layer.id, $0))
                } onEnd: {
                    perform(.endAdjust)
                }
                .accessibilityIdentifier("photo.layer.opacity")
            }
        }
    }
}
