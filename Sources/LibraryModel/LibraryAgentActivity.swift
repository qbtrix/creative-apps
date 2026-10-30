// LibraryAgentActivity.swift: Library's side of the sidebar's AI tab, an
// adapter onto SuiteKernel's AgentRequests, as Photo's is. `agentRequests`
// groups the agent steps of the catalog's history (`History.agentSteps`,
// timed by CatalogHistory's `agentDates`). The tab only lists: a catalog has
// no layers, so a request opens to its steps alone, and with no
// `history.begin` in Library every request is loose steps, never a span.
// Linux-safe.
import SuiteKernel

extension LibraryCatalog {
    /// The agent's requests in this catalog, newest first.
    public var agentRequests: [AgentRequest] { AgentRequests.group(history.kernel.agentSteps(dates: history.agentDates)) }
}
