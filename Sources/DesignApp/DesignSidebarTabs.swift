// DesignSidebarTabs.swift: Design's sidebar, SuiteUI's SegmentedTabs over two
// tabs, as Photo's is: Layers (DesignLayersPanel, the pages and layer tree)
// and AI (SuiteUI AgentActivityList over the workspace's `agentRequests`).
// The picked tab is this view's own state, so switching tabs or opening a
// request row runs no editor body and no canvas render. Values in, intents
// out: AI gestures leave as `.agent(...)`.
import DesignModel
import SuiteUI
import SwiftUI

enum DesignSidebarTab: Hashable, Sendable {
    case layers, ai
}

struct DesignSidebarTabs: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    @State var tab: DesignSidebarTab

    init(model: DesignWorkspace, perform: @escaping DesignPerform, tab: DesignSidebarTab = .layers) {
        (self.model, self.perform) = (model, perform)
        _tab = State(initialValue: tab)
    }

    static let tabs = [
        InspectorOption(id: DesignSidebarTab.layers, title: "Layers"),
        InspectorOption(id: DesignSidebarTab.ai, title: "AI"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedTabs("Sidebar", tabs: Self.tabs, selection: tab, id: DesignControlID.sidebarTabs, onChange: { tab = $0 })
                .padding(.horizontal, SuiteSpacing.s)
                .padding(.vertical, SuiteSpacing.xs)
            switch tab {
            case .layers: DesignLayersPanel(model: model, perform: perform)
            case .ai:
                AgentActivityList(requests: model.agentRequests, layerNames: model.layerNamesByID,
                                  hidden: model.hiddenNodeIDs) { perform(.agent($0)) }
            }
        }
    }
}
