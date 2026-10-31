// DesignEditor.swift: what a Design window shows, laid out on SuiteUI's
// SuiteWindow: the title (the file's name, "Untitled" for an open file with
// none, else "Design"), the toolbar's nine commands (DesignToolbarItem: New,
// Open and Save beside the title; Undo, Redo, History and the zoom commands
// trailing, History toggling the window's panel, DesignHistoryArea),
// the sidebar's Layers and AI tabs (DesignSidebarTabs), the canvas in
// EditorDetail with the floating tool palette over its leading edge while a
// file is open and the status line under it (zoom, "Page 1440 × 1024 pt", the last
// message, "2 Layers" with a selection, the save state's slot
// (DesignSaveStatus), the active tool), and Properties (DesignInspector) in the
// inspector. Values in, intents out: it reads the workspace and sends every
// action to `perform`, so the same view draws the live window and the
// snapshots. A command that can't act now is disabled with a tooltip saying
// why, and every toolbar command is also in the menu bar (DesignCommands).
// Undo and Redo carry `design.bar.undo` / `design.bar.redo`: their titles name
// the edit, so the identifier is what stays put for the UI journeys and the
// app audit. Every toolbar item (through ToolbarAction.identifier), each tool
// in the floating tool box (`design.tool.*`) and the status line's note,
// selection count and tool carry their DesignControlID and list themselves in
// `suite.controls` (.suiteControl), which DesignWindow's `.suiteProbes()`
// publishes. The note keeps to one line, cut in the middle, and shows its
// whole text as help. In debug builds `bodyRuns` counts its body's runs, so
// DesignWindowDragTests can prove a canvas drag leaves the editor still.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignEditor: View, BodyCounted {
    let model: DesignWorkspace
    var documentName: String?
    var note: String?
    var zoom = 1.0
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: DesignPerform = { _ in }
    /// The window's History panel, which the History button toggles.
    @Environment(\.designHistory) private var history

    /// The commands beside the title, then the trailing ones, in toolbar order.
    private static let documentItems: [DesignToolbarItem] = [.newFile, .open, .save]
    private static let trailingItems: [DesignToolbarItem] = [.undo, .redo, .history, .zoomOut, .fit, .zoomIn]

    #if DEBUG
    @Environment(\.bodyTally) private var bodyTally
    #endif

    var body: some View {
        #if DEBUG
        let _ = bodyTally.ran(Self.self)
        #endif
        SuiteWindow(
            title: documentName ?? (model.isOpen ? "Untitled" : "Design"),
            // The save state's place; it reads nothing until Design has an unsaved state (#270).
            subtitle: DesignSaveStatus.subtitle(model),
            documentActions: Self.documentItems.map { action($0) },
            actions: Self.trailingItems.map { action($0) },
            inspectorWidth: SuiteSize.editorPanelWidth + 2 * SuiteSpacing.m
        ) {
            DesignSidebarTabs(model: model, perform: perform)
        } content: {
            EditorDetail {
                DesignCanvas(model: model, zoom: zoom, onViewport: onViewport, onZoom: onZoom, perform: perform)
            } palette: {
                if model.isOpen {
                    ToolbarGroup(palette, axis: .vertical, style: .floating)
                }
            } status: {
                ViewerStatusBar(zoom: model.isOpen ? zoom : 0, size: model.statusSizeText) {
                    if let note {
                        Text(note)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .help(note)
                            .suiteControl(id: DesignControlID.statusNote, enabled: true, reason: nil)
                    }
                    if let count = model.selectionCountText {
                        Text(count)
                            .suiteControl(id: DesignControlID.statusSelection, enabled: true, reason: nil)
                    }
                    DesignSaveStatus(model: model)
                    Text(model.tool.title)
                        .help("\(DesignWorkspace.statusToolHelp): \(model.tool.title)")
                        .suiteControl(id: DesignControlID.statusTool, enabled: true, reason: nil)
                }
            }
        } inspector: {
            if model.isOpen {
                DesignInspector(model: model, perform: perform)
            } else {
                EmptyStateView("No Selection", systemImage: "square.dashed", message: "Create a file to start designing.")
            }
        }
    }

    /// The floating tool box: one button per tool, each with its `design.tool.*` id, so it is
    /// identified and listed in `suite.controls` (ToolbarGroup registers an action's identifier).
    private var palette: [ToolbarAction] {
        DesignTool.allCases.map { tool in
            ToolbarAction(
                tool.title, systemImage: tool.systemImage, isSelected: tool == model.tool,
                unavailableHelp: tool.unavailableHelp, shortcut: tool.shortcut, identifier: DesignControlID.tool(tool)
            ) { perform(.tool(tool)) }
        }
    }

    /// One toolbar command: the Model's title, symbol, reason and identifier, sending its intent.
    private func action(_ item: DesignToolbarItem) -> ToolbarAction {
        guard let intent = item.intent else { return DesignHistoryArea.toolbarAction(model, history) }
        return ToolbarAction(
            item.title(in: model), systemImage: item.systemImage, unavailableHelp: item.unavailableHelp(in: model),
            identifier: item.identifier
        ) { perform(intent) }
    }
}
