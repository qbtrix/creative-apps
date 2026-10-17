// DesignStyleBudgetTests.swift: QD-S6 and QD-S7's model halves (docs/blueprints/design.md
// section 7.1; packet docs/blueprints/design/features/style-rows.md, ST-7), on `crowd`
// (2,000 layers) through `.live`. QD-S7: one coalesced inspector scrub step, the
// Opacity row's `setStyle` on two selected rectangles through LiveStyling, takes
// ≤ 0.5 ms on a device, so ≤ 5 ms under the Linux debug gate. QD-S6: one keystroke,
// `setTextDraft` while a text layer is being edited, takes ≤ 0.1 ms on a device, so
// ≤ 1 ms under the gate. As in DesignLayersBudgetTests, each gate reads the median of
// the runs, not one sample, so a single slow run on a busy worker doesn't fail it,
// and a warm-up step runs first so the timed steps all coalesce into the open run.
// A scrub step keeps the page's held ids, since a style edit changes no id, and walks
// only the path the edit copied (#2303: rebuilding the id set cost about 2 ms in a
// Linux debug build); the scrub gate still reads the quietest of three batches' medians.
// P2 is the screen half of both.
@testable import DesignModel
import Testing

// crowd: Frame 1 is node-1; its Rectangle 1 and 2 are node-2 and node-3, its Text node-50.
private enum ID {
    static let first = "node-2", second = "node-3", text = "node-50"
}

@Suite struct DesignStyleBudgetTests {
    /// `crowd` on `.live`.
    private func liveCrowd() -> DesignWorkspace {
        var workspace = DesignFixtures.crowd
        workspace.useServices(.live)
        return workspace
    }

    @Test func scrubStep() throws {
        var workspace = liveCrowd()
        workspace.selectItem(ID.first)
        workspace.toggleSelection(ID.second)
        let gate = DesignBudget.linuxDebugGate(device: .microseconds(500))
        try workspace.setStyle(.opacity(0.5))  // warm-up: opens the run the timed steps join
        var step = 0
        // Three batches; the quietest batch's median is the step's cost (see the header).
        let reports = try (0..<3).map { _ in
            try DesignBudget.measure(runs: 30) {
                step += 1
                try workspace.setStyle(.opacity(step % 2 == 0 ? 0.5 : 0.4))
            }
        }
        let report = reports.min { $0.median < $1.median } ?? DesignBudget.Report(samples: [])
        #expect(step == 90, "the timed scrub ran \(step) steps, not 90")
        let opacity = workspace.selectedPage?.nodes.node(ID.second)?.opacity
        #expect(opacity == (step % 2 == 0 ? 0.5 : 0.4), "the timed scrub left opacity \(String(describing: opacity))")
        #expect(workspace.history.undo.map(\.name) == ["Change Opacity"], "the scrub is not one step")
        #expect(report.median <= gate, "QD-S7 scrub step on crowd: \(report), median over the gate \(gate)")
    }

    @Test func textDraftStep() throws {
        var workspace = liveCrowd()
        try workspace.beginTextEdit(ID.text)
        let gate = DesignBudget.linuxDebugGate(device: .microseconds(100))
        workspace.setTextDraft("Text ")  // warm-up keystroke
        var typed = "Text "
        let report = DesignBudget.measure(runs: 200) {
            typed.append("a")
            workspace.setTextDraft(typed)
        }
        #expect(workspace.editingTextID == ID.text)
        #expect(workspace.textDraft == typed, "the timed keystrokes left the draft \(workspace.textDraft.count) long")
        #expect(workspace.history.undo.isEmpty, "a keystroke recorded a step")
        #expect(report.median <= gate, "QD-S6 text draft step on crowd: \(report), median over the gate \(gate)")
    }
}
