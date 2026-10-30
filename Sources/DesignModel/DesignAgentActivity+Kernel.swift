// DesignAgentActivity+Kernel.swift: Design's side of the sidebar's AI tab, an
// adapter onto SuiteKernel's AgentRequests, as Photo's is. `agentRequests`
// groups the agent steps of this document's history (`History.agentSteps`,
// timed by DesignHistory's `agentDates`). A step's layers come from its undo
// snapshot: every node on every page, each without its children, is compared
// by id with the node now (a new id was created, a differing value changed),
// so a child's edit doesn't list its group. `setLayersHidden` is the tab's
// eye, one "Hide Agent Layers"/"Show Agent Layers" step; `selectLayers` picks
// the live ids on one page: the selected page when it holds any, else the
// first page that does (switching to it); a hidden or locked one past the
// first stays out, as Shift-click refuses it. Linux-safe.
import SuiteKernel

extension DesignWorkspace {
    /// The agent's requests in this document, newest first.
    public var agentRequests: [AgentRequest] {
        let now = Self.bareNodes(pages)
        return AgentRequests.group(history.kernel.agentSteps(dates: history.agentDates) { step in
            let before = Dictionary(Self.bareNodes(step.payload.snapshot.pages).map { ($0.id, $0) },
                                    uniquingKeysWith: { a, _ in a })
            return now.filter { before[$0.id] != $0 }.map(\.id)
        })
    }

    /// Every node's name by id, on every page: the AI tab's layer rows.
    public var layerNamesByID: [String: String] {
        Dictionary(Self.bareNodes(pages).map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
    }

    /// The ids of the nodes hidden themselves, on every page.
    public var hiddenNodeIDs: Set<String> { Set(Self.bareNodes(pages).filter(\.isHidden).map(\.id)) }

    /// Hides or shows every live node in `ids` as one step; nothing when none changes.
    public mutating func setLayersHidden(_ ids: [String], hidden: Bool) {
        let targets = Self.bareNodes(pages).filter { ids.contains($0.id) && $0.isHidden != hidden }.map(\.id)
        guard !targets.isEmpty else { return }
        let before = snapshot
        for id in targets { _ = pages.update(id) { $0.isHidden = hidden } }
        record(hidden ? "Hide Agent Layers" : "Show Agent Layers", before: before)
    }

    /// Selects the live nodes among `ids` on one page (the selected one first); nothing when none is live.
    public mutating func selectLayers(_ ids: [String]) {
        let holds = { (page: DesignPage) in ids.contains { page.nodes.node($0) != nil } }
        guard let page = pages.first(where: { $0.id == selectedPageID && holds($0) }) ?? pages.first(where: holds)
        else { return }
        let live = ids.filter { page.nodes.node($0) != nil }
        guard let first = live.first else { return }
        selectItem(first)
        for id in live.dropFirst() where !selectedNodeIDs.contains(id) { toggleSelection(id) }
    }

    /// Every node on `pages`, depth first, each without its children.
    static func bareNodes(_ pages: [DesignPage]) -> [DesignNode] {
        var out: [DesignNode] = []
        var stack = pages.reversed().flatMap { $0.nodes.reversed() }
        while var node = stack.popLast() {
            stack += node.children.reversed()
            node.children = []
            out.append(node)
        }
        return out
    }
}
