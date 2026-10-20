// PhotoPanel.swift: the inspector of a Photo window: the image header, then
// an Adjust | History tab switch (`photo.inspector.tabs`). Adjust is
// PhotoAdjustTab in one scroll view (the active tool's options, the selected
// layer's blend mode and opacity from PhotoLayerSettings, then the adjustment
// sections); History is PhotoHistoryTab. The window keeps which tab shows
// (`photoInspectorTab`, PhotoWindow+History.swift) and Window > History picks
// History. The layer list lives in the window's sidebar (PhotoLayerList). With
// no image open it says how to start. Values in, intents out. Every control
// carries a `photo.tool.*` or `photo.layer.*` accessibility identifier for the
// UI journeys and the app audit.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoPanel: View {
    let model: PhotoWorkspace
    var perform: PhotoPerform = { _ in }
    @Environment(\.photoInspectorTab) private var tab

    /// The inspector's tabs.
    static let tabs = [
        InspectorOption(id: PhotoInspectorTab.adjust, title: "Adjust"),
        InspectorOption(id: PhotoInspectorTab.history, title: "History"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if model.canvas != nil {
                InspectorHeader(model.inspectorHeaderTitle, details: model.inspectorHeaderDetails)
                SegmentedTabs("Inspector", tabs: Self.tabs, selection: tab, id: "photo.inspector.tabs",
                              onChange: { perform(.history(.showTab($0))) })
                switch tab {
                case .adjust: PhotoAdjustTab(model: model, perform: perform, showsLayerSettings: true)
                case .history: PhotoHistoryTab(model: model, perform: perform)
                }
            } else {
                EmptyStateView(
                    PhotoInspectorContent.noImageTitle, systemImage: PhotoInspectorContent.noImageSymbol,
                    message: PhotoInspectorContent.noImageMessage)
            }
        }
    }
}
