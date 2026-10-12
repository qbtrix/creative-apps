// DesignApp.swift: Design, the vector and UI design app. The window is
// SuiteWindow with pages and layers in the sidebar, DesignCanvas as content
// and the selected layer or page in the inspector. The page toolbar buttons
// and palette tools disable, saying why, when they can't act. File > New File
// (DesignFileCommands) and the Page menu (DesignCommands) reach the window
// through focused scene values; New File also clears the window's undo stack. Views only read DesignWorkspace and
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
                ToolbarAction("New File", systemImage: "plus") { newFile() },
                ToolbarAction("Add Page", systemImage: "doc.badge.plus", unavailableHelp: noFileHelp) { model.addPage() },
                ToolbarAction(
                    "Delete Page", systemImage: "trash",
                    unavailableHelp: noFileHelp ?? (model.canDeletePage ? nil : "A file keeps at least one page.")
                ) { deletePage?() },
            ]
        ) {
            DesignCanvas(model: model, onNew: { newFile() }, onTool: { model.selectTool($0) })
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
        .focusedSceneValue(\.designNewFile, { newFile() })
        .focusedSceneValue(\.designAddPage, addPage)
        .focusedSceneValue(\.designDeletePage, deletePage)
    }

    private var sidebarItems: [SidebarItem] {
        model.pages.map { SidebarItem(page: $0) }
            + model.layerRows.map { SidebarItem(row: $0, isExpanded: model.isExpanded($0.id)) }
    }

    /// Opens a new file and empties the window's undo and redo stacks, so no step from the
    /// old file can act on the new one.
    private func newFile() {
        DesignUndo.startNewFile(undoManager) { model.newFile() }
    }

    /// Why the page buttons can't act: no file is open.
    private var noFileHelp: String? { model.isOpen ? nil : "Create a file first." }

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
        registerUndo { redoDeletePage(deleted) }
    }

    /// Redo of "Delete Page"; the model refuses it for a page from another file.
    private func redoDeletePage(_ deleted: DeletedPage) {
        guard let again = try? model.redoDeletePage(deleted) else { return }
        registerUndo { restorePage(again) }
    }

    private func registerUndo(_ action: @escaping @MainActor @Sendable () -> Void) {
        guard let undoManager else { return }
        undoManager.registerUndo(withTarget: undoManager) { _ in MainActor.assumeIsolated { action() } }
        undoManager.setActionName("Delete Page")
    }
}

/// Window undo steps that are not one edit.
enum DesignUndo {
    /// Runs New File, then clears `undoManager`, so Undo and Redo disable.
    @MainActor static func startNewFile(_ undoManager: UndoManager?, _ newFile: () -> Void) {
        newFile()
        undoManager?.removeAllActions()
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
                ToolbarGroup(tools: DesignTool.allCases, selected: model.tool, onSelect: onTool)
            }
        } else {
            EmptyStateView(
                "No File Open", systemImage: "square.on.square.dashed",
                message: "Create a file to lay out frames, shapes and text.",
                action: ToolbarAction("New File", systemImage: "plus", perform: onNew))
        }
    }
}

extension DesignTool: PaletteTool {
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
