// PhotoSidebarTabs.swift: Photo's sidebar, SuiteUI's AgentSidebarTabs over
// Layers (PhotoLayerList) and AI (SuiteUI AgentActivityList over the
// workspace's `agentRequests`, #6029). The AI tab reads the PhotoSession's
// `document` facet itself, so switching tabs or opening a request row runs
// no window body and no canvas render. Values in, intents out: AI gestures
// leave as `.agent(...)`.
import PhotoModel
import SuiteUI
import SwiftUI

struct PhotoSidebarTabs: View {
    let model: PhotoWorkspace
    let perform: PhotoPerform
    var tab: AgentSidebarTab = .primary

    var body: some View {
        AgentSidebarTabs("Layers", id: "photo.sidebar.tabs", tab: tab) {
            PhotoLayerList(model: model, perform: perform)
        } ai: {
            PhotoAgentTab(model: model, perform: perform)
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
