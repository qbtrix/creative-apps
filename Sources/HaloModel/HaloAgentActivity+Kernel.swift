// HaloAgentActivity+Kernel.swift: Halo's side of the sidebar's AI tab, an
// adapter onto SuiteKernel's AgentRequests, as Photo's is. `agentRequests`
// groups the agent steps of this project's history (`History.agentSteps`,
// timed by HaloHistory's `agentDates`). A step's layers come from its undo
// state against the next step's (the document now for the newest): every
// layer of every composition is compared by id (a new id was created, a
// differing value changed), so a later edit never joins an older request. Halo layers have no
// visibility, so the tab has no eye; `selectLayers` picks one layer, as
// Halo's selection holds one: the first live id in the selected composition,
// else in the first composition that holds one (switching to it).
// `undoAgentRequest` runs `history.undo-request` and leaves a refusal in
// `refusal`. Linux-safe.
import SuiteKernel

extension HaloProject {
    /// The agent's requests in this project, newest first.
    public var agentRequests: [AgentRequest] {
        AgentRequests.group(history.kernel.agentSteps(dates: history.agentDates) { step, next in
            let before = Dictionary(step.payload.compositions.flatMap(\.layers).map { ($0.id, $0) },
                                    uniquingKeysWith: { a, _ in a })
            let after = (next?.payload ?? document).compositions.flatMap(\.layers)
            return after.filter { before[$0.id] != $0 }.map(\.id)
        })
    }

    /// Every layer's name by id, in every composition: the AI tab's layer rows.
    public var layerNamesByID: [String: String] {
        Dictionary(document.compositions.flatMap(\.layers).map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
    }

    /// Selects the first live layer among `ids`, the selected composition's first; nothing when none is live.
    public mutating func selectLayers(_ ids: [String]) {
        let holds = { (comp: HaloComposition) in comp.layers.contains { ids.contains($0.id) } }
        guard let comp = compositions.first(where: { $0.id == selectedCompositionID && holds($0) })
            ?? compositions.first(where: holds),
            let id = ids.first(where: { id in comp.layers.contains { $0.id == id } })
        else { return }
        selectComposition(comp.id)
        selectLayer(id)
    }

    /// Undoes the agent's request `title` as one (`history.undo-request`); a refusal shows in `refusal`.
    public mutating func undoAgentRequest(_ title: String) {
        do {
            _ = try Self.catalog.run("history.undo-request", params: .object(["name": .string(title)]), on: &self)
        } catch {
            refusal = HaloRefusal(control: "suite.agent", message: error.description)
        }
    }
}
