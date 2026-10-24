// FlareWindow+Stage.swift: the router's stage area (FlareWindow+Router.swift). FlareStage's drags arrive here: a
// pointer move is the Model's `dragChanged` (the live draft, marquee or move preview), mouse-up its `endDrag` (one
// undo step, or a selection change), and Escape mid-drag its `cancelDrag`. FlarePathEditLayer (FP-2, FP-u) draws
// Direct Select's `editablePath` (none on a locked layer; the status bar's pill says why) with its `anchorSelection`
// filled, and the Pen's `penDraft`, in PathEditOverlay on the kernel's types (PN-3). It passes presses through: the
// stage's gesture routes every press (FlareDrag, FP-7: an anchor or handle wins over the item, then the anchor
// marquee). It still takes hover, so the Pen's rubber band and close ring, the hovered anchor's ring and the pointer
// show; `.allowsHitTesting(false)` would drop those too.
import FlareCore
import FlareModel
import SuiteKernel
import SuiteUI
import SwiftUI

extension FlareWindow {
    /// Acts on a stage intent through the Model's gesture methods.
    func performStage(_ intent: FlareIntent.Stage) {
        switch intent {
        case .dragChanged(let start, let end, let shift, let option, let stageScale):
            var modifiers: DragModifiers = []
            if shift { modifiers.insert(.shift) }
            if option { modifiers.insert(.option) }
            model.dragChanged(from: start, to: end, modifiers: modifiers, stageScale: stageScale)
        case .endDrag: model.endDrag()
        case .cancelDrag: model.cancelDrag()
        }
    }

    /// Why a stage intent can't act now: the stage needs an open scene.
    func stageHelp(_ intent: FlareIntent.Stage) -> String? {
        model.selectedScene == nil ? "Open an animation to draw on the stage." : nil
    }
}

/// The path overlay over the stage: Direct Select's picked shape with its picked anchors and the Pen's open draft,
/// read from `model`. Marks and hover only: presses reach the stage's gesture, so it sends no intents.
struct FlarePathEditLayer: View {
    let model: FlareWorkspace
    let zoom: Double

    var body: some View {
        if let tool: PenTool = model.tool == .pen ? .pen : model.tool == .directSelect ? .directSelect : nil {
            PathEditOverlay(
                draft: model.penDraft, path: model.editablePath, selection: model.anchorSelection, tool: tool,
                zoom: zoom, onIntent: { _ in })
            .pressesPassThrough()
        }
    }
}
