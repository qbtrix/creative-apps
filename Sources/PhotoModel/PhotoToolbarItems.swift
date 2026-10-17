// PhotoToolbarItems.swift: the window toolbar's eight commands (Open, Save,
// Export, Undo, Redo, Zoom Out, Fit on Screen, Zoom In), each with its title,
// SF Symbol, accessibility identifier and the reason it can't run now, plus
// the window subtitle's save state. The app maps each item to a ToolbarAction
// and an intent in one switch, so a command is never shown enabled with
// nothing to act on, and a disabled one always says why. Undo and Redo keep
// `photo.bar.undo` / `photo.bar.redo`: their titles name the edit, so the
// identifier is what the journeys and the app audit find. The save state
// reads `saveStatus(autosaved:saveFailed:)`, but says "Saved" only for a file
// that has a name: a new image that was never saved shows nothing.
// Linux-safe: no UI imports.

/// One command in Photo's window toolbar, in toolbar order.
public enum PhotoToolbarItem: String, CaseIterable, Sendable {
    case open, save, export, undo, redo, zoomOut, fit, zoomIn

    /// The accessibility identifier the journeys find the item by.
    public var identifier: String {
        switch self {
        case .open: "photo.bar.open"
        case .save: "photo.bar.save"
        case .export: "photo.bar.export"
        case .undo: "photo.bar.undo"
        case .redo: "photo.bar.redo"
        case .zoomOut: "photo.bar.zoom-out"
        case .fit: "photo.bar.fit"
        case .zoomIn: "photo.bar.zoom-in"
        }
    }

    /// The SF Symbol the toolbar draws.
    public var systemImage: String {
        switch self {
        case .open: "folder"
        case .save: "square.and.arrow.down"
        case .export: "square.and.arrow.up"
        case .undo: "arrow.uturn.backward"
        case .redo: "arrow.uturn.forward"
        case .zoomOut: "minus.magnifyingglass"
        case .fit: "arrow.up.left.and.arrow.down.right"
        case .zoomIn: "plus.magnifyingglass"
        }
    }

    /// The title and tooltip: Undo and Redo name the edit ("Undo Paint").
    public func title(in workspace: PhotoWorkspace) -> String {
        switch self {
        case .open: "Open"
        case .save: "Save"
        case .export: "Export"
        case .undo: workspace.undoActionName
        case .redo: workspace.redoActionName
        case .zoomOut: "Zoom Out"
        case .fit: "Fit on Screen"
        case .zoomIn: "Zoom In"
        }
    }

    /// Why the item can't run now, as its tooltip; nil when it can.
    public func unavailableHelp(in workspace: PhotoWorkspace) -> String? {
        if self == .open { return nil }
        guard workspace.canvas != nil else { return Self.noImage }
        switch self {
        case .undo: return workspace.canUndo ? nil : "Nothing to undo."
        case .redo: return workspace.canRedo ? nil : "Nothing to redo."
        default: return nil
        }
    }

    /// The window subtitle's base save state: "Edited", "Saved" or nil. nil
    /// with no image, and for a clean image never saved (it has no name yet).
    public static func saveState(of workspace: PhotoWorkspace) -> String? {
        guard let status = workspace.saveStatus(autosaved: false, saveFailed: false) else { return nil }
        if status == .saved, workspace.documentName == nil { return nil }
        return status.title
    }

    private static let noImage = "Open or create an image first."
}
