// FlareStageGuides.swift: the stage's guides (stage-edit SE-2, J14) as ViewportGuideMarks over the artboard, any drag
// under way drawn where it is. Each guide is a hidden `flare.stage.guide.<i>` probe ("y 300") and a hit strip that
// drags it; released over its ruler it is removed. The document changes on release, via FlareGuideDrag's intents.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareStageGuides: View {
    static let space = "flare.stage"
    let model: FlareWorkspace
    let zoom: Double
    var showsGuides = true
    var showsRulers = true
    /// A guide coming out of a ruler, or the snapshot's drag; this view's own line drag wins over it.
    var drag: FlareGuideDrag? = nil
    let perform: @MainActor (FlareIntent) -> Void
    @State private var lineDrag: FlareGuideDrag?

    var body: some View {
        if showsGuides, let scene = model.selectedScene, zoom > 0 {
            let board = CGRect(x: 0, y: 0, width: scene.width * zoom, height: scene.height * zoom)
            let shown = (lineDrag ?? drag)?.shown(over: model.guides) ?? model.guides
            ZStack(alignment: .topLeading) {
                ViewportGuideMarks(guides: shown.map(Self.mark), zoom: zoom, viewport: board)
                ForEach(Array(model.guides.enumerated()), id: \.offset) { index, guide in
                    ProbeElement(
                        "flare.stage.guide.\(index)", label: model.guideReadout(at: index) ?? "",
                        rect: Self.strip(guide, scene: scene, thickness: 2 / zoom), zoom: zoom)
                    hitStrip(index, guide: guide, scene: scene)
                }
            }
            .frame(width: board.width, height: board.height, alignment: .topLeading)
        }
    }

    private nonisolated static func mark(_ guide: Guide) -> ViewportGuide {
        guide.axis == .horizontal ? .horizontal(y: guide.position) : .vertical(x: guide.position)
    }

    private nonisolated static func strip(_ guide: Guide, scene: FlareCore.Scene, thickness: Double) -> CGRect {
        let half = thickness / 2
        return guide.axis == .horizontal
            ? CGRect(x: 0, y: guide.position - half, width: scene.width, height: thickness)
            : CGRect(x: guide.position - half, y: 0, width: thickness, height: scene.height)
    }

    /// The clear strip that picks guide `index` up; a drag moves it, a release over its ruler removes it.
    private func hitStrip(_ index: Int, guide: Guide, scene: FlareCore.Scene) -> some View {
        let box = Self.strip(guide, scene: scene, thickness: SuiteSize.anchorHit / zoom)
            .applying(CGAffineTransform(scaleX: zoom, y: zoom))
        return Color.clear
            .frame(width: box.width, height: box.height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1, coordinateSpace: .named(Self.space))
                    .onChanged { value in
                        var next = lineDrag ?? FlareGuideDrag(guide: index, of: model.guides)
                        let moved = guide.axis == .horizontal ? value.translation.height : value.translation.width
                        next?.move(to: guide.position + moved / zoom)
                        lineDrag = next
                    }
                    .onEnded { value in
                        let edge = guide.axis == .horizontal ? value.location.y : value.location.x
                        lineDrag?.end(overRuler: edge < (showsRulers ? SuiteSize.ruler : 0)).forEach { perform($0) }
                        lineDrag = nil
                    }
            )
            .accessibilityHidden(true)
            .offset(x: box.minX, y: box.minY)
    }
}
