// PhotoPanel.swift: the inspector of a Photo window, with no tabs: the image
// header, the selected layer's blend mode and opacity (PhotoLayerSettings),
// then PhotoAdjustTab (the active tool's options and the adjustment sections,
// in one scroll view). The layer list lives in the window's sidebar
// (PhotoLayerList), and PhotoHistoryTab is not shown yet. With no image open
// it says how to start. Values in, intents out. Every control carries a
// `photo.tool.*` or `photo.layer.*` accessibility identifier for the UI
// journeys and the app audit.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoPanel: View {
    let model: PhotoWorkspace
    var perform: PhotoPerform = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.canvas != nil {
                InspectorHeader(model.inspectorHeaderTitle, details: model.inspectorHeaderDetails)
                PhotoLayerSettings(model: model, perform: perform)
                PhotoAdjustTab(model: model, perform: perform)
            } else {
                EmptyStateView(
                    PhotoInspectorContent.noImageTitle, systemImage: PhotoInspectorContent.noImageSymbol,
                    message: PhotoInspectorContent.noImageMessage)
            }
        }
    }
}
