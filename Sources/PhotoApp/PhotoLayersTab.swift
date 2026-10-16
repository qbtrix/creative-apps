// PhotoLayersTab.swift: the Layers tab of a Photo window's right panel: the
// layer list with its command row (PhotoLayerList), then the selected
// layer's blend mode and opacity (PhotoLayerSettings). Values in, intents out.
import PhotoModel
import SwiftUI

/// The Layers tab: the stack, top first, then the selected layer's settings.
struct PhotoLayersPanel: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            PhotoLayerList(model: model, perform: perform)
            PhotoLayerSettings(model: model, perform: perform)
        }
    }
}
