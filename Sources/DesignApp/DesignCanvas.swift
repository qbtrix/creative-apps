// DesignCanvas.swift: the canvas of Design's editor shell: the selected page as
// a white artboard on SuiteUI's CanvasViewport (rulers, checkerboard, zoom),
// or the empty state with a New File button when nothing is open. Pointer
// drags go to the workspace as `.drag` with the modifier keys held, and the
// release as `.endDrag`; the overlay ends with DesignTextOverlay, the inline
// text editor. Content, not chrome: flat, no glass.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignCanvas: View {
    let model: DesignWorkspace
    var zoom = 1.0
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: DesignPerform = { _ in }

    var body: some View {
        if let page = model.selectedPage {
            CanvasViewport(
                documentSize: CGSize(width: page.frameWidth, height: page.frameHeight), zoom: zoom,
                pointer: model.tool.pointer, onSize: onViewport, onZoom: onZoom,
                onDrag: { perform(.drag($0, $1, .current)) }, onDragEnd: { perform(.endDrag) }
            ) {
                Rectangle().fill(SuiteColor.artboard)
            } overlay: {
                DesignTextOverlay(model: model, zoom: zoom, perform: perform)
            }
        } else {
            EmptyStateView(
                "No File Open", systemImage: "square.on.square.dashed",
                message: "Create a file to lay out frames, shapes and text.",
                action: ToolbarAction("New File", systemImage: "plus") { perform(.newFile) })
        }
    }
}
