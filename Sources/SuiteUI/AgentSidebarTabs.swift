// AgentSidebarTabs.swift: the sidebar every app shares for its AI tab:
// SegmentedTabs over the app's own list (Layers, Compositions, Library) and
// AI, which the app fills with AgentActivityList. The picked tab is this
// view's own state, so switching tabs runs no app body and no canvas render;
// the AI content is built only while its tab shows. Segment ids are
// `<id>.<primary title, lower case>` and `<id>.ai`.
import SwiftUI

/// Which of the two sidebar tabs shows.
public enum AgentSidebarTab: Hashable, Sendable {
    case primary, ai
}

public struct AgentSidebarTabs<Primary: View, AI: View>: View {
    private let tabs: [InspectorOption<AgentSidebarTab>]
    private let id: String
    private let primary: Primary
    private let ai: () -> AI
    @State private var tab: AgentSidebarTab

    /// `primaryTitle` names the app's own tab; `id` lists the switch in `suite.controls`.
    public init(_ primaryTitle: String, id: String, tab: AgentSidebarTab = .primary,
                @ViewBuilder primary: () -> Primary, @ViewBuilder ai: @escaping () -> AI) {
        tabs = [
            InspectorOption(id: .primary, title: primaryTitle, identifier: "\(id).\(primaryTitle.lowercased())"),
            InspectorOption(id: .ai, title: "AI", identifier: "\(id).ai"),
        ]
        (self.id, self.primary, self.ai) = (id, primary(), ai)
        _tab = State(initialValue: tab)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedTabs("Sidebar", tabs: tabs, selection: tab, id: id, onChange: { tab = $0 })
                .padding(.horizontal, SuiteSpacing.s)
                .padding(.vertical, SuiteSpacing.xs)
            switch tab {
            case .primary: primary
            case .ai: ai()
            }
        }
    }
}
