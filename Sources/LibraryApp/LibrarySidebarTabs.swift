// LibrarySidebarTabs.swift: Library's sidebar, SuiteUI's SegmentedTabs over
// two tabs, as Photo's is: Library (the window's collections and folders
// list, passed in) and AI (SuiteUI AgentActivityList over the catalog's
// `agentRequests`). The AI tab only lists: a catalog has no layers, so it
// has no eye and a request opens to its steps alone; its gestures change
// nothing. The picked tab is this view's own state, so switching tabs or
// opening a request row runs no window body and no grid render.
import LibraryModel
import SuiteUI
import SwiftUI

enum LibrarySidebarTab: Hashable, Sendable {
    case library, ai
}

struct LibrarySidebarTabs<Sections: View>: View {
    let model: LibraryCatalog
    let sections: Sections
    @State var tab: LibrarySidebarTab

    init(model: LibraryCatalog, tab: LibrarySidebarTab = .library, @ViewBuilder sections: () -> Sections) {
        (self.model, self.sections) = (model, sections())
        _tab = State(initialValue: tab)
    }

    static var tabs: [InspectorOption<LibrarySidebarTab>] {
        [InspectorOption(id: .library, title: "Library"), InspectorOption(id: .ai, title: "AI")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedTabs("Sidebar", tabs: Self.tabs, selection: tab, id: "library.sidebar.tabs", onChange: { tab = $0 })
                .padding(.horizontal, SuiteSpacing.s)
                .padding(.vertical, SuiteSpacing.xs)
            switch tab {
            case .library: sections
            case .ai:
                // List only: no layer to show, hide or select, and no span to undo in Library.
                AgentActivityList(requests: model.agentRequests, layerNames: [:], hidden: [], showsEye: false) { _ in }
            }
        }
    }
}
