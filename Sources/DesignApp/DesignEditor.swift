// DesignEditor.swift: what a Design window shows, laid out on SuiteUI's
// EditorShell: the top bar (the document menu, New, Open, Save, undo and redo,
// zoom), the tool rail, the canvas, the Properties | Layers panel and the status
// line (zoom, page size, the last message, the active tool). Values in, intents
// out: it reads the workspace and sends every action to `perform`, so the same
// view draws the live window and the snapshots. A control that can't act now is
// disabled with a tooltip saying why, and every top bar command is also in the
// menu bar (DesignCommands). `documentName` is the file's name; an open file with
// none is "Untitled". Undo and Redo carry `design.bar.undo` / `design.bar.redo`:
// their titles name the edit, so the identifier is what stays put for the UI
// journeys and the app audit.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignEditor: View {
    let model: DesignWorkspace
    var documentName: String?
    var note: String?
    var zoom = 1.0
    var tab = DesignPanelTab.properties
    var onTab: @MainActor (DesignPanelTab) -> Void = { _ in }
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: DesignPerform = { _ in }

    var body: some View {
        EditorShell {
            DesignTopBar(model: model, documentName: documentName, perform: perform)
        } rail: {
            ToolbarGroup(tools: DesignTool.allCases, selected: model.tool, style: .rail) { perform(.tool($0)) }
        } canvas: {
            DesignCanvas(model: model, zoom: zoom, onViewport: onViewport, onZoom: onZoom, perform: perform)
        } panel: {
            DesignPanel(model: model, tab: tab, onTab: onTab, perform: perform)
        } status: {
            ViewerStatusBar(zoom: model.isOpen ? zoom : 0, size: model.selectedPage?.sizeText ?? "No file open") {
                if let note { Text(note) }
                Text(model.tool.title)
            }
        }
    }
}

/// The top bar: the document menu, New, Open and Save, Undo and Redo, then zoom.
struct DesignTopBar: View {
    let model: DesignWorkspace
    var documentName: String?
    let perform: DesignPerform

    var body: some View {
        let menu = DesignMenu(model: model, perform: perform)
        let closed = menu.isOpen ? nil : "Create or open a file first."
        EditorTopBar(app: "Design", document: menu.isOpen ? (documentName ?? "Untitled") : nil) {
            Button("New File") { perform(.newFile) }
            Button("Open…") { perform(.open) }
            Divider()
            Button("Save") { perform(.save) }.disabled(!menu.isOpen)
            Button("Save As…") { perform(.saveAs) }.disabled(!menu.isOpen)
        } content: {
            EditorBarItem(ToolbarAction("New", systemImage: "plus") { perform(.newFile) })
            EditorBarItem(ToolbarAction("Open", systemImage: "folder") { perform(.open) })
            EditorBarItem(
                ToolbarAction("Save", systemImage: "square.and.arrow.down", unavailableHelp: closed) { perform(.save) })
            EditorBarDivider()
            EditorBarItem(
                ToolbarAction(menu.undoTitle, systemImage: "arrow.uturn.backward", unavailableHelp: menu.undoHelp) {
                    perform(.undo)
                }, showsTitle: false)
            .accessibilityIdentifier("design.bar.undo")
            EditorBarItem(
                ToolbarAction(menu.redoTitle, systemImage: "arrow.uturn.forward", unavailableHelp: menu.redoHelp) {
                    perform(.redo)
                }, showsTitle: false)
            .accessibilityIdentifier("design.bar.redo")
            Spacer(minLength: SuiteSpacing.s)
            ForEach(zoomActions(unavailableHelp: closed)) { EditorBarItem($0, showsTitle: false) }
        }
    }

    private func zoomActions(unavailableHelp: String?) -> [ToolbarAction] {
        let steps: [(title: String, symbol: String, intent: DesignIntent)] = [
            ("Zoom Out", "minus.magnifyingglass", .zoomOut),
            ("Fit Page", "arrow.up.left.and.arrow.down.right", .fit),
            ("Zoom In", "plus.magnifyingglass", .zoomIn),
        ]
        return steps.map { step in
            ToolbarAction(step.title, systemImage: step.symbol, unavailableHelp: unavailableHelp) { perform(step.intent) }
        }
    }
}
