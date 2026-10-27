// DesignInspectorFill.swift (gradient-fill DG-2): the Fill section's type switch, Solid, Linear or
// Radial, over the selection's kernel fill. It reads `fillSelection` and `fillHelp` from the Model and
// sends every pick as a `GradientIntent` through `.fill`, which DesignWindow hands to `runFill`. While
// `fillHelp` says why (nothing selected, a locked layer, or gradients not built yet) the switch is off
// and that reason is its tooltip and a note under it. The switch is SuiteUI's: a gradient shows its
// GradientEditor (the switch, its stops, colour and angle; GF-3 landed it, gradient-fill DG-u), a solid
// its `GradientTypeSwitch` alone, both under `design.inspector.fill-type`. While the mouse is down in the
// editor (a stop drag, an angle scrub) its intents preview on the window's live box (DesignLiveDrag), which
// this section and the canvas read, and mouse-up lands them as one step (`.endEditRun`), so the window
// doesn't run per sample; a click, key or picked colour goes straight to `.fill`. Values in, intents out.
import DesignModel
import SuiteKernel
import SuiteUI
import SwiftUI

struct DesignInspectorFill: View {
    let model: DesignWorkspace
    let perform: DesignPerform
    @Environment(\.designLiveDrag) private var live
    /// The mouse is down in the editor: its intents preview until mouse-up.
    @State private var pressing = false

    var body: some View {
        let help = model.fillHelp
        let shown = live?.workspace ?? model
        let type = shown.fillSelection.map { GradientRules.type(of: $0.fill) } ?? .solid
        VStack(alignment: .leading, spacing: SuiteSpacing.xs) {
            if let selection = shown.fillSelection, type != .solid {
                // SuiteUI's editor with its switch: the stop bar, the stop's colour and location and, for a
                // linear fill, the angle, each gesture an intent to `runFill`.
                GradientEditor(fill: selection.fill, box: selection.box, typeID: DesignControlID.inspectorFillType,
                               typeHelp: help) { send($0) }
                    .disabled(help != nil)
                    .help(help ?? "Gradient stops and angle")
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in pressing = true }
                            .onEnded { _ in
                                pressing = false
                                perform(.endEditRun)
                            })
            } else {
                GradientTypeSwitch(type: type, typeID: DesignControlID.inspectorFillType, help: help) {
                    perform(.fill(.type($0)))
                }
            }
        }
    }

    /// A drag's intent previews on the live box; any other goes to the workspace. Without a box, each goes straight.
    private func send(_ intent: GradientIntent) {
        guard pressing, let live else { return perform(.fill(intent)) }
        if !live.isLive { live.begin(from: model) }
        live.preview(intent)
    }
}
