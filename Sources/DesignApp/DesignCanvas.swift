// DesignCanvas.swift: the canvas of Design's editor shell: the selected page on
// SuiteUI's CanvasViewport (rulers, checkerboard, zoom), with its nodes painted
// by DesignArtwork and the selection's outline and handles over them, or the
// empty state with a New File button when nothing is open. Pointer drags go to
// the workspace as `.drag` with the modifier keys held, and the release as
// `.endDrag`; the workspace decides what a press hits and which tool acts. The
// overlay (not clipped to the page) is the selection's marks, left out for the
// text node being edited, then DesignTextOverlay, the inline text editor. Keys reach the
// canvas while it has focus. During an inline text edit the canvas passes no key
// handler, so CanvasViewport stops being focusable: a focusable view around the
// text field would keep the field from taking the keyboard.
// Content, not chrome: flat, no glass.
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
            canvas(page)
        } else {
            EmptyStateView(
                "No File Open", systemImage: "square.on.square.dashed",
                message: "Create a file to lay out frames, shapes and text.",
                action: ToolbarAction("New File", systemImage: "plus") { perform(.newFile) })
        }
    }

    private func canvas(_ page: DesignPage) -> some View {
        let painted = page.painted
        // A hidden node, or one inside a hidden frame, is not on the canvas, so it has no outline.
        let selected = painted.first { $0.node.id == model.selectedNodeID }?.node
        return CanvasViewport(
            documentSize: CGSize(width: page.frameWidth, height: page.frameHeight), zoom: zoom,
            pointer: model.tool.pointer, onSize: onViewport, onZoom: onZoom,
            onDrag: { perform(.drag($0, $1, .current)) }, onDragEnd: { perform(.endDrag) },
            onKey: model.editingTextID == nil ? { key($0) } : nil
        ) {
            DesignArtwork(painted: painted, zoom: zoom, editingTextID: model.editingTextID)
        } overlay: {
            // The text being edited shows its editor's box instead of handles.
            if let selected, selected.id != model.editingTextID {
                DesignSelectionMarks(rect: selected.frame, zoom: zoom, handles: model.lockHelp(selected.id) == nil)
            }
            DesignTextOverlay(model: model, zoom: zoom, perform: perform)
        }
    }

    /// Arrows nudge the selection (Shift: ten points), Delete removes it, Escape deselects, Return
    /// edits a selected text node, and a tool's letter picks that tool. Anything else is left to the system.
    private func key(_ press: KeyPress) -> KeyPress.Result {
        guard press.modifiers.subtracting(.shift).isEmpty else { return .ignored }
        let shift = press.modifiers.contains(.shift)
        let selection = model.selectedNode
        switch press.key {
        case .upArrow where selection != nil: perform(.nudge(.up, shift: shift))
        case .downArrow where selection != nil: perform(.nudge(.down, shift: shift))
        case .leftArrow where selection != nil: perform(.nudge(.left, shift: shift))
        case .rightArrow where selection != nil: perform(.nudge(.right, shift: shift))
        case .delete where selection != nil, .deleteForward where selection != nil: perform(.deleteSelection)
        case .escape: perform(.deselect)
        case .return:
            guard let selection, selection.kind == .text else { return .ignored }
            perform(.editText(selection.id))
        default:
            // The rail shows Pen disabled; its letter must not pick it either.
            let typed = press.characters.lowercased()
            guard let tool = DesignTool.allCases.first(where: { $0.isEnabled && $0.shortcut.map(String.init) == typed })
            else { return .ignored }
            perform(.tool(tool))
        }
        return .handled
    }
}
