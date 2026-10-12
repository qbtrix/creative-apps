// DesignApp.swift: Design, the vector and UI design app. The window is
// SuiteWindow with pages and layers in the sidebar, DesignCanvas as content
// and the selected layer or page in the inspector. The Page menu (DesignCommands)
// reaches the window through focused scene values. Views only read DesignWorkspace and
// call its methods; all state lives in DesignModel (scripts/ci checks this).
import DesignModel
import SuiteUI
import SwiftUI

@main
struct DesignApp: App {
    var body: some Scene {
        WindowGroup { DesignWindow() }
            .commands { DesignCommands() }
    }
}

struct DesignWindow: View {
    @State private var model = DesignWorkspace()

    var body: some View {
        SuiteWindow(
            title: model.isOpen ? "Untitled Design" : "Design",
            sidebarTitle: "Pages and Layers",
            items: model.pages.map { SidebarItem(page: $0) } + model.layerRows.map { SidebarItem(row: $0) },
            selection: model.selectedNodeID ?? model.selectedPageID,
            onSelect: { model.selectItem($0) },
            actions: [
                ToolbarAction("New File", systemImage: "plus") { model.newFile() },
                ToolbarAction("Add Page", systemImage: "doc.badge.plus") { model.addPage() },
                // Page > Delete Page disables on the last page; this button cannot until
                // ToolbarAction has a disabled state (#85), so it acts only when allowed.
                ToolbarAction("Delete Page", systemImage: "trash") { deletePage?() },
            ]
        ) {
            DesignCanvas(model: model, onNew: { model.newFile() }, onTool: { model.selectTool($0) })
        } inspector: {
            if let node = model.selectedNode {
                // The node comes from the model, so these setters cannot hit an unknown id.
                SurfaceCard(title: node.name, detail: node.kind.defaultName)
                Toggle("Hidden", isOn: Binding(get: { node.isHidden }, set: { try? model.setNodeHidden(node.id, $0) }))
                Toggle("Locked", isOn: Binding(get: { node.isLocked }, set: { try? model.setNodeLocked(node.id, $0) }))
            } else if let page = model.selectedPage {
                SurfaceCard(title: page.name, detail: "Frame \(Int(page.frameWidth)) × \(Int(page.frameHeight)) pt")
            } else {
                EmptyStateView("No Selection", systemImage: "square.dashed", message: "Select a page or layer to edit it.")
            }
        }
        .focusedSceneValue(\.designAddPage, addPage)
        .focusedSceneValue(\.designDeletePage, deletePage)
    }

    /// Page > Add Page's action, nil with no file open.
    private var addPage: (@MainActor () -> Void)? {
        guard model.isOpen else { return nil }
        return { model.addPage() }
    }

    /// Page > Delete Page's action, nil when the selected page is the last one.
    private var deletePage: (@MainActor () -> Void)? {
        guard model.canDeletePage, let id = model.selectedPageID else { return nil }
        // canDeletePage holds, so the delete cannot be refused.
        return { try? model.deletePage(id) }
    }
}

/// The main content: the page canvas with its tool palette, or the empty state.
struct DesignCanvas: View {
    let model: DesignWorkspace
    var onNew: @MainActor () -> Void = {}
    var onTool: @MainActor (DesignTool) -> Void = { _ in }

    var body: some View {
        if let page = model.selectedPage {
            CanvasSurface(artboard: CGSize(width: page.frameWidth, height: page.frameHeight)) {
                ToolbarGroup(DesignTool.allCases.map { tool in
                    ToolbarAction(tool.title, systemImage: tool.systemImage, isSelected: tool == model.tool) { onTool(tool) }
                }, axis: .vertical)
            }
        } else {
            EmptyStateView(
                "No File Open", systemImage: "square.on.square.dashed",
                message: "Create a file to lay out frames, shapes and text.",
                action: ToolbarAction("New File", systemImage: "plus", perform: onNew))
        }
    }
}

extension DesignTool {
    var title: String {
        switch self {
        case .move: "Move"
        case .frame: "Frame"
        case .rectangle: "Rectangle"
        case .text: "Text"
        case .pen: "Pen"
        }
    }

    var systemImage: String {
        switch self {
        case .move: "cursorarrow"
        case .frame: "number"
        case .rectangle: "rectangle"
        case .text: "textformat"
        case .pen: "pencil.tip"
        }
    }
}
