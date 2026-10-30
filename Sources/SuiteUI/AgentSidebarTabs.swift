// AgentSidebarTabs.swift: the sidebar every app shares for its AI tab:
// SegmentedTabs over the app's own list (Layers, Compositions, Library) and
// AI, which the app fills with AgentActivityList. The picked tab is this
// view's own state, so switching tabs runs no app body and no canvas render;
// the AI content is built only while its tab shows. While an agent works
// (`work`, the app's AgentWork) AgentWorkingMark pulses at the AI segment's
// trailing edge, whichever tab is picked; `work` is read inside the mark's
// own reader, so an agent step reruns neither this body nor the primary tab.
// Segment ids are `<id>.<primary title, lower case>` and `<id>.ai`; the
// mark is `<id>.ai.working`.
import SuiteKernel
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
    private let work: @MainActor () -> AgentWork
    @State private var tab: AgentSidebarTab

    /// `primaryTitle` names the app's own tab; `id` lists the switch in `suite.controls`. `work` reads the
    /// document's AgentWork (`History.agentWork`) for the working mark.
    public init(_ primaryTitle: String, id: String, tab: AgentSidebarTab = .primary,
                work: @escaping @MainActor () -> AgentWork = { AgentWork() },
                @ViewBuilder primary: () -> Primary, @ViewBuilder ai: @escaping () -> AI) {
        tabs = [
            InspectorOption(id: .primary, title: primaryTitle, identifier: "\(id).\(primaryTitle.lowercased())"),
            InspectorOption(id: .ai, title: "AI", identifier: "\(id).ai"),
        ]
        (self.id, self.primary, self.ai, self.work) = (id, primary(), ai, work)
        _tab = State(initialValue: tab)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedTabs("Sidebar", tabs: tabs, selection: tab, id: id, onChange: { tab = $0 })
                // Over the picker: a segment's label draws no custom or animated view.
                .overlay(alignment: .trailing) {
                    AgentWorkingReader(read: work, id: "\(id).ai.working")
                        .padding(.trailing, SuiteSpacing.m)
                        .allowsHitTesting(false)
                }
                .padding(.horizontal, SuiteSpacing.s)
                .padding(.vertical, SuiteSpacing.xs)
            switch tab {
            case .primary: primary
            case .ai: ai()
            }
        }
    }
}

/// Reads the app's AgentWork in its own body, so observing it reruns only this and the mark.
private struct AgentWorkingReader: View {
    let read: @MainActor () -> AgentWork
    let id: String

    var body: some View { AgentWorkingMark(read(), id: id).equatable() }
}
