// DesignWindow.swift: the root of a Design window. It holds the one
// DesignWorkspace (`model`) and the window's presentation state (zoom, the
// viewport, the panel tab), turns every DesignIntent into a workspace method,
// and publishes File > New File and the Page menu's actions through focused
// scene values. Only this file calls the workspace's methods. The zoom keeps
// the handle tolerance a constant size on screen, and the page is fitted
// whenever the selected page changes. Open, Save and the launch arguments
// arrive with the files slice.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignWindow: View {
    @State private var model = DesignWorkspace()
    @State private var zoom = 1.0
    @State private var viewport = CGSize.zero
    /// A new page waits to be fitted until the canvas has a size.
    @State private var fitPending = false
    @State private var tab = DesignPanelTab.properties

    var body: some View {
        DesignEditor(
            model: model, zoom: zoom, tab: tab, onTab: { tab = $0 }, onViewport: viewportChanged, onZoom: setZoom,
            perform: perform
        )
        .navigationTitle(model.isOpen ? "Untitled" : "Design")
        .focusedSceneValue(\.designNewFile, { perform(.newFile) })
        .focusedSceneValue(\.designAddPage, addPage)
        .focusedSceneValue(\.designDeletePage, deletePage)
        .onChange(of: model.selectedPageID) {
            fitPending = true
            fit()
        }
    }

    /// Page > Add Page's action, nil with no file open.
    private var addPage: (@MainActor () -> Void)? {
        guard model.isOpen else { return nil }
        return { perform(.addPage) }
    }

    /// Page > Delete Page's action, nil when the selected page is the last one.
    private var deletePage: (@MainActor () -> Void)? {
        guard model.canDeletePage else { return nil }
        return { perform(.deletePage) }
    }

    private func perform(_ intent: DesignIntent) {
        switch intent {
        case .newFile: model.newFile()
        case .open, .save, .saveAs, .openFile: break
        case .undo: model.undo()
        case .redo: model.redo()
        case .tool(let tool): model.selectTool(tool)
        case .drag(let from, let to, let modifiers):
            model.drag(from: DesignPoint(from), to: DesignPoint(to), modifiers: modifiers)
        case .endDrag: model.endDrag()
        case .nudge(let direction, let shift): model.nudge(direction, shift: shift)
        case .deleteSelection: model.deleteSelection()
        case .deselect: model.deselect()
        case .select(let id): model.selectItem(id)
        // The ids below come from the model's own rows, so a refused call can't happen.
        case .toggleExpanded(let id): try? model.toggleExpanded(id)
        case .addPage: model.addPage()
        case .deletePage: if let id = model.selectedPageID { try? model.deletePage(id) }
        case .setFrame(let id, let x, let y, let width, let height):
            try? model.setNodeFrame(id, x: x, y: y, width: width, height: height)
        case .setFill(let id, let color): try? model.setFill(id, color)
        case .setHidden(let id, let hidden): try? model.setNodeHidden(id, hidden)
        case .setLocked(let id, let locked): try? model.setNodeLocked(id, locked)
        case .editText(let id): try? model.beginTextEdit(id)
        case .textDraft(let text): model.setTextDraft(text)
        case .commitText: model.commitTextEdit()
        case .cancelText: model.cancelTextEdit()
        case .zoomIn: setZoom(ViewerZoom.zoomedIn(from: zoom))
        case .zoomOut: setZoom(ViewerZoom.zoomedOut(from: zoom))
        case .fit: fit()
        }
    }

    // MARK: Zoom

    /// Sets the zoom within the Zoom In and Zoom Out stops, and resizes the handle grab area to match.
    private func setZoom(_ scale: Double) {
        let (lowest, highest) = (ViewerZoom.stops.first ?? 1, ViewerZoom.stops.last ?? 1)
        zoom = scale.isFinite ? Swift.min(Swift.max(scale, lowest), highest) : 1
        model.setHandleTolerance(Double(SuiteSpacing.s) / zoom)
    }

    /// Zooms to show the whole selected page, once the canvas has been laid out.
    private func fit() {
        guard let page = model.selectedPage, viewport != .zero else { return }
        fitPending = false
        let size = CGSize(width: page.frameWidth, height: page.frameHeight)
        let scale = ViewerZoom.fitScale(artboard: size, in: viewport, inset: SuiteSpacing.xxl)
        setZoom(scale > 0 ? scale : 1)
    }

    private func viewportChanged(_ size: CGSize) {
        viewport = size
        if fitPending { fit() }
    }
}
