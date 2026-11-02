// DesignSidebarTabs.swift: Design's sidebar, SuiteUI's AgentSidebarTabs over
// Layers (DesignLayersPanel, the pages and layer tree) and AI (SuiteUI
// AgentActivityList over the workspace's `agentRequests`). Switching tabs or
// opening a request row runs no editor body and no canvas render; the
// workspace's `agentWork` drives the working mark and the live request row. Values in,
// intents out: AI gestures leave as `.agent(...)`.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignSidebarTabs: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    var tab: AgentSidebarTab = .primary

    var body: some View {
        AgentSidebarTabs("Layers", id: DesignControlID.sidebarTabs, tab: tab, work: { model.agentWork }) {
            DesignLayersPanel(model: model, perform: perform)
        } ai: {
            AgentActivityList(requests: model.agentRequests, layerNames: model.layerNamesByID,
                              hidden: model.hiddenNodeIDs, work: model.agentWork) { perform(.agent($0)) }
        }
    }
}
