// DesignApp.swift: Design, the vector and UI design app. The window is
// SuiteWindow with pages and layers in the sidebar, DesignCanvas as content
// and the selected layer or page in the inspector. File > New File
// (DesignFileCommands) and the Page menu (DesignCommands) reach the window
// through focused scene values. Views only read DesignWorkspace and
// call its methods; all state lives in DesignModel (scripts/ci checks this).
import DesignModel
import SuiteUI
import SwiftUI

@main
struct DesignApp: App {
    var body: some Scene {
        WindowGroup { DesignWindow() }
            .commands {
                DesignFileCommands()
                DesignCommands()
            }
    }
}

struct DesignWindow: View {
    @State private var model = DesignWorkspace()
    @Environment(\.undoManager) private var undoManager

    var body: some View {
        SuiteWindow(
            title: model.isOpen ? "Untitled Design" : "Design",
            sections: [SidebarSection(id: "pages-and-layers", title: "Pages and Layers", items: sidebarItems)],
            selection: model.selectedNodeID ?? model.selectedPageID,
            onSelect: { model.selectItem($0) },
            // The row comes from the model, so the toggle cannot hit an unknown id.
            onToggle: { id, toggle in if toggle == SidebarItem.designExpand { try? model.toggleExpanded(id) } },
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
        .focusedSceneValue(\.designNewFile, { model.newFile() })
        .focusedSceneValue(\.designAddPage, addPage)
        .focusedSceneValue(\.designDeletePage, deletePage)
    }

    private var sidebarItems: [SidebarItem] {
        model.pages.map { SidebarItem(page: $0) }
            + model.layerRows.map { SidebarItem(row: $0, isExpanded: model.isExpanded($0.id)) }
    }

    /// Page > Add Page's action, nil with no file open.
    private var addPage: (@MainActor () -> Void)? {
        guard model.isOpen else { return nil }
        return { model.addPage() }
    }

    /// Page > Delete Page's action, nil when the selected page is the last one.
    private var deletePage: (@MainActor () -> Void)? {
        guard model.canDeletePage, let id = model.selectedPageID else { return nil }
        return { deletePage(id) }
    }

    /// Deletes a page as the undo step "Delete Page": undo restores it, redo deletes it again.
    private func deletePage(_ id: String) {
        guard let deleted = try? model.deletePage(id) else { return }
        registerUndo { restorePage(deleted) }
    }

    private func restorePage(_ deleted: DeletedPage) {
        guard (try? model.restorePage(deleted)) != nil else { return }
        registerUndo { deletePage(deleted.page.id) }
    }

    private func registerUndo(_ action: @escaping @MainActor @Sendable () -> Void) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: undoManager) { _ in MainActor.assumeIsolated { action() } }
        undoManager.setActionName("Delete Page")
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
