// HaloWindow+Agent.swift: the sidebar AI tab's routes. A click selects the
// request's first live layer (`selectLayers`, switching composition when
// needed); Undo Request runs `history.undo-request` through the Model, whose
// refusal shows like any other. Halo layers can't hide, so the tab has no eye
// and `setHidden` never comes.
import HaloModel
import SuiteUI

extension HaloWindow {
    func agentPerform(_ action: AgentActivityAction) {
        takePlayback()
        switch action {
        case .select(let ids): model.selectLayers(ids)
        case .undoRequest(let title): model.undoAgentRequest(title)
        case .setHidden: break
        }
    }
}
