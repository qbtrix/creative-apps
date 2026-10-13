// FlareApp.swift: Flare, the 2D animation app. The window is SuiteWindow with
// scenes and layers in the sidebar, FlareCanvas as content and, in the
// inspector, the selected scene's summary and, while a layer is selected, the
// easing editor (FlareEasingInspector on the live FlareWorkspace). New Sample
// Animation (toolbar and File menu) opens a keyed document to edit; the menus
// in FlareCommands reach the window through a focused scene value, and View >
// Hide Sidebar makes room for the inspector on a small screen. A palette
// tool that doesn't work yet shows disabled with FlareTool.unavailableHelp as
// its tooltip. Views only read FlareWorkspace and call its methods; all state
// lives in FlareModel (scripts/ci checks this).
import FlareModel
import SuiteUI
import SwiftUI

@main
struct FlareApp: App {
    var body: some Scene {
        WindowGroup { FlareWindow() }
            // Fits a 1024 x 768 screen (the CI runner's) with the inspector in full.
            .defaultSize(width: 1000, height: 700)
            .commands {
                SidebarCommands()
                FlareCommands()
            }
    }
}

struct FlareWindow: View {
    @State private var model = FlareWorkspace()

    var body: some View {
        SuiteWindow(
            title: model.document == nil ? "Flare" : "Untitled Animation",
            sections: SidebarSection.flare(model, onAddLayer: { model.addLayer() }),
            selection: model.selectedLayerID ?? model.selectedSceneID,
            onSelect: { model.selectItem($0) },
            onToggle: { id, toggle in
                if let flag = FlareLayerFlag(rawValue: toggle) { model.toggleLayerFlag(id, flag) }
            },
            onMove: { section, rows, destination in
                // The sidebar selects one row at a time, so a drag moves one layer.
                if section == "layers", let row = rows.first { model.moveLayer(from: row, to: destination) }
            },
            onRename: { id, name in model.renameLayer(id, to: name) },
            actions: [
                ToolbarAction("New Animation", systemImage: "plus") { model.newDocument() },
                ToolbarAction("New Sample Animation", systemImage: "wand.and.stars") { model.newSampleAnimation() },
                // Acts only with a layer selected; ToolbarAction has no disabled state yet (#85).
                ToolbarAction("Delete Layer", systemImage: "trash") {
                    if let id = model.selectedLayerID { model.removeLayer(id) }
                },
            ]
        ) {
            FlareCanvas(model: model, onNew: { model.newDocument() }, onTool: { model.selectTool($0) })
        } inspector: {
            VStack(alignment: .leading, spacing: SuiteSpacing.s) {
                if let error = model.layerError {
                    Label(error.message, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(SuiteColor.secondaryText)
                }
                if let scene = model.selectedScene {
                    SurfaceCard(title: scene.name, detail: "\(Int(scene.width)) × \(Int(scene.height)) pt · \(scene.fps) fps")
                    if model.selectedLayerID != nil {
                        FlareEasingInspector(
                            editor: model, onSelect: { model.selectEasingSegment($0) },
                            onPreset: { model.setEasingPreset($0) }, onMoveHandle: { model.moveEasingHandle($0, to: $1) },
                            onEndDrag: { model.endEasingHandleDrag() })
                    }
                } else {
                    EmptyStateView("No Selection", systemImage: "film", message: "Select a scene to see its properties.")
                }
            }
        }
        .focusedSceneValue(
            \.flareMenu,
            FlareMenu(
                model: model, newSample: { model.newSampleAnimation() }, undo: { model.undo() },
                redo: { model.redo() }))
    }
}

/// The main content: the canvas with its tool palette, or the empty state.
struct FlareCanvas: View {
    let model: FlareWorkspace
    var onNew: @MainActor () -> Void = {}
    var onTool: @MainActor (FlareTool) -> Void = { _ in }

    var body: some View {
        if let scene = model.selectedScene {
            CanvasSurface(artboard: CGSize(width: scene.width, height: scene.height)) {
                ToolbarGroup(tools: FlareTool.allCases, selected: model.tool, onSelect: onTool)
            }
        } else {
            EmptyStateView(
                "No Animation Open", systemImage: "film.stack",
                message: "Create an animation to start drawing scenes and keyframes.",
                action: ToolbarAction("New Animation", systemImage: "plus", perform: onNew))
        }
    }
}

extension FlareTool: PaletteTool {
    public var title: String {
        switch self {
        case .select: "Select"
        case .pen: "Pen"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        }
    }

    public var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .pen: "pencil.tip"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        }
    }
}
