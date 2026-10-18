// DesignCanvas.swift: the canvas of Design's editor shell: the selected page on
// SuiteUI's CanvasViewport (rulers in points, matching the status bar and the
// inspector; checkerboard; zoom), with its nodes painted by DesignArtwork, or the
// empty state with a New File button when nothing is open. Pointer drags go to
// the workspace as `.drag` with the modifier keys held, and the release as
// `.endDrag`; the workspace decides what a press hits and which tool acts. The
// pointer and the pointer handler come from DesignCanvasFeedback. The overlay
// (not clipped to the page) is, bottom to top: the frame names
// (DesignFrameLabels), the selection's marks (DesignSelectionMarks), the marquee
// under way (DesignMarqueeMark), DesignTextOverlay, the inline text editor, and
// DesignCanvasFeedback's marks. `show` is the rect View > Zoom to Selection asks
// for, kept until CanvasViewport can scroll to a rect. Keys reach the
// canvas while it has focus. During an inline text edit the canvas passes no key
// handler, so CanvasViewport stops being focusable: a focusable view around the
// text field would keep the field from taking the keyboard. While the canvas has
// focus, Edit > Cut, Copy and Paste send `.cut`, `.copy` and `.paste`
// (designPasteboardCommands). While a drag or scrub is live, the page, the
// selection's marks, the marquee and the feedback are drawn from the window's
// DesignLiveDrag copy (`live.workspace ?? model`), so a sample redraws the
// canvas without running the window (D0-8a); keys and text editing read `model`.
// The canvas lists itself in `suite.controls` as `design.canvas.page`
// (DesignControlID.canvas) without replacing CanvasViewport's identifier.
// Content, not chrome: flat, no glass.
import DesignModel
import SuiteUI
import SwiftUI

struct DesignCanvas: View {
    let model: DesignWorkspace
    var zoom = 1.0
    /// The rect Zoom to Selection asks the canvas to show (page points); stored until CanvasViewport takes it.
    var show: DesignRect?
    var onViewport: @MainActor (CGSize) -> Void = { _ in }
    var onZoom: @MainActor (Double) -> Void = { _ in }
    var perform: DesignPerform = { _ in }
    /// The window's live drag box; nil when the canvas is hosted alone.
    @Environment(\.designLiveDrag) private var live

    var body: some View {
        let shown = live?.workspace ?? model
        if let page = shown.selectedPage {
            canvas(page, shown: shown)
        } else {
            EmptyStateView(
                "No File Open", systemImage: "square.on.square.dashed",
                message: "Create a file to lay out frames, shapes and text.",
                action: ToolbarAction("New File", systemImage: "plus") { perform(.newFile) })
            .accessibilityIdentifier("design.new-file")
        }
    }

    /// `page` of `shown`, the live copy while a drag or scrub lasts and `model` otherwise.
    private func canvas(_ page: DesignPage, shown: DesignWorkspace) -> some View {
        let painted = page.painted
        let feedback = DesignCanvasFeedback(model: shown, zoom: zoom)
        return CanvasViewport(
            documentSize: CGSize(width: page.frameWidth, height: page.frameHeight), zoom: zoom,
            pointer: feedback.pointer, unit: "pt", onSize: onViewport, onZoom: onZoom,
            onDrag: { perform(.drag($0, $1, .current)) }, onDragEnd: { perform(.endDrag) },
            onKey: model.editingTextID == nil ? { key($0) } : nil, onPointer: feedback.onPointer
        ) {
            DesignArtwork(painted: painted, zoom: zoom, editingTextID: model.editingTextID)
        } overlay: {
            DesignFrameLabels(painted: painted, zoom: zoom)
            DesignSelectionMarks(model: shown, painted: painted, zoom: zoom)
            if let marquee = shown.marquee { DesignMarqueeMark(rect: marquee, zoom: zoom) }
            DesignTextOverlay(model: model, zoom: zoom, perform: perform)
            feedback
        }
        .designPasteboardCommands(model, perform)
        // Listed under its DesignControlID; CanvasViewport keeps its own `suite.canvas` identifier.
        .suiteControl(id: DesignControlID.canvas, enabled: true, reason: nil, identifies: false)
    }

    /// The Model decides the arrows, Delete, Escape and Return (canvasKeyAction: every selected
    /// layer nudges or deletes); a tool's letter picks that tool. Anything else is left to the system.
    private func key(_ press: KeyPress) -> KeyPress.Result {
        let modifiers = DesignKeyModifiers(press.modifiers)
        guard modifiers.reachesCanvas else { return .ignored }
        if let key = DesignCanvasKey(press.key) {
            switch model.canvasKeyAction(key, modifiers: modifiers) {
            case .nudge(let direction, let shift)?: perform(.nudge(direction, shift: shift))
            case .deleteSelection?: perform(.deleteSelection)
            case .deselect?: perform(.deselect)
            case .editText(let id)?: perform(.editText(id))
            case nil: return .ignored
            }
            return .handled
        }
        // The rail shows Pen disabled; its letter must not pick it either.
        let typed = press.characters.lowercased()
        guard let tool = DesignTool.allCases.first(where: { $0.isEnabled && $0.shortcut.map(String.init) == typed })
        else { return .ignored }
        perform(.tool(tool))
        return .handled
    }
}

extension DesignCanvasKey {
    /// The canvas key `key` is, or nil for any other key.
    init?(_ key: KeyEquivalent) {
        switch key {
        case .upArrow: self = .arrow(.up)
        case .downArrow: self = .arrow(.down)
        case .leftArrow: self = .arrow(.left)
        case .rightArrow: self = .arrow(.right)
        case .delete, .deleteForward: self = .delete
        case .escape: self = .escape
        case .return: self = .enter
        default: return nil
        }
    }
}

extension DesignKeyModifiers {
    /// Every flag of `modifiers`: an arrow press carries `.numericPad`, which the Model ignores.
    init(_ modifiers: EventModifiers) {
        let pairs: [(EventModifiers, DesignKeyModifiers)] = [
            (.shift, .shift), (.command, .command), (.option, .option), (.control, .control),
            (.numericPad, .numericPad), (.capsLock, .capsLock),
        ]
        self = pairs.reduce(into: []) { held, pair in if modifiers.contains(pair.0) { held.insert(pair.1) } }
    }
}
