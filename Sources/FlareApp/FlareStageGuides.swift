// FlareStageGuides.swift: the stage's ruler guides (stage-edit SE-2, J14), in the stage's overlay at the artboard's
// size. While `showsGuides` it draws the selected scene's guides as SuiteUI's ViewportGuideMarks across the artboard,
// with the drag under way (`drag`, a guide coming out of a ruler, or this view's own line drag) where it is. Each guide is a hidden `flare.stage.guide.<i>` probe whose label is its readout ("y 300")
// and a thin hit strip: dragging it moves the guide, and releasing it over its ruler (in the stage's `space`) removes
// it. The document changes once, on release, through the FlareGuideDrag's intents. It only reads `model`.
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareStageGuides: View {
    /// The stage's coordinate space: the viewport, with the rulers along its top and leading edges.
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
            let current = lineDrag ?? drag
            let shown = current?.shown(over: model.guides) ?? model.guides
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

    /// The guide's line as a ViewportGuide.
    private nonisolated static func mark(_ guide: Guide) -> ViewportGuide {
        guide.axis == .horizontal ? .horizontal(y: guide.position) : .vertical(x: guide.position)
    }

    /// A strip `thickness` scene points across, centred on the guide's line and spanning the scene.
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
                        let ended = lineDrag
                        lineDrag = nil
                        ended?.end(overRuler: edge < (showsRulers ? SuiteSize.ruler : 0)).forEach { perform($0) }
                    }
            )
            .accessibilityHidden(true)
            .offset(x: box.minX, y: box.minY)
    }
}
