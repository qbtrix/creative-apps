// PhotoPanel.swift: the inspector of a Photo window: the image header, then
// an Adjust | History tab switch (`photo.inspector.tabs`). Adjust is
// PhotoAdjustTab in one scroll view (the active tool's options, the selected
// layer's blend mode and opacity from PhotoLayerSettings, then the adjustment
// sections); History is PhotoHistoryTab. The window keeps which tab shows
// (`photoInspectorTab`, PhotoWindow+History.swift) and Window > History picks
// History. The layer list lives in the window's sidebar (PhotoLayerList). With
// no image open it says how to start. Values in, intents out. Every control
// carries a `photo.tool.*` or `photo.layer.*` accessibility identifier for the
// UI journeys and the app audit. In a window it reads the PhotoSession's
// `tool`, `toolOptions`, `adjust` and `history` facets, so an option step
// re-runs it alone; its layer rows and header follow the window's own pass
// (the window re-creates it on every other facet). Without a session (the
// snapshots) it shows the workspace it was given. Debug builds report its body
// runs to the window's BodyTally.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoPanel: View {
    private let given: PhotoWorkspace
    var perform: PhotoPerform = { _ in }
    @Environment(\.photoInspectorTab) private var tab
    @Environment(PhotoSession.self) private var session: PhotoSession?
    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    init(model: PhotoWorkspace, perform: @escaping PhotoPerform = { _ in }) {
        (given, self.perform) = (model, perform)
    }

    /// The window's workspace now, read through the facets this panel shows; the given one outside a window.
    private var model: PhotoWorkspace { session?.workspace(reading: .tool, .toolOptions, .adjust, .history) ?? given }

    /// The inspector's tabs.
    static let tabs = [
        InspectorOption(id: PhotoInspectorTab.adjust, title: "Adjust"),
        InspectorOption(id: PhotoInspectorTab.history, title: "History"),
    ]

    var body: some View {
        #if DEBUG
        let _ = bodyTally?.ran(Self.self)
        #endif
        let model = self.model
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
