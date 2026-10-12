// PhotoApp.swift: Photo, the raster editing app. The window is SuiteWindow
// with the canvas's layers in the sidebar, PhotoCanvas as content and the
// canvas size in the inspector. Views only read PhotoWorkspace and call its
// methods; all state lives in PhotoModel (scripts/ci checks this).
import PhotoModel
import SuiteUI
import SwiftUI

@main
struct PhotoApp: App {
    var body: some Scene {
        WindowGroup { PhotoWindow() }
    }
}

struct PhotoWindow: View {
    @State private var model = PhotoWorkspace()

    var body: some View {
        SuiteWindow(
            title: model.canvas == nil ? "Photo" : "Untitled Image",
            sidebarTitle: "Layers",
            items: model.layerNames.map { SidebarItem(id: $0, title: $0, systemImage: "square.3.layers.3d") },
            selection: model.selectedLayer,
            onSelect: { model.selectLayer($0) },
            actions: [ToolbarAction("New Image", systemImage: "plus") { newImage() }]
        ) {
            PhotoCanvas(model: model, onNew: newImage, onTool: { model.selectTool($0) })
        } inspector: {
            if let canvas = model.canvas, let layer = model.selectedLayer {
                SurfaceCard(title: layer, detail: "\(canvas.width) × \(canvas.height) px")
            } else {
                EmptyStateView("No Selection", systemImage: "photo", message: "Select a layer to adjust it.")
            }
        }
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
                ToolbarGroup(PhotoTool.allCases.map { tool in
                    ToolbarAction(tool.title, systemImage: tool.systemImage, isSelected: tool == model.tool) { onTool(tool) }
                }, axis: .vertical)
            }
        } else {
            EmptyStateView(
                "No Image Open", systemImage: "photo.on.rectangle",
                message: "Create an image to paint, select and adjust it.",
                action: ToolbarAction("New Image", systemImage: "plus", perform: onNew))
        }
    }
}

extension PhotoTool {
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
