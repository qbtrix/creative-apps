// HaloSidebarTabs.swift: Halo's sidebar, SuiteUI's SegmentedTabs over two
// tabs, as Photo's is: Compositions (the window's composition list, passed
// in) and AI (SuiteUI AgentActivityList over the project's `agentRequests`,
// with no eye: Halo layers can't hide yet). The picked tab is this view's
// own state, so switching tabs or opening a request row runs no window body
// and no viewer render. Values in, intents out: AI gestures leave through
// `onAgent` (HaloWindow+Agent.swift).
import HaloModel
import SuiteUI
import SwiftUI

enum HaloSidebarTab: Hashable, Sendable {
    case compositions, ai
}

struct HaloSidebarTabs<Compositions: View>: View {
    let model: HaloProject
    let onAgent: @MainActor (AgentActivityAction) -> Void
    let compositions: Compositions
    @State var tab: HaloSidebarTab

    init(model: HaloProject, tab: HaloSidebarTab = .compositions,
         onAgent: @escaping @MainActor (AgentActivityAction) -> Void, @ViewBuilder compositions: () -> Compositions) {
        (self.model, self.onAgent, self.compositions) = (model, onAgent, compositions())
        _tab = State(initialValue: tab)
    }

    static var tabs: [InspectorOption<HaloSidebarTab>] {
        [InspectorOption(id: .compositions, title: "Compositions"), InspectorOption(id: .ai, title: "AI")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedTabs("Sidebar", tabs: Self.tabs, selection: tab, id: "halo.sidebar.tabs", onChange: { tab = $0 })
                .padding(.horizontal, SuiteSpacing.s)
                .padding(.vertical, SuiteSpacing.xs)
            switch tab {
            case .compositions: compositions
            case .ai:
                AgentActivityList(requests: model.agentRequests, layerNames: model.layerNamesByID, hidden: [],
                                  showsEye: false, onAction: onAgent)
            }
        }
    }
}
