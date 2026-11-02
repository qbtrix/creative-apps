// HaloShapeTool.swift (shape-tools HS-2): the Shape button by the viewer and
// its options popover. The button is a floating ToolbarGroup item
// (`halo.viewer.shape`) disabled with HaloProject's `shapeHelp` as its
// tooltip while the tool can't draw; it opens HaloShapeOptions, SuiteUI's
// ShapeToolOptions on the Model's `shapeTool` with `shapeHelp` under its
// rows. Each option goes to `onIntent`. The view only reads the Model; the
// popover's open state is presentation state.
// HS-3: an option turns the tool on (HaloShapeDrawing); a viewer drag then
// sets its draft, which only HaloShapeDraftView reads, and the release draws once.
// HaloTool names the viewer's two canvas gestures as palette tools (the plain
// viewer drag moves a layer; Shape draws one), so Halo declares each tool's
// ToolGesture like every app; the Shape button takes its face from it.
import HaloModel
import Observation
import SuiteKernel
import SuiteUI
import SwiftUI

/// The viewer's canvas tools: a plain drag moves the layer under it; with Shape on it draws one.
enum HaloTool: String, CaseIterable, PaletteTool {
    case move, shape
    var title: String { self == .move ? "Move" : "Shape" }
    var systemImage: String { self == .move ? "cursorarrow" : "star" }
    var unavailableHelp: String? { nil }
    var gesture: ToolGesture { self == .move ? .movesContent : .creates }
}

struct HaloShapeTool: View {
    let model: HaloProject
    var onIntent: @MainActor (ShapeIntent) -> Void = { _ in }
    /// Whether the options popover is open. Presentation state only.
    @State private var showsOptions = false
    @Environment(\.haloShapeDrawing) private var drawing

    /// The button, off with the Model's reason while it can't draw.
    nonisolated static func action(_ model: HaloProject, isOn: Bool = false, perform: @escaping @MainActor () -> Void) -> ToolbarAction {
        ToolbarAction(
            HaloTool.shape.title, systemImage: HaloTool.shape.systemImage, isSelected: isOn, unavailableHelp: model.shapeHelp, identifier: "halo.viewer.shape",
            perform: perform)
    }

    var body: some View {
        ToolbarGroup([Self.action(model, isOn: drawing?.isOn ?? false) { showsOptions = true }])
            .popover(isPresented: $showsOptions, arrowEdge: .bottom) {
                HaloShapeOptions(model: model, onIntent: onIntent)
            }
    }
}

/// The Shape popover's content, on its own so a snapshot can show it.
struct HaloShapeOptions: View {
    let model: HaloProject
    var onIntent: @MainActor (ShapeIntent) -> Void = { _ in }

    var body: some View {
        ShapeToolOptions(spec: model.shapeTool, help: model.shapeHelp, onIntent: onIntent)
            .padding(SuiteSpacing.m)
            .frame(width: SuiteSize.editorPanelWidth)
    }
}

/// Whether the shape tool is on and its drag. Presentation state, like HaloLiveEdit.
@MainActor @Observable final class HaloShapeDrawing {
    var isOn = false
    private(set) var gesture = HaloShapeGesture()
    /// A spec drawn instead of the Model's tool (tests); `draw` adds a released shape.
    @ObservationIgnored let tool: ShapeSpec?
    @ObservationIgnored var draw: @MainActor (HaloShapeDrawn) -> Void

    init(tool: ShapeSpec? = nil, draw: @escaping @MainActor (HaloShapeDrawn) -> Void = { _ in }) {
        (self.tool, self.draw) = (tool, draw)
    }

    var draft: HaloShapeDrawn? { gesture.draft }

    func drag(_ modelTool: ShapeSpec, from: HaloPoint, to: HaloPoint, modifiers: EditModifiers = []) {
        gesture.drag(tool ?? modelTool, from: from, to: to, modifiers: modifiers)
    }

    func release() {
        if let drawn = gesture.release() { draw(drawn) }
    }

    /// Escape: drops the drag in progress, or with none turns the tool off.
    func escape() {
        if !gesture.escape() { isOn = false }
    }
}

extension EnvironmentValues {
    /// The window's shape tool; nil outside a HaloWindow, where a drag moves layers.
    @Entry var haloShapeDrawing: HaloShapeDrawing?
}

/// The drag's draft over the artboard; the only view that reads it.
struct HaloShapeDraftView: View {
    let drawing: HaloShapeDrawing
    let artboard: CGSize

    var body: some View {
        let outline = drawing.draft?.outline ?? []
        let artboard = artboard
        Canvas { context, size in
            let (sx, sy) = (size.width / max(artboard.width, 1), size.height / max(artboard.height, 1))
            var path = SwiftUI.Path()
            for line in outline { path.addLines(line.map { CGPoint(x: $0.x * sx, y: $0.y * sy) }) }
            context.stroke(path, with: .color(SuiteColor.accent), lineWidth: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
