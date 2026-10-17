// FlareStageOverlay.swift: the stage's marks over the committed art (packet draw-key-save, DK-8), from
// `model.stageMarks` in scene points at the stage zoom: the draft a drawing drag would add (its outline in the accent
// color, curves kept by StagePath), the marquee under way and the selection box (each a SelectionOutline from
// CanvasMarks). It redraws on a pointer move while the Canvas under it redraws only when the list changes. It never
// takes a click; the canvas gesture does.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareStageOverlay: View {
    let marks: StageMarks
    let zoom: Double

    var body: some View {
        ZStack(alignment: .topLeading) {
            if let draft = marks.draft {
                SwiftUI.Path(StagePath.cgPath(draft, transform: .scale(x: zoom, y: zoom)))
                    .stroke(SuiteColor.accent, lineWidth: 1)
            }
            if let marquee = marks.marquee { SelectionOutline(rect: Self.rect(marquee), zoom: zoom) }
            if let selection = marks.selection { SelectionOutline(rect: Self.rect(selection), zoom: zoom) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// `rect` in scene points as a CGRect.
    static func rect(_ rect: Rect) -> CGRect {
        CGRect(x: rect.minX, y: rect.minY, width: rect.maxX - rect.minX, height: rect.maxY - rect.minY)
    }
}
