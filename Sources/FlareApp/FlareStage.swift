// FlareStage.swift: the stage, the top of Flare's content (packet draw-key-save, DK-8). The scene's draw list
// (`model.stageList`) is drawn in one Canvas under `.drawingGroup()` on CanvasViewport, so the committed art redraws
// only when the list changes; FlareStageOverlay draws the marks (draft, marquee, selection outline) over it. A drag's
// samples run on a FlareLiveDrag, a copy of the model in this view's own state, so only the stage redraws per sample
// and the window's body doesn't (#1792); its art and marks come from that copy while it lasts. Mouse-up sends the
// last sample as `.stage(.dragChanged)` (the gesture's start, Shift and Option and the zoom), then `.stage(.endDrag)`,
// so the window changes once; Escape drops the copy before the window's `toolKey` cancels. A tool letter (V A R E P) chooses its tool; every other key goes to `onKey` (the window's `toolKey`). The floating
// glass palette lists FlareTool.allCases, each with `model.toolHelp` as its reason when it can't act, then Finish
// Path with `model.finishPathHelp`; it sits inside the vertical ruler. Under the stage the window's one
// ViewerStatusBar shows the zoom percent, the scene size, on the fakes a "Preview data" warning pill, then
// `model.statusPills` from the canvas's `measuredFPS` (IT-9): aspect and rate, the rate shown while playing (a warning
// while frames drop) and "Text not shown (n)". It only reads `model`; every change goes through `perform`.
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
    /// The rate playback measured, from FlareCanvas's PlaybackDriver; nil while paused.
    var measuredFPS: Double? = nil
    /// The gesture under way's first point, in scene points; nil between drags.
    @State private var dragStart: CGPoint?
    /// The drag under way, drawn here until mouse-up; nil between drags and after Escape.
    @State private var live: FlareLiveDrag?
    /// The viewport's size, for the fit while `zoom` is nil.
    @State private var viewport: CGSize = .zero

    var body: some View {
        if let scene = model.selectedScene {
            let size = CGSize(width: scene.width, height: scene.height)
            let scale = zoom ?? ZoomMath.fit(document: size, in: viewport)
            VStack(spacing: 0) {
                stage(size: size, scale: scale)
                ViewerStatusBar(zoom: scale, size: Self.sizeText(size)) {
                    if model.services.isPreview {
                        Text("Preview data").accessibilityIdentifier("flare.status.preview").statusPill(.warning)
                            .help(Self.previewHelp)
                            .accessibilityHint(Self.previewHelp)
                    }
                    Self.statusPills(model.statusPills(measuredFPS: measuredFPS))
                }
            }
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(Self.identifier)
        }
    }

    /// The stage and its status bar; the journeys measure the palette against its leading ruler.
    static let identifier = "flare.stagePane"
    /// What the "Preview data" pill means, as its tooltip and accessibility hint.
    static let previewHelp = "This window shows built-in sample data, not a file on disk."

    /// The actual-rate pill's tooltip.
    static let actualHelp = "The rate playback is showing now. Under the scene's rate, frames are being dropped."

    /// The IT-9 pills after the size: aspect, rate, the rate shown while playing and the hidden-text warning. Aspect
    /// and rate are data, in primary text as the zoom pill is: a short "1:1" in the bar's secondary text measured
    /// under 4.5:1 on the pill fill.
    @ViewBuilder static func statusPills(_ pills: StatusPills) -> some View {
        Text(pills.aspect).foregroundStyle(SuiteColor.textPrimary).accessibilityIdentifier("flare.status.aspect")
        Text(pills.fps).foregroundStyle(SuiteColor.textPrimary).accessibilityIdentifier("flare.status.fps")
        if let actual = pills.actualFPS {
            Text(actual)
                .accessibilityIdentifier("flare.status.actualFPS")
                .accessibilityLabel("Showing \(actual)")
                .help(actualHelp)
                .statusPill(pills.isDropping ? .warning : .plain)
        }
        if let warning = pills.textWarning {
            Text(warning).accessibilityIdentifier("flare.status.text").statusPill(.warning)
        }
    }

    /// The scene's size for the status bar in whole points ("550 × 400 pt"); a non-finite side reads 0.
    static func sizeText(_ size: CGSize) -> String {
        func side(_ value: CGFloat) -> String {
            value.isFinite ? Double(value).formatted(.number.grouping(.never).precision(.fractionLength(0))) : "0"
        }
        return "\(side(size.width)) × \(side(size.height)) pt"
    }

    /// The viewport with the art, the marks and the floating palette. The palette starts inside the vertical
    /// ruler (CanvasViewport always draws one), so it never covers the ruler's numbers.
    private func stage(size: CGSize, scale: Double) -> some View {
        CanvasViewport(
            documentSize: size, zoom: scale, checkerboard: false, onSize: { viewport = $0 },
            onDrag: { previous, current in drag(from: previous, to: current, scale: scale) },
            onDragEnd: endDrag, onKey: key
        ) {
            if let list = live?.movePreview ?? model.stageList { FlareStageArt(list: list, zoom: scale).drawingGroup() }
        } overlay: {
            FlareStageOverlay(marks: live?.stageMarks ?? model.stageMarks, zoom: scale)
            FlareStageSelection(model: model, zoom: scale, perform: perform)
            FlareStageGuides(model: model, zoom: scale, perform: perform)
        }
        .overlay(alignment: .leading) {
            ToolbarGroup(palette, axis: .vertical, style: .floating)
                .padding(SuiteSpacing.m)
                .padding(.leading, SuiteSize.ruler)
        }
        .modifier(FlareStageContextMenu(model: model, zoom: scale, perform: perform))
    }

    /// One pointer move, on the live copy (made from the model at the drag's first sample, or the first after
    /// Escape): the gesture keeps the point it started at, so the Model sees one gesture.
    private func drag(from previous: CGPoint, to current: CGPoint, scale: Double) {
        let start = dragStart ?? previous
        if dragStart == nil { dragStart = start }
        let flags = NSEvent.modifierFlags
        var modifiers: DragModifiers = []
        if flags.contains(.shift) { modifiers.insert(.shift) }
        if flags.contains(.option) { modifiers.insert(.option) }
        var next = live ?? FlareLiveDrag(on: model)
        live = nil
        next.move(StageDragSample(
            start: Point(x: start.x, y: start.y), end: Point(x: current.x, y: current.y), modifiers: modifiers,
            stageScale: scale))
        live = next
    }

    /// Mouse-up: the window gets the drag's last sample and its end, one change and one undo step.
    private func endDrag() {
        if let s = live?.last {
            perform(.stage(.dragChanged(
                start: s.start, end: s.end, shift: s.modifiers.contains(.shift), option: s.modifiers.contains(.option),
                stageScale: s.stageScale)))
        }
        perform(.stage(.endDrag))
        (live, dragStart) = (nil, nil)
    }

    /// A tool letter chooses its tool when it can act, as its palette button does; anything else goes to `onKey`.
    private func key(_ press: KeyPress) -> KeyPress.Result {
        if press.key == .escape { live = nil }
        guard press.modifiers.isEmpty,
            let tool = FlareTool.allCases.first(where: { $0.shortcut.map(String.init) == press.characters.lowercased() })
        else { return onKey(press) }
        guard model.toolHelp(tool) == nil else { return .ignored }
        perform(.tools(.choose(tool)))
        return .handled
    }

    /// The palette: V A R E P, each with its reason when it can't act, then Finish Path. Return finishes a pen
    /// path too, but a mouse-only user needs a control on screen (lead.md rule 8, 9).
    private var palette: [ToolbarAction] {
        let tools = FlareTool.allCases.map { tool in
            let intent = FlareIntent.tools(.choose(tool))
            return ToolbarAction(
                tool.title, systemImage: tool.systemImage, isSelected: tool == model.tool,
                unavailableHelp: model.toolHelp(tool), shortcut: tool.shortcut, identifier: intent.identifier
            ) { perform(intent) }
        }
        let finish = FlareIntent.tools(.finishPath)
        return tools + [
            ToolbarAction(
                "Finish Path", systemImage: "checkmark.circle", isSelected: false,
                unavailableHelp: model.finishPathHelp, shortcut: nil, identifier: finish.identifier
            ) { perform(finish) }
        ]
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
