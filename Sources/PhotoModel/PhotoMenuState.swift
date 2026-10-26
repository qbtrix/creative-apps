// PhotoMenuState.swift (adopt-command-catalog AC-p3): what a Photo menu item built from its catalog spec reads. The
// target is the focused window's workspace (a blank one with no window) plus the menu's own context, which today's
// Edit and Select items fold in: while text has focus or a sheet is up, Cut, Copy and Paste stay on so the field gets
// the key; Cut and Copy are on with an image open (they also act on focused text), Paste with an image on the
// pasteboard; Edit > Select All is off while a sheet is up; Select > All stays on with no window so a field keeps
// Command-A. Every other item is the catalog's availability. An enabled item's tooltip is its menu summary
// (PhotoWorkspace.menuSummary), not the agent call's. Paste Layer Style also needs a style on the pasteboard; the
// style panel's item (Layer Style…, the Layers bar's fx, the sheet's Done) stays on while the panel is open, so it can
// always close it. Run goes through the catalog, as do the style items' runs (the PhotoWorkspace extension at the
// end). Linux-safe.
import SuiteImaging
import SuiteKernel

public struct PhotoMenuState: Sendable {
    public var workspace: PhotoWorkspace
    public var hasWindow: Bool, isPresenting: Bool, textFocused: Bool
    public var pasteboardHasImage: Bool, pasteboardIsEmpty: Bool
    /// The style pasteboard (SuiteUI's LayerStylePasteboard) holds a style.
    public var pasteboardHasStyle: Bool

    /// Paste Layer Style's reason with no style on the pasteboard.
    public static let noStyleToPaste = "Copy a layer style first."

    public init(workspace: PhotoWorkspace = PhotoWorkspace(), hasWindow: Bool = false, isPresenting: Bool = false,
                textFocused: Bool = false, pasteboardHasImage: Bool = false, pasteboardIsEmpty: Bool = true,
                pasteboardHasStyle: Bool = false) {
        (self.workspace, self.hasWindow, self.isPresenting, self.textFocused) = (workspace, hasWindow, isPresenting, textFocused)
        (self.pasteboardHasImage, self.pasteboardIsEmpty) = (pasteboardHasImage, pasteboardIsEmpty)
        self.pasteboardHasStyle = pasteboardHasStyle
    }

    /// The label the menu shows for `id`.
    public func title(_ id: String) -> String { workspace.menuTitle(id) }

    /// The catalog's spec for `id` over the menu state; an id the catalog lacks is never available.
    public static func spec(_ id: String) -> CommandSpec<PhotoMenuState> {
        specs[id] ?? .typed(id, title: id, summary: "Photo has no \(id) command.", kind: .view, params: JSONValue.self,
                            example: .object([:]), availability: { _ in .unavailable("Photo has no \(id) command.") }) { _, _ in JSONValue.object([:]) }
    }

    static let specs = Dictionary(uniqueKeysWithValues: PhotoWorkspace.commands.map { spec in
        (spec.id, CommandSpec<PhotoMenuState>.typed(
            spec.id, title: spec.title, summary: PhotoWorkspace.menuSummary(spec.id), kind: spec.kind, params: JSONValue.self, schema: spec.params,
            result: spec.result, example: spec.example, availability: { $0.availability(spec.id) }) { state, params in
            try PhotoWorkspace.catalog.run(spec.id, params: params, on: &state.workspace).result
        })
    })

    /// Whether the menu item for `id` can run, and why not.
    public func availability(_ id: String) -> Availability {
        let ws = workspace, base = PhotoWorkspace.catalog.availability(id, on: ws)
        let textFirst = textFocused || isPresenting
        switch id {
        case "edit.cut", "edit.copy":
            if textFirst || (hasWindow && ws.canvas != nil) { return .available }
            return .unavailable(base.why ?? PhotoWorkspace.noImage)
        case "edit.paste":
            if textFirst || (hasWindow && pasteboardHasImage) { return .available }
            return .unavailable(pasteboardIsEmpty || !hasWindow ? "Nothing to paste." : "The pasteboard has no image.")
        case "edit.select-all":
            if textFocused { return .available }
            return isPresenting && ws.canvas != nil ? .unavailable("Finish the open sheet first.") : base
        case "select.all":
            return hasWindow ? base : .available
        case "style.paste":
            return base.why == nil && !pasteboardHasStyle ? .unavailable(Self.noStyleToPaste) : base
        case "style.panel":
            return ws.stylePanel != nil ? .available : base
        default:
            return base
        }
    }
}

// What Layer > Layer Style…, Copy, Paste and Clear Layer Style and the style panel's sheet run (layer-styles PY-2).
// A panel intent runs its style.* command through the catalog, except `.show`, which opens or closes the panel with
// `showStylePanel` because style.panel's run is LS-6's. Copy returns the style's JSON for the style pasteboard and
// Paste takes it back; until LS-6 and PY-5 build them, every one but `.show` is refused and the window shows why.
extension PhotoWorkspace {
    /// Runs one style panel intent; a refusal throws the catalog's reason.
    public mutating func runStyleIntent(_ intent: StyleIntent) throws {
        if case .show(let kind) = intent { return showStylePanel(kind) }
        let (id, params) = intent.command
        _ = try Self.catalog.run(id, params: params, on: &self)
    }

    /// Copy Layer Style: the selected layer's style as style.copy returns it, for the style pasteboard.
    public mutating func copyLayerStyle() throws -> JSONValue {
        try Self.catalog.run("style.copy", params: .object([:]), on: &self).result
    }

    /// Paste Layer Style: replaces the selected layer's style with `style`, a copied one.
    public mutating func pasteLayerStyle(_ style: JSONValue) throws {
        _ = try Self.catalog.run("style.paste", params: .object(["style": style]), on: &self)
    }

    /// Clear Layer Style: removes every style from the selected layer.
    public mutating func clearLayerStyle() throws {
        _ = try Self.catalog.run("style.clear", params: .object([:]), on: &self)
    }
}
