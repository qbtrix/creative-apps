// PhotoPanel.swift: the right panel of a Photo window. Segmented tabs switch
// between Adjust (the image header, then PhotoAdjustTab: the active tool's
// options and the adjustment sections) and Layers (the image header, then
// PhotoLayersPanel, in PhotoLayersTab.swift: the layer list and the selected
// layer's settings). PhotoHistoryTab is not shown yet. With no
// image open it says how to start. Values in, intents out. Every control in
// the tabs carries a `photo.tool.*` or `photo.layer.*` accessibility
// identifier for the UI journeys and the app audit.
import PhotoModel
import SuiteUI
import SwiftUI

enum PhotoPanelTab: Hashable, Sendable {
    case adjust, layers
}

struct PhotoPanel: View {
    let model: PhotoWorkspace
    let tab: PhotoPanelTab
    var onTab: @MainActor (PhotoPanelTab) -> Void = { _ in }
    var perform: PhotoPerform = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedTabs(
                "Panel", tabs: [InspectorOption(id: .adjust, title: "Adjust"), InspectorOption(id: .layers, title: "Layers")],
                selection: tab, onChange: onTab)
            if model.canvas != nil {
                InspectorHeader(model.inspectorHeaderTitle, details: model.inspectorHeaderDetails)
                if tab == .adjust {
                    PhotoAdjustTab(model: model, perform: perform)
                } else {
                    PhotoLayersPanel(model: model, perform: perform)
                }
            } else {
                EmptyStateView(
                    PhotoInspectorContent.noImageTitle, systemImage: PhotoInspectorContent.noImageSymbol,
                    message: PhotoInspectorContent.noImageMessage)
            }
        }
    }
}
