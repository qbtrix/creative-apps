// FlareStage.swift: the stage, the top of Flare's content (packet draw-key-save, DK-8). The scene's draw list
// (`model.stageList`) is drawn in one Canvas under `.drawingGroup()` on CanvasViewport, so the committed art redraws
// only when the list changes; FlareStageOverlay draws the marks (draft, marquee, selection outline) over it. A drag
// sends `.stage(.dragChanged)` with the gesture's start, Shift and Option and the zoom, then `.stage(.endDrag)`. A
// tool letter (V A R E P) chooses its tool; every other key goes to `onKey` (the window's `toolKey`). The floating
// glass palette lists FlareTool.allCases, each with `model.toolHelp` as its reason when it can't act. It only reads
// `model`; every change goes through `perform`.
import AppKit
import FlareCore
import FlareModel
import SuiteUI
import SwiftUI

struct FlareStage: View {
    let model: FlareWorkspace
    let zoom: Double?
    let showsRulers: Bool
    let showsGuides: Bool
    let perform: @MainActor (FlareIntent) -> Void
    let help: @MainActor (FlareIntent) -> String?
    /// A key the stage doesn't take itself; the window passes `toolKey` (Escape, Return).
    var onKey: @MainActor (KeyPress) -> KeyPress.Result = { _ in .ignored }
    /// The gesture under way's first point, in scene points; nil between drags.
    @State private var dragStart: CGPoint?
    /// The viewport's size, for the fit while `zoom` is nil.
    @State private var viewport: CGSize = .zero

    var body: some View {
        if let scene = model.selectedScene {
            let size = CGSize(width: scene.width, height: scene.height)
            let scale = zoom ?? ZoomMath.fit(document: size, in: viewport)
            CanvasViewport(
                documentSize: size, zoom: scale, checkerboard: false, onSize: { viewport = $0 },
                onDrag: { previous, current in drag(from: previous, to: current, scale: scale) },
                onDragEnd: { perform(.stage(.endDrag)); dragStart = nil }, onKey: key
            ) {
                if let list = model.stageList { FlareStageArt(list: list, zoom: scale).drawingGroup() }
            } overlay: {
                FlareStageOverlay(marks: model.stageMarks, zoom: scale)
                FlareStageSelection(model: model, zoom: scale, perform: perform)
                FlareStageGuides(model: model, zoom: scale, perform: perform)
            }
            .overlay(alignment: .leading) {
                ToolbarGroup(palette, axis: .vertical, style: .floating).padding(SuiteSpacing.m)
            }
            .modifier(FlareStageContextMenu(model: model, zoom: scale, perform: perform))
        }
    }

    /// One pointer move: the gesture keeps the point it started at, so the Model sees one gesture.
    private func drag(from previous: CGPoint, to current: CGPoint, scale: Double) {
        let start = dragStart ?? previous
        if dragStart == nil { dragStart = start }
        let flags = NSEvent.modifierFlags
        perform(.stage(.dragChanged(
            start: Point(x: start.x, y: start.y), end: Point(x: current.x, y: current.y),
            shift: flags.contains(.shift), option: flags.contains(.option), stageScale: scale)))
    }

    /// A tool letter chooses its tool when it can act, as its palette button does; anything else goes to `onKey`.
    private func key(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.isEmpty,
            let tool = FlareTool.allCases.first(where: { $0.shortcut.map(String.init) == press.characters.lowercased() })
        else { return onKey(press) }
        guard model.toolHelp(tool) == nil else { return .ignored }
        perform(.tools(.choose(tool)))
        return .handled
    }

    /// The palette: V A R E P, each with its reason when it can't act.
    private var palette: [ToolbarAction] {
        FlareTool.allCases.map { tool in
            let intent = FlareIntent.tools(.choose(tool))
            return ToolbarAction(
                tool.title, systemImage: tool.systemImage, isSelected: tool == model.tool,
                unavailableHelp: model.toolHelp(tool), shortcut: tool.shortcut, identifier: intent.identifier
            ) { perform(intent) }
        }
    }
}

/// The committed art: the list's background, then each item's fill and stroke at its opacity, curves kept as curves
/// (StagePath). Plain values in, so SwiftUI skips it while the list and zoom stay the same.
private struct FlareStageArt: View, Equatable {
    let list: StageDrawList
    let zoom: Double

    var body: some View {
        Canvas { context, size in
            context.fill(SwiftUI.Path(CGRect(origin: .zero, size: size)), with: .color(Self.paint(list.background)))
            for item in list.items where !item.isText { draw(item, in: context) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ item: StageItem, in context: GraphicsContext) {
        let matrix = Matrix.scale(x: zoom, y: zoom) * item.transform
        let path = SwiftUI.Path(StagePath.cgPath(item.path, transform: matrix))
        // How far the matrix stretches a length, for stroke widths and gradient radii.
        let stretch = abs(matrix.determinant).squareRoot()
        var context = context
        context.opacity = item.opacity
        if let fill = item.fill { context.fill(path, with: shading(fill, matrix: matrix, stretch: stretch)) }
        if let stroke = item.stroke, stroke.width > 0 {
            context.stroke(
                path, with: .color(Self.paint(stroke.color)),
                style: StrokeStyle(
                    lineWidth: stroke.width * stretch, lineCap: cap(stroke.cap), lineJoin: join(stroke.join)))
        }
    }

    private func shading(_ fill: Fill, matrix: Matrix, stretch: Double) -> GraphicsContext.Shading {
        func point(_ p: FlareCore.Point) -> CGPoint { let m = matrix.apply(p); return CGPoint(x: m.x, y: m.y) }
        func gradient(_ stops: [GradientStop]) -> Gradient {
            Gradient(stops: stops.map { .init(color: Self.paint($0.color), location: $0.offset) })
        }
        switch fill {
        case .solid(let color): return .color(Self.paint(color))
        case .linear(let stops, let start, let end):
            return .linearGradient(gradient(stops), startPoint: point(start), endPoint: point(end))
        case .radial(let stops, let center, let radius):
            return .radialGradient(gradient(stops), center: point(center), startRadius: 0, endRadius: radius * stretch)
        }
    }

    private static func paint(_ color: FlareColor) -> SwiftUI.Color { SwiftUI.Color(cgColor: StagePath.cgColor(color)) }

    private func cap(_ cap: Stroke.Cap) -> CGLineCap {
        switch cap {
        case .butt: .butt
        case .round: .round
        case .square: .square
        }
    }

    private func join(_ join: Stroke.Join) -> CGLineJoin {
        switch join {
        case .miter: .miter
        case .round: .round
        case .bevel: .bevel
        }
    }
}
