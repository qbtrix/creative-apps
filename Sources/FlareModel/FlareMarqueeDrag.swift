// FlareMarqueeDrag.swift: the marquee a selection-tool drag on empty stage draws while it lasts. The window keeps the
// model in State, so every write to it reruns the whole window; a marquee's samples (60 to 120 a second) are kept
// here instead, and the app draws `marquee` on its own overlay. At mouse-up `take` gives back the gesture's points
// and keys, and the window replays them on the model as one `drag`: a marquee's selection depends on nothing else.
// A click, a move of an item, or a pen or rectangle draft is declined: the caller applies that gesture to the model,
// sample by sample as before. Presentation state only; Linux-safe.
import FlareCore

public struct FlareMarqueeDrag: Sendable {
    /// A marquee gesture's points and keys, as the mouse-up replays them on the model.
    public struct Gesture: Sendable, Equatable {
        public let start: Point
        public let end: Point
        public let modifiers: DragModifiers
        public let stageScale: Double

        public init(start: Point, end: Point, modifiers: DragModifiers, stageScale: Double) {
            self.start = start
            self.end = end
            self.modifiers = modifiers
            self.stageScale = stageScale
        }
    }

    /// The gesture under way; nil until a sample proves a marquee.
    private var gesture: Gesture?
    /// Set once a gesture proves it is a draft or a move, so its later samples skip the probe.
    private var declined = false

    public init() {}

    /// The rectangle under way, in scene points; nil when no marquee drag is.
    public var marquee: Rect? {
        gesture.flatMap { Rect(enclosing: [$0.start, $0.end]) }
    }

    /// One pointer sample. True when it is a marquee; false when the caller applies it to `model`.
    public mutating func sample(_ model: FlareWorkspace, from start: Point, to end: Point,
                                modifiers: DragModifiers, stageScale: Double) -> Bool {
        let next = Gesture(start: start, end: end, modifiers: modifiers, stageScale: stageScale)
        if gesture != nil {
            gesture = next
            return true
        }
        guard !declined else { return false }
        // The probe is a copy: the model is not written, so a sample that turns out to be a click or a draft
        // leaves the model untouched by this check.
        var probe = model
        probe.dragChanged(from: start, to: end, modifiers: modifiers, stageScale: stageScale)
        if probe.draft != nil || probe.dragPreview != nil {
            declined = true
            return false
        }
        guard probe.marquee != nil else { return false }
        gesture = next
        return true
    }

    /// Mouse-up: the marquee gesture to replay on the model; nil when no marquee drag ran.
    public mutating func take() -> Gesture? {
        defer { self = FlareMarqueeDrag() }
        return gesture
    }

    /// Escape: drops the marquee.
    public mutating func cancel() { self = FlareMarqueeDrag() }
}
