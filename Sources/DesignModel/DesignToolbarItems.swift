// DesignToolbarItems.swift: the window toolbar's nine commands (New, Open,
// Save, Undo, Redo, History, Zoom Out, Fit Page, Zoom In), each with its title, SF
// Symbol, accessibility identifier and the reason it can't run now. The app maps
// each item to a ToolbarAction and an intent in one switch, so a command is
// never shown enabled with nothing to act on, and a disabled one always says
// why. Undo and Redo keep `design.bar.undo` / `design.bar.redo`: their titles
// name the edit, so the identifier is what the journeys and the app audit find.
// History (design/autosave-history DA-3) shows the window's History panel, which
// has steps to list only once a file is open.
// Linux-safe: no UI imports.

/// One command in Design's window toolbar, in toolbar order.
public enum DesignToolbarItem: String, CaseIterable, Sendable {
    case newFile, open, save, undo, redo, history, zoomOut, fit, zoomIn

    /// The accessibility identifier the journeys find the item by.
    public var identifier: String {
        switch self {
        case .newFile: "design.bar.new"
        case .open: "design.bar.open"
        case .save: "design.bar.save"
        case .undo: "design.bar.undo"
        case .redo: "design.bar.redo"
        case .history: "design.bar.history"
        case .zoomOut: "design.bar.zoom-out"
        case .fit: "design.bar.fit"
        case .zoomIn: "design.bar.zoom-in"
        }
    }

    /// The SF Symbol the toolbar draws.
    public var systemImage: String {
        switch self {
        case .newFile: "plus"
        case .open: "folder"
        case .save: "square.and.arrow.down"
        case .undo: "arrow.uturn.backward"
        case .redo: "arrow.uturn.forward"
        case .history: "clock.arrow.circlepath"
        case .zoomOut: "minus.magnifyingglass"
        case .fit: "arrow.up.left.and.arrow.down.right"
        case .zoomIn: "plus.magnifyingglass"
        }
    }

    /// The title and tooltip: Undo and Redo name the edit ("Undo Add Rectangle").
    public func title(in workspace: DesignWorkspace) -> String {
        switch self {
        case .newFile: "New"
        case .open: "Open"
        case .save: "Save"
        case .undo: workspace.undoActionName
        case .redo: workspace.redoActionName
        case .history: "History"
        case .zoomOut: "Zoom Out"
        case .fit: "Fit Page"
        case .zoomIn: "Zoom In"
        }
    }

    /// Why the item can't run now, as its tooltip; nil when it can.
    public func unavailableHelp(in workspace: DesignWorkspace) -> String? {
        switch self {
        case .newFile, .open:
            return nil
        case .save, .zoomOut, .fit, .zoomIn:
            return workspace.isOpen ? nil : Self.noFile
        case .history:
            return workspace.isOpen ? nil : Self.noFile
        case .undo:
            if workspace.editingTextID != nil { return Self.finishEditing }
            return workspace.canUndo ? nil : "Nothing to undo."
        case .redo:
            if workspace.editingTextID != nil { return Self.finishEditing }
            return workspace.canRedo ? nil : "Nothing to redo."
        }
    }

    static let noFile = "Create or open a file first."
    private static let finishEditing = "Finish editing the text first."
}
