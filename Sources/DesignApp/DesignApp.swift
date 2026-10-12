// DesignApp.swift: Design, the vector and UI design app. The window is
// SuiteWindow with the file's pages in the sidebar, DesignCanvas as content
// and the selected page in the inspector. Views only read DesignWorkspace and
// call its methods; all state lives in DesignModel (scripts/ci checks this).
import DesignModel
import SuiteUI
import SwiftUI

@main
struct DesignApp: App {
    var body: some Scene {
        WindowGroup { DesignWindow() }
    }
}

struct DesignWindow: View {
    @State private var model = DesignWorkspace()

    var body: some View {
        SuiteWindow(
            title: model.isOpen ? "Untitled Design" : "Design",
            sidebarTitle: "Pages",
            items: model.pages.map { SidebarItem(id: $0.id, title: $0.name, systemImage: "doc") },
            selection: model.selectedPageID,
            onSelect: { model.selectPage($0) },
            actions: [
                ToolbarAction("New File", systemImage: "plus") { model.newFile() },
                ToolbarAction("Add Page", systemImage: "doc.badge.plus") { model.addPage() },
            ]
        ) {
            DesignCanvas(model: model, onNew: { model.newFile() }, onTool: { model.selectTool($0) })
        } inspector: {
            if let page = model.selectedPage {
                SurfaceCard(title: page.name, detail: "Frame \(Int(page.frameWidth)) × \(Int(page.frameHeight)) pt")
            } else {
                EmptyStateView("No Selection", systemImage: "square.dashed", message: "Select a page or layer to edit it.")
            }
        }
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
