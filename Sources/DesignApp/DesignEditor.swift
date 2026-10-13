// DesignEditor.swift: what a Design window shows, laid out on SuiteUI's
// EditorShell: the top bar (New File, undo and redo, zoom), the tool rail, the
// canvas, the Properties | Layers panel and the status line (zoom, page size,
// active tool). Values in, intents out: it reads the workspace and sends every
// action to `perform`, so the same view draws the live window and the
// snapshots. A control that can't act now is disabled with a tooltip saying why.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignEditor: View {
    let model: DesignWorkspace
    var zoom = 1.0
    var tab = DesignPanelTab.properties
    var onTab: @MainActor (DesignPanelTab) -> Void = { _ in }
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: DesignPerform = { _ in }

    var body: some View {
        EditorShell {
            DesignTopBar(model: model, perform: perform)
        } rail: {
            ToolbarGroup(tools: DesignTool.allCases, selected: model.tool, style: .rail) { perform(.tool($0)) }
        } canvas: {
            DesignCanvas(model: model, zoom: zoom, onViewport: onViewport, onZoom: onZoom, perform: perform)
        } panel: {
            DesignPanel(model: model, tab: tab, onTab: onTab, perform: perform)
        } status: {
            ViewerStatusBar(zoom: model.isOpen ? zoom : 0, size: model.selectedPage?.sizeText ?? "No file open") {
                Text(model.tool.title)
            }
        }
    }
}

/// The top bar: the document menu, New File, Undo and Redo, then zoom.
struct DesignTopBar: View {
    let model: DesignWorkspace
    let perform: DesignPerform

    var body: some View {
        EditorTopBar(app: "Design", document: model.isOpen ? "Untitled" : nil) {
            Button("New File") { perform(.newFile) }
        } content: {
            EditorBarItem(ToolbarAction("New File", systemImage: "plus") { perform(.newFile) })
            EditorBarDivider()
            ForEach(historyActions) { EditorBarItem($0, showsTitle: false) }
            Spacer(minLength: SuiteSpacing.s)
            ForEach(zoomActions) { EditorBarItem($0, showsTitle: false) }
        }
    }

    /// Undo and Redo, named for the edit they act on ("Undo Add Rectangle").
    private var historyActions: [ToolbarAction] {
        [
            ToolbarAction(
                model.undoActionName, systemImage: "arrow.uturn.backward",
                unavailableHelp: model.canUndo ? nil : "Nothing to undo.") { perform(.undo) },
            ToolbarAction(
                model.redoActionName, systemImage: "arrow.uturn.forward",
                unavailableHelp: model.canRedo ? nil : "Nothing to redo.") { perform(.redo) },
        ]
    }

    private var zoomActions: [ToolbarAction] {
        let steps: [(title: String, symbol: String, intent: DesignIntent)] = [
            ("Zoom Out", "minus.magnifyingglass", .zoomOut),
            ("Fit on Screen", "arrow.up.left.and.arrow.down.right", .fit),
            ("Zoom In", "plus.magnifyingglass", .zoomIn),
        ]
        let help = model.isOpen ? nil : "Create a file first."
        return steps.map { step in
            ToolbarAction(step.title, systemImage: step.symbol, unavailableHelp: help) { perform(step.intent) }
        }
    }
}
