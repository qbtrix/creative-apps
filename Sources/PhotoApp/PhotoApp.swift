// PhotoApp.swift: Photo, the raster editing app. The window is SuiteWindow
// with the layer stack in the sidebar (add, rename, reorder, show and hide),
// PhotoCanvas as content and PhotoInspector (the selected layer, then the
// image adjustments, or an empty state) in the inspector. The Layer menu
// (PhotoCommands) reaches the window through a focused scene value. A palette
// tool that doesn't work yet shows disabled with PhotoTool.unavailableHelp as
// its tooltip. Views only
// read PhotoWorkspace and call its methods; all state lives in PhotoModel
// (scripts/ci checks this).
import PhotoModel
import SuiteUI
import SwiftUI

@main
struct PhotoApp: App {
    var body: some Scene {
        WindowGroup { PhotoWindow() }
            .commands { PhotoCommands() }
    }
}

struct PhotoWindow: View {
    @State private var model = PhotoWorkspace()
    @State private var isRenaming = false
    @State private var renameText = ""

    var body: some View {
        SuiteWindow(
            title: model.canvas == nil ? "Photo" : "Untitled Image",
            sections: [
                SidebarSection(
                    id: PhotoLayerItems.sectionID, title: "Layers", items: PhotoLayerItems.items(model.layers),
                    addAction: model.canvas == nil ? nil : ToolbarAction("New Layer", systemImage: "plus", perform: addLayer))
            ],
            selection: model.selectedLayerID,
            onSelect: { model.selectLayer($0) },
            onToggle: { id, _ in model.toggleVisibility(id) },
            onMove: { _, from, to in model.moveLayers(fromOffsets: Array(from), toOffset: to) },
            onRename: { model.renameLayer($0, to: $1) },
            actions: actions
        ) {
            PhotoCanvas(model: model, onNew: newImage, onTool: { model.selectTool($0) })
        } inspector: {
            PhotoInspector(
                model: model,
                onBlendMode: { model.setBlendMode($0, $1) },
                onOpacity: { model.setOpacity($0, percent: $1) },
                onAdjust: { model.adjust($0) })
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                DeleteLayerCommand(isEnabled: model.canDeleteSelectedLayer, perform: deleteLayer)
            }
        }
        .focusedSceneValue(\.photoLayerActions, layerActions)
        .alert("Rename Layer", isPresented: $isRenaming) {
            TextField("Name", text: $renameText)
            Button("Rename", action: commitRename)
            Button("Cancel", role: .cancel) {}
        }
    }

    /// The Layer menu's actions, each nil while it can't run.
    private var layerActions: PhotoLayerActions {
        PhotoLayerActions(
            newLayer: model.canAddLayer ? addLayer : nil,
            deleteLayer: model.canDeleteSelectedLayer ? deleteLayer : nil,
            renameLayer: model.canEditSelectedLayer ? beginRename : nil,
            toggleVisibility: model.canEditSelectedLayer ? toggleSelectedVisibility : nil,
            visibilityTitle: model.visibilityCommandTitle)
    }

    private var actions: [ToolbarAction] {
        [ToolbarAction("New Image", systemImage: "plus") { newImage() }]
    }

    private func deleteLayer() {
        guard let id = model.selectedLayerID else { return }
        model.removeLayer(id)
    }

    private func beginRename() {
        guard let layer = model.selectedLayer else { return }
        renameText = layer.name
        isRenaming = true
    }

    private func commitRename() {
        guard let id = model.selectedLayerID else { return }
        model.renameLayer(id, to: renameText)
    }

    private func toggleSelectedVisibility() {
        guard let id = model.selectedLayerID else { return }
        model.toggleVisibility(id)
    }

    private func addLayer() {
        model.addLayer()
    }

    /// 1920x1080 is a size CoreRaster always accepts, so this never throws.
    private func newImage() {
        try? model.newCanvas(width: 1920, height: 1080)
    }
}

/// The main content: the image canvas with its tool palette, or the empty state.
struct PhotoCanvas: View {
    let model: PhotoWorkspace
    var onNew: @MainActor () -> Void = {}
    var onTool: @MainActor (PhotoTool) -> Void = { _ in }

    var body: some View {
        if let canvas = model.canvas {
            CanvasSurface(artboard: CGSize(width: canvas.width, height: canvas.height)) {
                ToolbarGroup(tools: PhotoTool.allCases, selected: model.tool, onSelect: onTool)
            }
        } else {
            EmptyStateView(
                "No Image Open", systemImage: "photo.on.rectangle",
                message: "Create an image to paint, select and adjust it.",
                action: ToolbarAction("New Image", systemImage: "plus", perform: onNew))
        }
    }
}

extension PhotoTool: PaletteTool {
    var title: String {
        switch self {
        case .move: "Move"
        case .marquee: "Marquee"
        case .brush: "Brush"
        case .eraser: "Eraser"
        case .crop: "Crop"
        }
    }

    var systemImage: String {
        switch self {
        case .move: "arrow.up.and.down.and.arrow.left.and.right"
        case .marquee: "rectangle.dashed"
        case .brush: "paintbrush.pointed"
        case .eraser: "eraser"
        case .crop: "crop"
        }
    }
}
