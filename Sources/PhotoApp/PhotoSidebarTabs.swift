// PhotoSidebarTabs.swift: Photo's sidebar, SuiteUI's SegmentedTabs over two
// tabs: Layers (PhotoLayerList) and AI (SuiteUI AgentActivityList over the
// workspace's `agentRequests`, #6029). The picked tab is this view's own
// state and the AI tab reads the PhotoSession's `document` facet itself, so
// switching tabs or opening a request row runs no window body and no canvas
// render. Values in, intents out: AI gestures leave as `.agent(...)`.
import PhotoModel
import SuiteUI
import SwiftUI

enum PhotoSidebarTab: Hashable, Sendable {
    case layers, ai
}

struct PhotoSidebarTabs: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    @State var tab: PhotoSidebarTab

    init(model: PhotoWorkspace, perform: @escaping PhotoPerform, tab: PhotoSidebarTab = .layers) {
        (self.model, self.perform) = (model, perform)
        _tab = State(initialValue: tab)
    }

    static let tabs = [
        InspectorOption(id: PhotoSidebarTab.layers, title: "Layers"),
        InspectorOption(id: PhotoSidebarTab.ai, title: "AI"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedTabs("Sidebar", tabs: Self.tabs, selection: tab, id: "photo.sidebar.tabs", onChange: { tab = $0 })
                .padding(.horizontal, SuiteSpacing.s)
                .padding(.vertical, SuiteSpacing.xs)
            switch tab {
            case .layers: PhotoLayerList(model: model, perform: perform)
            case .ai: PhotoAgentTab(model: model, perform: perform)
            }
        }
    }
}

/// The AI tab: the agent's requests with their layers' names and visibility.
struct PhotoAgentTab: View {
    private let given: PhotoWorkspace
    let perform: PhotoPerform
    @Environment(PhotoSession.self) private var session: PhotoSession?

    init(model: PhotoWorkspace, perform: @escaping PhotoPerform) {
        (given, self.perform) = (model, perform)
    }

    private var model: PhotoWorkspace { session?.workspace(reading: .document) ?? given }

    var body: some View {
        let model = self.model
        AgentActivityList(
            requests: model.agentRequests,
            layerNames: Dictionary(model.layers.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a }),
            hidden: Set(model.layers.filter { !$0.isVisible }.map(\.id))
        ) { perform(.agent($0)) }
    }
}
