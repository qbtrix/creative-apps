// FlareApp.swift: Flare, the 2D animation app. The window is SuiteWindow with
// the scenes in the sidebar, FlareCanvas as content and the selected scene's
// summary in the inspector. Views only read FlareWorkspace and call its
// methods; all state lives in FlareModel (scripts/ci checks this).
import FlareModel
import SuiteUI
import SwiftUI

@main
struct FlareApp: App {
    var body: some Scene {
        WindowGroup { FlareWindow() }
    }
}

struct FlareWindow: View {
    @State private var model = FlareWorkspace()

    var body: some View {
        SuiteWindow(
            title: model.document == nil ? "Flare" : "Untitled Animation",
            sidebarTitle: "Scenes",
            items: model.scenes.map { SidebarItem(id: $0.id, title: $0.name, systemImage: "film") },
            selection: model.selectedSceneID,
            onSelect: { model.selectScene($0) },
            actions: [ToolbarAction("New Animation", systemImage: "plus") { model.newDocument() }]
        ) {
            FlareCanvas(model: model, onNew: { model.newDocument() }, onTool: { model.selectTool($0) })
        } inspector: {
            if let scene = model.selectedScene {
                SurfaceCard(title: scene.name, detail: "\(Int(scene.width)) × \(Int(scene.height)) pt · \(scene.fps) fps")
            } else {
                EmptyStateView("No Selection", systemImage: "film", message: "Select a scene to see its properties.")
            }
        }
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
                ToolbarGroup(FlareTool.allCases.map { tool in
                    ToolbarAction(tool.title, systemImage: tool.systemImage, isSelected: tool == model.tool) { onTool(tool) }
                }, axis: .vertical)
            }
        } else {
            EmptyStateView(
                "No Animation Open", systemImage: "film.stack",
                message: "Create an animation to start drawing scenes and keyframes.",
                action: ToolbarAction("New Animation", systemImage: "plus", perform: onNew))
        }
    }
}

extension FlareTool {
    var title: String {
        switch self {
        case .select: "Select"
        case .pen: "Pen"
        case .rectangle: "Rectangle"
        case .ellipse: "Ellipse"
        }
    }

    var systemImage: String {
        switch self {
        case .select: "cursorarrow"
        case .pen: "pencil.tip"
        case .rectangle: "rectangle"
        case .ellipse: "circle"
        }
    }
}
