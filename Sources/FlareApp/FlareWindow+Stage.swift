// FlareWindow+Stage.swift: the router's stage area (FlareWindow+Router.swift). FlareStage's drags arrive here: a
// pointer move is the Model's `dragChanged` (the live draft, marquee or move preview), mouse-up its `endDrag` (one
// undo step, or a selection change), Escape mid-drag its `cancelDrag`, and a right click its `contextClick` (the
// context menu's target, FlareStageContextMenu.swift).
import FlareModel

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
        case .contextClick(let point, let stageScale): model.contextClick(at: point, stageScale: stageScale)
        }
    }

    /// Why a stage intent can't act now: the stage needs an open scene.
    func stageHelp(_ intent: FlareIntent.Stage) -> String? {
        model.selectedScene == nil ? "Open an animation to draw on the stage." : nil
    }
}
