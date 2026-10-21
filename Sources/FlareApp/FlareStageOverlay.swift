// FlareStageOverlay.swift: the stage's marks over the committed art (packet draw-key-save, DK-8), from
// `model.stageMarks` in scene points at the stage zoom: the draft a drawing drag would add (its outline in the accent
// color, curves kept by StagePath), the marquee under way and the selection box (each a SelectionOutline from
// CanvasMarks). The draft is the drawn path itself for every kind, so the Shape tool's star, polygon, line and arrow
// preview as themselves, never as their box (shape-tools FS-3). It redraws on a pointer move while the Canvas under it
// redraws only when the list changes. It never takes a click; the canvas gesture does.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareStageOverlay: View {
    let marks: StageMarks
    let zoom: Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let draft = Self.draftPath(marks, zoom: zoom) {
                SwiftUI.Path(draft).stroke(SuiteColor.accent, lineWidth: 1)
            }
            if let marquee = marks.marquee { SelectionOutline(rect: Self.rect(marquee), zoom: zoom) }
            if let selection = marks.selection { SelectionOutline(rect: Self.rect(selection), zoom: zoom) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The draft's own path in stage points at `zoom`, or nil with no draft.
    nonisolated static func draftPath(_ marks: StageMarks, zoom: Double) -> CGPath? {
        marks.draft.map { StagePath.cgPath($0, transform: .scale(x: zoom, y: zoom)) }
    }

    /// `rect` in scene points as a CGRect.
    static func rect(_ rect: Rect) -> CGRect {
        CGRect(x: rect.minX, y: rect.minY, width: rect.maxX - rect.minX, height: rect.maxY - rect.minY)
    }
}
