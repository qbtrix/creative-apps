// PhotoPanel.swift: the inspector of a Photo window, with no tabs: the image
// header, then PhotoAdjustTab in one scroll view (the active tool's options,
// the selected layer's blend mode and opacity from PhotoLayerSettings, then
// the adjustment sections). The layer list lives in the window's sidebar
// (PhotoLayerList), and PhotoHistoryTab is not shown yet. With no image open
// it says how to start. Values in, intents out. Every control carries a
// `photo.tool.*` or `photo.layer.*` accessibility identifier for the UI
// journeys and the app audit. `scrollAnchor` passes through to
// PhotoAdjustTab's scroll view (nil: the top).
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoPanel: View {
    let model: PhotoWorkspace
    var perform: PhotoPerform = { _ in }
    var scrollAnchor: UnitPoint?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.canvas != nil {
                InspectorHeader(model.inspectorHeaderTitle, details: model.inspectorHeaderDetails)
                PhotoAdjustTab(model: model, perform: perform, showsLayerSettings: true, scrollAnchor: scrollAnchor)
            } else {
                EmptyStateView(
                    PhotoInspectorContent.noImageTitle, systemImage: PhotoInspectorContent.noImageSymbol,
                    message: PhotoInspectorContent.noImageMessage)
            }
        }
    }
}
