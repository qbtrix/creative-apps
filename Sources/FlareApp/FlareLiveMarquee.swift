// FlareLiveMarquee.swift: the marquee a selection drag draws while it lasts, kept out of the window's State. The
// window holds its model in State, and every write to that reruns the whole window, so a marquee's samples go to a
// copy in FlareMarqueeDrag (FlareModel) and only the rectangle the stage overlay draws is published here. A sample
// then reruns the overlay alone. The window takes the copy back at mouse-up, or drops it at Escape. Presentation
// state only.
import FlareCore
import FlareModel
import Observation

@MainActor @Observable final class FlareLiveMarquee {
    @ObservationIgnored private var drag = FlareMarqueeDrag()
    /// The rectangle the overlay draws; nil between marquee drags.
    private(set) var marquee: Rect?

    /// Applies one sample to the marquee copy. False when the window applies it to its model instead.
    func sample(_ model: FlareWorkspace, from start: Point, to end: Point, modifiers: DragModifiers,
                stageScale: Double) -> Bool {
        guard drag.sample(model, from: start, to: end, modifiers: modifiers, stageScale: stageScale) else { return false }
        marquee = drag.marquee
        return true
    }

    /// Mouse-up: the marquee gesture for the window to replay on the model; nil when no marquee drag ran.
    func take() -> FlareMarqueeDrag.Gesture? {
        marquee = nil
        return drag.take()
    }

    /// Escape: drops the marquee and its copy.
    func cancel() {
        marquee = nil
        drag.cancel()
    }
}
