// FlareLiveDrag.swift: a stage drag under way, kept out of the window's state (#1792, docs/engineering/swiftui-rules.md
// rule 1). Every write to the window's FlareWorkspace re-runs the whole window, so the stage runs a drag's samples on
// a copy of the workspace here (`move`, the workspace's own `dragChanged`) and draws its draft, marquee and move
// preview from that copy. At mouse-up the window gets only the last sample and `endDrag`: the gesture keeps its first
// point, and each sample replaces the one before it, so the last one gives the same draft, move or marquee as all of
// them did, and one undo step. Value type; the stage holds it in its own view state.
import FlareCore

/// One pointer sample of a stage drag, in scene points: the gesture's first point, where the pointer is now, the keys
/// held and the stage's fit scale.
public struct StageDragSample: Sendable, Equatable {
    public var start: Point, end: Point, modifiers: DragModifiers, stageScale: Double
    public init(start: Point, end: Point, modifiers: DragModifiers = [], stageScale: Double = 1) {
        self.start = start; self.end = end; self.modifiers = modifiers; self.stageScale = stageScale
    }
}

/// A drag's samples on a copy of the workspace taken at its first sample.
public struct FlareLiveDrag: Sendable, Equatable {
    /// The copy with every sample so far applied; never handed back to the window.
    public private(set) var shown: FlareWorkspace
    /// The latest sample, for the window at mouse-up; nil before the first.
    public private(set) var last: StageDragSample?

    public init(on workspace: FlareWorkspace) { shown = workspace }

    /// One pointer move: updates the copy's live preview and keeps the sample.
    public mutating func move(_ sample: StageDragSample) {
        shown.dragChanged(from: sample.start, to: sample.end, modifiers: sample.modifiers, stageScale: sample.stageScale)
        last = sample
    }

    /// The stage with the move under way applied; nil when the drag moves nothing, so the stage draws the window's list.
    public var movePreview: StageDrawList? { shown.dragPreview }

    /// The overlay while the drag lasts: its draft, marquee and the selection box.
    public var stageMarks: StageMarks { shown.stageMarks }
}
