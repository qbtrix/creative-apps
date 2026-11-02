// DesignAgentGlow.swift: the canvas's "the AI just touched this" glow, in the
// overlay under the selection's marks. When a newer agent step lands
// (`step`, the workspace's AgentWork.lastStep; an undo or redo back to an
// older one lights nothing), it outlines the nodes that step created or
// changed (DesignWorkspace.newestAgentLayers, diffed once per step) in a
// 2 pt accent box (DesignSelectionBox, no handles), holds AgentWork.linger,
// fades over SuiteMotion.agentFade (at once under Reduce Motion) to
// nothing. Equatable on (step, zoom), so a canvas render or a drag sample
// with no new step skips its body, and the fade runs in the render graph, so
// no body runs per frame. No shadow, blur or mask: render contract rule 4.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignAgentGlow: View, Equatable {
    let step: Int?
    let zoom: Double
    /// The touched nodes on the shown page, read once when a new step lands.
    let touched: @MainActor () -> [DesignNode]
    @State private var lit: [DesignNode] = []
    @State private var shown = false
    /// The newest step lit so far.
    @State private var seen = 0
    @State private var beat = 0
    @Environment(\.suiteReduceMotion) private var reduceMotion

    nonisolated static func == (lhs: Self, rhs: Self) -> Bool { lhs.step == rhs.step && lhs.zoom == rhs.zoom }

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(lit) { node in
                DesignSelectionBox(rect: node.frame, zoom: zoom, handles: false, degrees: node.rotation,
                                   lineWidth: SuiteSize.focusRing)
            }
        }
        .opacity(shown ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .onAppear { seen = step ?? 0 }
        .onChange(of: step) { _, new in
            guard let new, new > seen else { return }
            seen = new
            lit = touched()
            shown = !lit.isEmpty
            beat += 1
        }
        .task(id: beat) {
            guard beat > 0 else { return }
            try? await Task.sleep(for: .seconds(AgentWork.linger))
            guard !Task.isCancelled else { return }
            withAnimation(reduceMotion ? nil : SuiteMotion.agentFade) { shown = false }
        }
    }
}
