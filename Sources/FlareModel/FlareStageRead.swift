// FlareStageRead.swift: what the stage draws, read off the workspace (packet draw-key-save, DK-4). `stageList` is the
// move preview while a selection drag runs, else the stage service's list at the playhead for the edited owner;
// `stageMarks` is the overlay: the draft's outline, the marquee and the selection box.
import FlareCore

/// The stage overlay, in scene points: the shape a drawing drag would add, the marquee under way and the selection box.
public struct StageMarks: Sendable, Equatable {
    public var draft: FlarePath?, marquee: Rect?, selection: Rect?
    public init(draft: FlarePath? = nil, marquee: Rect? = nil, selection: Rect? = nil) {
        self.draft = draft; self.marquee = marquee; self.selection = selection
    }
}

extension FlareWorkspace {
    /// The stage picture to draw; nil with no document or scene.
    public var stageList: StageDrawList? {
        guard let document, let sceneID = selectedSceneID else { return nil }
        return dragPreview ?? services.stage.drawList(document, sceneID: sceneID, frame: currentFrame,
                                                       editing: editingSymbolID)
    }

    /// The overlay over `stageList`; the selection box is nil with nothing selected.
    public var stageMarks: StageMarks {
        StageMarks(draft: draft?.shape.outline, marquee: marquee, selection: selection.isEmpty ? nil : selectionBounds)
    }
}
