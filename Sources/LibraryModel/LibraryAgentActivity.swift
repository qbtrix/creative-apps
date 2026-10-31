// LibraryAgentActivity.swift: Library's side of the sidebar's AI tab, an
// adapter onto SuiteKernel's AgentRequests, as Photo's is. `agentRequests`
// groups the agent steps of the catalog's history (`History.agentSteps`,
// timed by CatalogHistory's `agentDates`). The tab only lists: a catalog has
// no layers, so a request opens to its steps alone, and with no
// `history.begin` in Library every request is loose steps, never a span.
// `agentWork` feeds the tab's working marks.
// Linux-safe.
import SuiteKernel

extension LibraryCatalog {
    /// The sidebar's Library | AI switch; each segment is `<id>.<tab>` (SuiteUI AgentSidebarTabs).
    public static let sidebarTabsID = "library.sidebar.tabs"
    /// Why the AI tab's Undo Request never runs here: Library has no request spans.
    public static let agentUndoHelp = "Library can't undo a request as one."

    /// The agent's requests in this catalog, newest first.
    public var agentRequests: [AgentRequest] { AgentRequests.group(history.kernel.agentSteps(dates: history.agentDates)) }

    /// The open request and the newest agent step: what the AI tab's working marks read (SuiteUI AgentWorking).
    public var agentWork: AgentWork { history.kernel.agentWork }
}
