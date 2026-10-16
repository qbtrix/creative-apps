// FlareWindow+Stage.swift: the router's stage area (FlareWindow+Router.swift). FlareStage's drags arrive here: a
// pointer move is the Model's `dragChanged` (the live draft, marquee or move preview), mouse-up its `endDrag` (one
// undo step, or a selection change), and Escape mid-drag its `cancelDrag`. A selection marquee's samples skip the
// model and go to FlareLiveMarquee, so the window reruns once, at mouse-up, instead of once per sample.
import FlareModel

extension FlareWindow {
    /// Acts on a stage intent through the Model's gesture methods.
    func performStage(_ intent: FlareIntent.Stage) {
        switch intent {
        case .dragChanged(let start, let end, let shift, let option, let stageScale):
            var modifiers: DragModifiers = []
            if shift { modifiers.insert(.shift) }
            if option { modifiers.insert(.option) }
            if liveMarquee.sample(model, from: start, to: end, modifiers: modifiers, stageScale: stageScale) { return }
            model.dragChanged(from: start, to: end, modifiers: modifiers, stageScale: stageScale)
        case .endDrag: endGesture()
        case .cancelDrag:
            liveMarquee.cancel()
            model.cancelDrag()
        }
    }

    /// Mouse-up: a marquee replays its gesture on the model, one drag; otherwise the model ends its own gesture.
    /// Either way the model is written once, so the window reruns once.
    func endGesture() {
        guard let marquee = liveMarquee.take() else { return model.endDrag() }
        model.drag(from: marquee.start, to: marquee.end, modifiers: marquee.modifiers, stageScale: marquee.stageScale)
    }

    /// Why a stage intent can't act now: the stage needs an open scene.
    func stageHelp(_ intent: FlareIntent.Stage) -> String? {
        model.selectedScene == nil ? "Open an animation to draw on the stage." : nil
    }
}
